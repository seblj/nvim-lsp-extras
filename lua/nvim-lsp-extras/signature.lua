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
                    return active.request(
                        "textDocument/signatureHelp",
                        vim.lsp.util.make_position_params(),
                        vim.lsp.with(vim.lsp.handlers.signature_help, {
                            border = config.get("global").border or config.get("signature").border,
                            silent = true,
                            focusable = false,
                        }),
                        bufnr
                    )
                end
            end
        end,
        desc = "Start lsp signature",
    })
end

-- Hack to highlight active signature because of `open_floating_preview`
-- override I have
---@diagnostic disable-next-line: duplicate-set-field
vim.lsp.handlers.signature_help = function(_, result, ctx, config)
    config = config or {}
    config.focus_id = ctx.method
    if vim.api.nvim_get_current_buf() ~= ctx.bufnr then
        -- Ignore result since buffer changed. This happens for slow language servers.
        return
    end
    -- When use `autocmd CompleteDone <silent><buffer> lua vim.lsp.buf.signature_help()` to call signatureHelp handler
    -- If the completion item doesn't have signatures It will make noise. Change to use `print` that can use `<silent>` to ignore
    if not (result and result.signatures and result.signatures[1]) then
        if config.silent ~= true then
            print("No signature help available")
        end
        return
    end
    local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
    local triggers = vim.tbl_get(client.server_capabilities, "signatureHelpProvider", "triggerCharacters")
    local ft = vim.bo[ctx.bufnr].filetype
    local lines, hl = vim.lsp.util.convert_signature_help_to_markdown_lines(result, ft, triggers)
    if not lines or vim.tbl_isempty(lines) then
        if config.silent ~= true then
            print("No signature help available")
        end
        return
    end
    local fbuf, fwin = vim.lsp.util.open_floating_preview(lines, "markdown", config)
    if hl then
        vim.api.nvim_buf_add_highlight(fbuf, -1, "LspSignatureActiveParameter", 0, unpack(hl))
    end
    return fbuf, fwin
end

return M
