require("buffer-manager.utils")

local M = {}

local defaults = {
    window_title = "Manage your buffers!",
    window_width = 90,
    window_height = 25,
    padding_left = 1,
    padding_right = 1,
    keys = {
        delete_key = 'x',
        wipe_key = 'w',
        close_other_buffers_key = 'O',
    }
}

local ui = vim.api.nvim_list_uis()[1]

local function get_buffers()
    local buffers = vim.tbl_filter(function(buf)
        return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_option(buf, "buflisted")
    end, vim.api.nvim_list_bufs())
    return buffers
end

function edit_buffer(win, buf_list_win)
    local pos = vim.api.nvim_win_get_cursor(buf_list_win)
    local buffer = M._buffer_map[pos[1]]
    vim.api.nvim_win_set_buf(win, buffer)
end

function delete_all_other_buffers(buf_list_win)
    local pos = vim.api.nvim_win_get_cursor(buf_list_win)
    local buffer = M._buffer_map[pos[1]]
    local buffers = get_buffers()

    -- First check if there are any open buffers with unsaved changes
    local any_unsaved_buffers = false
    for _, b in ipairs(buffers) do
        if vim.bo[b].modified then
            any_unsaved_buffers = true
        end
    end
    if any_unsaved_buffers then
        vim.api.nvim_echo({ { string.format("You have one or more unsaved buffers. Would you like to:\n"
            ..
            "(s)ave all of them and close\n(f)orce close them without save\n(c)ancel") } }, false, {})
        local choice = string.char(vim.fn.getchar())
        if choice == 'c' or choice == 'C' then
            vim.cmd.echo('""')
            vim.cmd.redraw()
            return
        end
        if choice == 's' or choice == 'S' then
            for _, b in ipairs(buffers) do
                if vim.bo[b].modified then
                    vim.api.nvim_buf_call(b, function() vim.cmd.write() end)
                end
            end
            vim.cmd.echo('""')
            vim.cmd.redraw()
        end
    end

    -- Force close everything since we now have either saved it all, cancelled, or selected force.
    local deleted_count = 0
    for _, b in ipairs(buffers) do
        if b ~= buffer then
            vim.api.nvim_buf_delete(b, { force = true })
            deleted_count = deleted_count + 1
        end
    end
    vim.api.nvim_echo({ { string.format("Closed %d buffers", deleted_count) } }, false, {})

    refresh_window(buf_list_win)
end

function delete_buffer(buf_list_win)
    local pos = vim.api.nvim_win_get_cursor(buf_list_win)
    local buffer = M._buffer_map[pos[1]]
    if vim.bo[buffer].modified then
        vim.api.nvim_echo({ {
            string.format(
                "The buffer you're trying to close (%d: %s) has been modified since the last write. Would you like to:\n"
                ..
                "(s)ave and close\n(f)orce close without save\n(c)ancel",
                buffer, vim.api.nvim_buf_get_name(buffer))
        } }, false, {})
        local choice = string.char(vim.fn.getchar())
        -- Save buffer
        if choice == 'c' or choice == 'C' then
            vim.cmd.echo('""')
            vim.cmd.redraw()
            return
        end
        if choice == 's' or choice == 'S' then
            vim.api.nvim_buf_call(buffer, function() vim.cmd.write() end)
        end
        vim.cmd.echo('""')
        vim.cmd.redraw()
    end
    vim.api.nvim_buf_delete(buffer, { force = true })
    refresh_window(buf_list_win)
end

function refresh_window(original_win)
    vim.api.nvim_win_close(original_win, false)
    M.show_buffer_list()
end

M.setup = function(options)
    M.options = vim.tbl_deep_extend("force", {}, defaults, options or {})

    vim.api.nvim_create_user_command("BufferManagerShow", function()
        M.show_buffer_list()
    end
    , {})
end

-- { cursor line, buffer number }
M._buffer_map = {}
M._previous_pos = { 0, 0 }

M.show_buffer_list = function()
    local buf = vim.api.nvim_create_buf(false, true)

    local current_win = vim.api.nvim_get_current_win()

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = M.options.window_width,
        height = M.options.window_height,
        col = (ui.width - M.options.window_width) / 2,
        row = (ui.height - M.options.window_height) / 2,
        style = "minimal",
        focusable = false,
        border = "rounded",
    })

    -- TODO: Clean this up. Lots of hacky magic numbers in here.
    vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = buf,
        group = vim.api.nvim_create_augroup("prevent_cursor", { clear = false }),
        callback = function()
            local pos = vim.api.nvim_win_get_cursor(win)
            if pos[1] < 6 then
                vim.api.nvim_win_set_cursor(win, { 6, M._previous_pos[2] })
            end

            -- Prevent cursor from going into column 1
            if pos[2] < M.options["padding_left"] then
                vim.api.nvim_win_set_cursor(win, { M._previous_pos[1], M.options["padding_left"] })
            end

            if pos[1] ~= 5 and pos[2] ~= 0 then
                M._previous_pos = pos
            end
        end,
    })


    -- Set keymaps
    local closing_keys = { "q", "<esc>" }
    local opts = { noremap = true, silent = true }
    for _, key in pairs(closing_keys) do
        vim.api.nvim_buf_set_keymap(buf, "n", key, string.format(":lua vim.api.nvim_win_close(%d, false)<CR>", win), opts)
    end
    vim.api.nvim_buf_set_keymap(buf, "n", "<CR>",
        string.format(":lua edit_buffer(%d, %d)<CR>", current_win, win), opts)
    vim.api.nvim_buf_set_keymap(buf, "n", M.options.keys["delete_key"], string.format(":lua delete_buffer(%d)<CR>", win)
    , opts)

    vim.api.nvim_buf_set_keymap(buf, "n", M.options.keys["close_other_buffers_key"],
        string.format(":lua delete_all_other_buffers(%d)<CR>", win), opts)


    -- Set the buffer text

    local line = center(M.options["window_title"])

    vim.api.nvim_buf_set_lines(buf, 1, 1, false, { line })
    vim.api.nvim_buf_set_lines(buf, 2, 2, false, { " " })
    vim.api.nvim_buf_set_lines(buf, 3, 3, false,
        { center(string.format("%s = :bd | %s = :bw | return = :e | q = cancel", M.options.keys["delete_key"],
            M.options.keys["wipe_key"])) })
    vim.api.nvim_buf_set_lines(buf, 4, 4, false, { " " })

    local buffers = get_buffers()
    for i, b in ipairs(buffers) do
        local name = vim.api.nvim_buf_get_name(b)
        M._buffer_map[5 + i] = b
        vim.api.nvim_buf_set_lines(buf, 5 + i, 5 + i, false,
            { string.rep(" ", M.options["padding_left"]) .. b .. "   " .. name })
    end

    -- Set the cursor to the position of the current buffer
    -- Find the current buffer and loop through all open buffers to find the matching bufnr
    -- The index of the matching buffer should be how many rows we need to add when
    -- setting the cursor pos.
    local main_buffer = get_main_buffer_behind_floating()
    local buf_index = 1
    for i, b in ipairs(buffers) do
        if b == main_buffer then
            buf_index = i
        end
    end

    vim.api.nvim_win_set_cursor(win, { 5 + buf_index, M.options["padding_left"] })

    vim.api.nvim_buf_set_option(buf, "modifiable", false)
end


M.setup()
--M.show_buffer_list()

return M
