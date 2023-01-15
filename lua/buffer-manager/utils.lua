local utils = {}

function round(float)
    return math.floor(float + .5)
end

function center(str)
    local width = vim.api.nvim_win_get_width(0)
    local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
    return string.rep(" ", shift) .. str
end

return utils
