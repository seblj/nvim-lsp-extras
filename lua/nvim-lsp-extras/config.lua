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
}

local config = {}

M.set = function(user_options)
	user_options = user_options or {}
	config = vim.tbl_extend("force", default, user_options)
	return config
end

M.get = function(key)
	return key and config[key] or config
end

return M
