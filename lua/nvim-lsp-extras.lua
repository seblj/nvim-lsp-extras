local M = {}
local config = require("nvim-lsp-extras.config")

M.setup = function(opts)
    config.set(opts)

    for conf, _ in pairs(config.get()) do
        if config.get(conf) then
            vim.api.nvim_create_autocmd("LspAttach", {
                pattern = "*",
                group = vim.api.nvim_create_augroup(string.format("%sLspExtra", conf), { clear = true }),
                callback = function(args)
                    local client = vim.lsp.get_client_by_id(args.data.client_id)
                    require(string.format("nvim-lsp-extras.%s", conf)).setup(client)
                end,
            })
        end
    end
end

return M
