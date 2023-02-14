local config = require("nvim-lsp-extras.config")

local M = {}

function M.is_rule(line)
    return line and line:find("^%s*[%*%-_][%*%-_][%*%-_]+%s*$")
end

local function is_code_block(line)
    return line and line:find("^%s*```")
end

local function is_empty(line)
    return line and line:find("^%s*$")
end

---@param text string
local function html_entities(text)
    local entities = { nbsp = "", lt = "<", gt = ">", amp = "&", quot = '"' }
    for entity, char in pairs(entities) do
        text = text:gsub("&" .. entity .. ";", char)
    end
    return text
end

---@param text string
function M.parse(text)
    ---@type string
    text = text:gsub("</?pre>", "```")
    text = html_entities(text)

    local ret = {}

    local lines = vim.split(text, "\n")

    local l = 1

    local function eat_nl()
        while is_empty(lines[l + 1]) do
            l = l + 1
        end
    end

    while l <= #lines do
        local line = lines[l]
        if is_empty(line) then
            local is_start = l == 1
            eat_nl()
            local is_end = l == #lines
            if not (is_code_block(lines[l + 1]) or M.is_rule(lines[l + 1]) or is_start or is_end) then
                table.insert(ret, { line = "" })
            end
        elseif is_code_block(line) then
            ---@type string
            local lang = line:match("```(%S+)") or "text"
            local block = { lang = lang, code = {} }
            while lines[l + 1] and not is_code_block(lines[l + 1]) do
                table.insert(block.code, lines[l + 1])
                l = l + 1
            end

            local prev = ret[#ret]
            if prev and not M.is_rule(prev.line) then
                table.insert(ret, { line = "" })
            end

            table.insert(ret, block)
            l = l + 1
            eat_nl()
        elseif M.is_rule(line) then
            table.insert(ret, { line = "---" })
            eat_nl()
        else
            local prev = ret[#ret]
            if prev and prev.code then
                table.insert(ret, { line = "" })
            end
            table.insert(ret, { line = line })
        end
        l = l + 1
    end

    return ret
end

function M.get_highlights(line)
    local ret = {}
    for pattern, hl_group in pairs(config.get("treesitter_hover").highlights) do
        local from = 1
        while from do
            local to, match
            from, to, match = line:find(pattern, from)
            if match then
                from, to = line:find(match, from)
            end
            if from then
                table.insert(ret, {
                    hl_group = hl_group,
                    col = from - 1,
                    length = to - from + 1,
                })
            end
            from = to and to + 1 or nil
        end
    end
    return ret
end

local function open(uri)
    local cmd
    if vim.fn.has("win32") == 1 then
        cmd = { "cmd.exe", "/c", "start", '""', vim.fn.shellescape(uri) }
    elseif vim.fn.has("macunix") == 1 then
        cmd = { "open", uri }
    else
        cmd = { "xdg-open", uri }
    end

    local ret = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        local msg = {
            "Failed to open uri",
            ret,
            vim.inspect(cmd),
        }
        vim.notify(table.concat(msg, "\n"), vim.log.levels.ERROR)
    end
end

function M.set_keymap(buf)
    vim.keymap.set("n", "gh", function()
        local line = vim.api.nvim_get_current_line()
        local pos = vim.api.nvim_win_get_cursor(0)
        local col = pos[2] + 1

        local hover = {
            ["|(%S-)|"] = vim.cmd.help,
            ["%[.-%]%((%S-)%)"] = open,
        }

        for pattern, handler in pairs(hover) do
            local from = 1
            local to, url
            while from do
                from, to, url = line:find(pattern, from)
                if from and col >= from and col <= to then
                    return handler(url)
                end
                if from then
                    from = to + 1
                end
            end
        end
        vim.api.nvim_feedkeys("gh", "n", false)
    end, { buffer = buf, silent = true })
end

function M.format_markdown(contents)
    if type(contents) ~= "table" or not vim.tbl_islist(contents) then
        contents = { contents }
    end

    local parts = {}

    for _, content in ipairs(contents) do
        if type(content) == "string" then
            table.insert(parts, content)
        elseif content.language then
            table.insert(parts, ("```%s\n%s\n```"):format(content.language, content.value))
        elseif content.kind == "markdown" then
            table.insert(parts, content.value)
        elseif content.kind == "plaintext" then
            table.insert(parts, ("```\n%s\n```"):format(content.value))
        elseif vim.tbl_islist(content) then
            vim.list_extend(parts, M.format_markdown(content))
        else
            error("Unknown markup " .. vim.inspect(content))
        end
    end

    return vim.split(table.concat(parts, "\n"), "\n")
end

return M
