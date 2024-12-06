local utils = {}

function round(float)
    return math.floor(float + .5)
end

function center(str)
    local width = vim.api.nvim_win_get_width(0)
    local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
    return string.rep(" ", shift) .. str
end

function get_main_buffer_behind_floating()
    local current_win = vim.api.nvim_get_current_win()
    local wins = vim.api.nvim_tabpage_list_wins(0)

    for _, win in ipairs(wins) do
        local config = vim.api.nvim_win_get_config(win)
        if config.relative == "" and win ~= current_win then
            return vim.api.nvim_win_get_buf(win)
        end
    end

    return nil -- No main buffer found
end

return utils
