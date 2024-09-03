local sign_name = "LightbulbSign"
local sign_group = "LightbulbGroup"
local old_line = nil
local config = require("nvim-lsp-extras.config")
local M = {}

local changed_line = function(lnum)
    if lnum == old_line then
        return false
    end
    old_line = lnum
    return true
end

---@param client vim.lsp.Client
local check_code_action = function(client, bufnr)
    local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
    local params = vim.lsp.util.make_range_params()
    params.context = {
        diagnostics = vim.tbl_map(function(d)
            return d.user_data.lsp
        end, vim.diagnostic.get(0, { lnum = lnum })),
    }

    client.request("textDocument/codeAction", params, function(_, results)
        if #(results and results[1] or {}) > 0 then
            return vim.fn.sign_unplace(sign_group)
        end

        -- Only show actions if there are diagnostics
        if config.get("lightbulb").diagnostic_only and #params.context.diagnostics == 0 then
            return vim.fn.sign_unplace(sign_group)
        end

        if changed_line(lnum) then
            vim.fn.sign_unplace(sign_group)
        end
        vim.fn.sign_place(0, sign_group, sign_name, bufnr, { lnum = vim.fn.line("."), priority = 1000 })
    end)
end

M.setup = function(client)
    if not client.supports_method("textDocument/codeAction") then
        return
    end
    vim.fn.sign_define(sign_name, { text = config.get("lightbulb").icon, texthl = "DiagnosticInfo" })

    local group = vim.api.nvim_create_augroup("SetupLightbulb", { clear = false })
    vim.api.nvim_clear_autocmds({ group = group, pattern = "<buffer>" })
    vim.api.nvim_create_autocmd({ "CursorHold", "CursorMoved" }, {
        group = group,
        pattern = "<buffer>",
        callback = function(args)
            if vim.fn.mode() ~= "n" then
                return
            end
            -- Always check that at least one client is supporting this, as a server coul be stopped
            local active_clients = vim.lsp.get_clients()
            for _, c in ipairs(active_clients) do
                if c.supports_method("textDocument/codeAction") then
                    check_code_action(c, args.buf)
                end
            end
        end,
        desc = "Start lightbulb for code actions",
    })
end

return M
