local api = vim.api
local npcall = vim.F.npcall

local function close_preview_window(winnr, bufnrs)
    vim.schedule(function()
        -- exit if we are in one of ignored buffers
        if bufnrs and vim.list_contains(bufnrs, api.nvim_get_current_buf()) then
            return
        end

        local augroup = "preview_window_" .. winnr
        pcall(api.nvim_del_augroup_by_name, augroup)
        pcall(api.nvim_win_close, winnr, true)
    end)
end

local function close_preview_autocmd(events, winnr, bufnrs)
    local augroup = api.nvim_create_augroup("preview_window_" .. winnr, {
        clear = true,
    })

    -- close the preview window when entered a buffer that is not
    -- the floating window buffer or the buffer that spawned it
    api.nvim_create_autocmd("BufEnter", {
        group = augroup,
        callback = function()
            close_preview_window(winnr, bufnrs)
        end,
    })

    if #events > 0 then
        api.nvim_create_autocmd(events, {
            group = augroup,
            buffer = bufnrs[2],
            callback = function()
                close_preview_window(winnr)
            end,
        })
    end
end

local function find_window_by_var(name, value)
    for _, win in ipairs(api.nvim_list_wins()) do
        if npcall(api.nvim_win_get_var, win, name) == value then
            return win
        end
    end
end

function vim.lsp.util.open_floating_preview(contents, syntax, opts)
    vim.validate({
        contents = { contents, "t" },
        syntax = { syntax, "s", true },
        opts = { opts, "t", true },
    })
    opts = opts or {}
    opts.wrap = opts.wrap ~= false -- wrapping by default
    opts.stylize_markdown = opts.stylize_markdown ~= false and vim.g.syntax_on ~= nil
    opts.focus = opts.focus ~= false
    opts.close_events = opts.close_events or { "CursorMoved", "CursorMovedI", "InsertCharPre" }

    local bufnr = api.nvim_get_current_buf()

    -- check if this popup is focusable and we need to focus
    if opts.focus_id and opts.focusable ~= false and opts.focus then
        -- Go back to previous window if we are in a focusable one
        local current_winnr = api.nvim_get_current_win()
        if npcall(api.nvim_win_get_var, current_winnr, opts.focus_id) then
            api.nvim_command("wincmd p")
            return bufnr, current_winnr
        end
        do
            local win = find_window_by_var(opts.focus_id, bufnr)
            if win and api.nvim_win_is_valid(win) and vim.fn.pumvisible() == 0 then
                -- focus and return the existing buf, win
                api.nvim_set_current_win(win)
                api.nvim_command("stopinsert")
                return api.nvim_win_get_buf(win), win
            end
        end
    end

    -- check if another floating preview already exists for this buffer
    -- and close it if needed
    local existing_float = npcall(api.nvim_buf_get_var, bufnr, "lsp_floating_preview")
    if existing_float and api.nvim_win_is_valid(existing_float) then
        api.nvim_win_close(existing_float, true)
    end

    local floating_bufnr = api.nvim_create_buf(false, true)
    local do_stylize = syntax == "markdown" and opts.stylize_markdown

    -- Clean up input: trim empty lines from the end, pad
    contents = vim.split(table.concat(contents, "\n"), "\n", { trimempty = true })

    if do_stylize then
        -- applies the syntax and sets the lines to the buffer
        contents = vim.lsp.util.stylize_markdown(floating_bufnr, contents, opts)
    else
        if syntax then
            vim.bo[floating_bufnr].syntax = syntax
        end
        api.nvim_buf_set_lines(floating_bufnr, 0, -1, true, contents)
    end

    -- Compute size of float needed to show (wrapped) lines
    if opts.wrap then
        opts.wrap_at = opts.wrap_at or api.nvim_win_get_width(0)
    else
        opts.wrap_at = nil
    end
    local width, height = vim.lsp.util._make_floating_popup_size(contents, opts)

    local float_option = vim.lsp.util.make_floating_popup_options(width, height, opts)
    local floating_winnr = api.nvim_open_win(floating_bufnr, false, float_option)
    if do_stylize then
        vim.wo[floating_winnr].conceallevel = 2
        vim.wo[floating_winnr].concealcursor = "n"
    end
    -- disable folding
    vim.wo[floating_winnr].foldenable = false
    -- soft wrapping
    vim.wo[floating_winnr].wrap = opts.wrap

    vim.bo[floating_bufnr].modifiable = false
    vim.bo[floating_bufnr].bufhidden = "wipe"
    api.nvim_buf_set_keymap(
        floating_bufnr,
        "n",
        "q",
        "<cmd>bdelete<cr>",
        { silent = true, noremap = true, nowait = true }
    )
    close_preview_autocmd(opts.close_events, floating_winnr, { floating_bufnr, bufnr })

    -- save focus_id
    if opts.focus_id then
        api.nvim_win_set_var(floating_winnr, opts.focus_id, bufnr)
    end
    api.nvim_buf_set_var(bufnr, "lsp_floating_preview", floating_winnr)

    return floating_bufnr, floating_winnr
end
