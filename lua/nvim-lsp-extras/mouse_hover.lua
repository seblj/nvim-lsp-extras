local M = {}
local config = require("nvim-lsp-extras.config")
local popup_bufnr, popup_winnr

local make_params = function(mouse, bufnr)
    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    local supports = vim.iter(clients):any(function(client)
        return client.supports_method("textDocument/hover")
    end)

    if not supports then
        return nil
    end

    local line = vim.api.nvim_buf_get_lines(bufnr, mouse.line - 1, mouse.line, true)[1]
    if not line or #line < mouse.column then
        return nil
    end

    local col = vim.lsp.util._str_utfindex_enc(line, mouse.column, vim.lsp.util._get_offset_encoding(bufnr))

    return {
        textDocument = vim.lsp.util.make_text_document_params(bufnr),
        position = { line = mouse.line - 1, character = col },
    }
end

local try_close_window = function(bufnr)
    if bufnr ~= popup_bufnr and popup_winnr and vim.api.nvim_win_is_valid(popup_winnr) then
        vim.schedule(function()
            pcall(vim.api.nvim_win_close, popup_winnr, true)
            popup_winnr = nil
        end)
    end
end

-- Disable hover when these filetypes is open in the window
local disable_filetypes = {
    "TelescopePrompt",
}

---@param client vim.lsp.Client
M.setup = function(client)
    if not client.supports_method("textDocument/hover") then
        return
    end
    local hover_timer = nil
    vim.o.mousemoveevent = true

    vim.keymap.set({ "", "i" }, "<MouseMove>", function()
        if hover_timer then
            hover_timer:close()
        end

        hover_timer = vim.defer_fn(function()
            hover_timer = nil
            for _, win in pairs(vim.fn.getwininfo()) do
                if vim.tbl_contains(disable_filetypes, vim.bo[win.bufnr].ft) then
                    return
                end
            end
            local mouse = vim.fn.getmousepos()
            local bufnr = vim.api.nvim_win_get_buf(mouse.winid)

            try_close_window(bufnr)

            local params = make_params(mouse, bufnr)
            if not params then
                return
            end

            vim.lsp.buf_request(
                bufnr,
                "textDocument/hover",
                params,
                vim.lsp.with(function(_, result, ctx, c)
                    -- Hack to get hover for split which the cursor is not in
                    ctx.bufnr = vim.api.nvim_get_current_buf()
                    popup_bufnr, popup_winnr = vim.lsp.handlers.hover(_, result, ctx, c)
                    return popup_bufnr, popup_winnr
                end, {
                    focusable = false,
                    relative = "mouse",
                    border = config.get("global").border or config.get("mouse_hover").border,
                    silent = true,
                    close_events = { "CursorMoved", "CursorMovedI", "InsertCharPre", "FocusLost", "FocusGained" },
                })
            )
        end, 500)
        return "<MouseMove>"
    end, { expr = true })
end

return M
