local M = {}

local default = {
    signature = {
        border = "rounded",
    },
    mouse_hover = {
        border = "rounded",
    },
    lightbulb = {
        icon = "",
        diagnostic_only = true,
    },
    treesitter_hover = {
        highlights = {
            ["|%S-|"] = "@text.reference",
            ["@%S+"] = "@parameter",
            ["^%s*(Parameters:)"] = "@text.title",
            ["^%s*(Return:)"] = "@text.title",
            ["^%s*(See also:)"] = "@text.title",
            ["{%S-}"] = "@parameter",
        },
    },
}

local config = {}

M.set = function(user_options)
    user_options = user_options or {}
    config = vim.tbl_extend("force", default, user_options)
    return config
end

M.get_all = function()
    return config
end

M.get = function(key)
    return config[key]
end

return M
