local M = {}
local config = require("nvim-lsp-extras.config")
local util = require("vim.lsp.util")
local popup_bufnr, popup_winnr

local function make_position_param(mouse, bufnr, offset_encoding)
    local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
    if not clients then
        return
    end
    local supports = false
    for _, client in pairs(clients) do
        if client.supports_method("textDocument/hover") then
            supports = true
            break
        end
    end
    if not supports then
        return
    end
    local row = mouse.line - 1
    local col = mouse.column

    offset_encoding = offset_encoding or util._get_offset_encoding(bufnr)
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]
    if not line or #line < col then
        return nil
    end

    col = util._str_utfindex_enc(line, col, offset_encoding)

    return { line = row, character = col }
end

local make_params = function(mouse, bufnr, offset_encoding)
    offset_encoding = offset_encoding or util._get_offset_encoding(bufnr)
    local position = make_position_param(mouse, bufnr, offset_encoding)
    if not position then
        return nil
    end
    return {
        textDocument = util.make_text_document_params(bufnr),
        position = position,
    }
end

local function hover_handler(_, result, _, mouse_config)
    mouse_config = {
        border = config.get("global").border or config.get("mouse_hover").border,
        relative = "mouse",
        max_height = 11,
    }
    if not (result and result.contents) then
        return
    end
    local markdown_lines = util.convert_input_to_markdown_lines(result.contents, {})
    -- Trim empty lines does not trim empty lines if there is only one line and
    -- it is empty
    markdown_lines = util.trim_empty_lines(markdown_lines)
    if vim.tbl_isempty(markdown_lines) or #markdown_lines == 1 and markdown_lines[1] == "" then
        return
    end
    popup_bufnr, popup_winnr = util.open_floating_preview(markdown_lines, "markdown", mouse_config)
    return popup_bufnr, popup_winnr
end

local try_close_window = function(bufnr)
    if bufnr ~= popup_bufnr then
        if popup_winnr and vim.api.nvim_win_is_valid(popup_winnr) then
            vim.schedule(function()
                pcall(vim.api.nvim_win_close, popup_winnr, true)
                popup_winnr = nil
            end)
        end
    end
end

-- Disable hover when these filetypes is open in the window
local disable_filetypes = {
    "TelescopePrompt",
}

M.setup = function(client)
    if not client.supports_method("textDocument/hover") then
        return
    end
    local hover_timer = nil
    vim.o.mousemoveevent = true

    vim.api.nvim_create_autocmd({ "FocusLost", "FocusGained" }, {
        pattern = "*",
        group = vim.api.nvim_create_augroup("HoverFocusClear", { clear = true }),
        callback = function()
            local mouse = vim.fn.getmousepos()
            local bufnr = vim.api.nvim_win_get_buf(mouse.winid)
            try_close_window(bufnr)
        end,
    })

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
            vim.lsp.buf_request(bufnr, "textDocument/hover", params, hover_handler)
        end, 500)
        return "<MouseMove>"
    end, { expr = true })
end

return M
