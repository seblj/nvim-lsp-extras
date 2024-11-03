local M = {}

---@param client vim.lsp.Client
M.setup = function(client, bufnr)
    local config = require("nvim-lsp-extras.config")
    if not client.server_capabilities.signatureHelpProvider then
        return
    end

    vim.api.nvim_create_autocmd("TextChangedI", {
        group = vim.api.nvim_create_augroup(string.format("LspSignature_%s_%s", client.name, bufnr), { clear = false }),
        buffer = bufnr,
        callback = function()
            local active = vim.lsp.get_client_by_id(client.id)
            if not active then
                return
            end

            local pos = vim.api.nvim_win_get_cursor(0)
            local line_to_cursor = vim.api.nvim_get_current_line():sub(pos[2] - 1, pos[2])
            for _, trigger_char in ipairs(active.server_capabilities.signatureHelpProvider.triggerCharacters or {}) do
                local current_char = line_to_cursor:sub(#line_to_cursor, #line_to_cursor)
                local prev_char = line_to_cursor:sub(#line_to_cursor - 1, #line_to_cursor - 1)

                if current_char == trigger_char or (current_char == " " and prev_char == trigger_char) then
                    vim.lsp.buf.signature_help({
                        border = config.get("global").border or config.get("signature").border,
                        silent = true,
                        focusable = false,
                    })
                end
            end
        end,
        desc = "Start lsp signature",
    })
end

-- Hack to highlight active signature because of `open_floating_preview`
-- override I have
local orig_hl_range = vim.hl.range
---@diagnostic disable-next-line: duplicate-set-field
vim.hl.range = function(bufnr, ns, higroup, start, finish, opts)
    if ns == vim.api.nvim_get_namespaces()["vim_lsp_signature_help"] then
        return orig_hl_range(bufnr, ns, higroup, { start[1] - 1, start[2] }, { finish[1] - 1, finish[2] }, opts)
    else
        return orig_hl_range(bufnr, ns, higroup, start, finish, opts)
    end
end

return M
