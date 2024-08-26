local M = {}
local util = require("vim.lsp.util")
local handler
local clients = {}

local check_trigger_char = function(line_to_cursor, triggers)
    if not triggers then
        return false
    end

    for _, trigger_char in ipairs(triggers) do
        local current_char = line_to_cursor:sub(#line_to_cursor, #line_to_cursor)
        local prev_char = line_to_cursor:sub(#line_to_cursor - 1, #line_to_cursor - 1)
        if current_char == trigger_char then
            return true
        end
        if current_char == " " and prev_char == trigger_char then
            return true
        end
    end
    return false
end

local open_signature = function()
    local triggered = false

    for _, client in pairs(clients) do
        local pos = vim.api.nvim_win_get_cursor(0)
        local line = vim.api.nvim_get_current_line()
        local line_to_cursor = line:sub(1, pos[2])

        if not triggered then
            local triggers = client.server_capabilities.signatureHelpProvider.triggerCharacters
            triggered = check_trigger_char(line_to_cursor, triggers)
        end
    end

    if triggered then
        local params = util.make_position_params()
        vim.lsp.buf_request(0, "textDocument/signatureHelp", params, handler)
    end
end

M.setup = function(client)
    local config = require("nvim-lsp-extras.config")
    if not client.server_capabilities.signatureHelpProvider then
        return
    end
    handler = vim.lsp.with(vim.lsp.handlers.signature_help, {
        border = config.get("global").border or config.get("signature").border,
        silent = true,
        focusable = false,
    })

    table.insert(clients, client)

    local group = vim.api.nvim_create_augroup("LspSignature", { clear = false })
    vim.api.nvim_clear_autocmds({ group = group, pattern = "<buffer>" })
    vim.api.nvim_create_autocmd("TextChangedI", {
        group = group,
        pattern = "<buffer>",
        callback = function()
            -- Guard against spamming of method not supported after
            -- stopping a language serer with LspStop
            local active_clients = vim.lsp.get_clients()
            for _, c in ipairs(active_clients) do
                if c.server_capabilities.signatureHelpProvider then
                    open_signature()
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
    local lines, hl = util.convert_signature_help_to_markdown_lines(result, ft, triggers)
    if not lines or vim.tbl_isempty(lines) then
        if config.silent ~= true then
            print("No signature help available")
        end
        return
    end
    local fbuf, fwin = util.open_floating_preview(lines, "markdown", config)
    if hl then
        vim.api.nvim_buf_add_highlight(fbuf, -1, "LspSignatureActiveParameter", 0, unpack(hl))
    end
    return fbuf, fwin
end

return M
