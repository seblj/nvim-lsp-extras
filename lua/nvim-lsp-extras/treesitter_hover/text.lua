local treesitter = require("nvim-lsp-extras.treesitter_hover.treesitter")
local syntax = require("nvim-lsp-extras.treesitter_hover.syntax")
local markdown = require("nvim-lsp-extras.treesitter_hover.markdown")

local M = {}

local function conceal_escape_characters(buf, ns, range)
    local chars = "\\`*_{}[]()#+-.!"
    local regex = "\\["
    for i = 1, #chars do
        regex = regex .. "%" .. chars:sub(i, i)
    end
    regex = regex .. "]"

    local lines = vim.api.nvim_buf_get_lines(buf, range[1], range[3] + 1, false)

    for l, line in ipairs(lines) do
        local c = line:find(regex)
        while c do
            vim.api.nvim_buf_set_extmark(buf, ns, range[1] + l - 1, c - 1, {
                end_col = c,
                conceal = "",
            })
            c = line:find(regex, c + 1)
        end
    end
end

local function highlight(extmark, bufnr, ns_id, linenr, byte_start)
    if not extmark then
        return
    end

    if extmark.lang then
        local range = { linenr - extmark.lines, extmark.col and byte_start + extmark.col - 1 or 0, linenr, byte_start }
        if vim.treesitter.language.require_language(extmark.lang, nil, true) then
            treesitter.highlight(bufnr, ns_id, range, extmark.lang)
        else
            syntax.highlight(bufnr, ns_id, range, extmark.lang)
        end
        if extmark.lang == "markdown" then
            conceal_escape_characters(bufnr, ns_id, range)
        end
    else
        local length = 0
        if extmark.length then
            length = extmark.length
            extmark.length = nil
        end

        if extmark.col then
            byte_start = extmark.col
            extmark.col = nil
        end

        extmark.end_col = byte_start + length
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, linenr - 1, byte_start, extmark)
    end
end

---@param bufnr number buffer number
---@param ns_id number namespace id
function M.render(text, bufnr, ns_id)
    for i, line in ipairs(text) do
        vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { line.content })
        for _, extmark in ipairs(line.extmarks) do
            highlight(extmark, bufnr, ns_id, i, vim.fn.strlen(line.content))
        end
    end
end

local function newline(tbl)
    table.insert(tbl, { content = "", extmarks = {} })
end

local function append(tbl, item)
    if #tbl == 0 then
        newline(tbl)
    end
    if type(item) == "string" then
        tbl[#tbl].content = item
    else
        table.insert(tbl[#tbl].extmarks, item)
    end
end

local function append_string(tbl, content)
    local text = content:gsub("\r\n", "\n")

    while text ~= "" do
        local nl = text:find("\n")
        if nl then
            local str = text:sub(1, nl - 1)

            -- handle carriage returns. They overwrite the line from the first character
            if str:find("\r") then
                local parts = vim.split(str, "\r", { plain = true })
                str = ""
                for _, p in ipairs(parts) do
                    str = p .. str:sub(p:len() + 1)
                end
            end

            append(tbl, content)
            newline(tbl)
            text = text:sub(nl + 1)
        else
            append(tbl, content)
            break
        end
    end
end

function M.format(text)
    local blocks = markdown.parse(text)
    local md_lines = 0
    local ret = {}

    for _, block in ipairs(blocks) do
        if block.code then
            if md_lines > 0 then
                append(ret, { lang = "markdown", lines = md_lines })
                md_lines = 0
            end
            newline(ret)
            for c, line in ipairs(block.code) do
                append_string(ret, line)
                if c == #block.code then
                    append(ret, { lang = block.lang, lines = #block.code })
                else
                    newline(ret)
                end
            end
        else
            newline(ret)
            if markdown.is_rule(block.line) then
                append(ret, {
                    virt_text_win_col = 0,
                    virt_text = { { string.rep("─", vim.go.columns), "@punctuation.special.markdown" } },
                    priority = 100,
                })
            else
                append_string(ret, block.line)
                for _, t in ipairs(markdown.get_highlights(block.line)) do
                    append(ret, t)
                end
                md_lines = md_lines + 1
            end
        end
    end
    if md_lines > 0 then
        append(ret, { lang = "markdown", lines = md_lines })
        md_lines = 0
    end
    return ret
end

return M
