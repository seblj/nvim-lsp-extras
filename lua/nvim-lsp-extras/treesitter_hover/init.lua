local text = require("nvim-lsp-extras.treesitter_hover.text")
local markdown = require("nvim-lsp-extras.treesitter_hover.markdown")

-- Hack to override vim.lsp.util.open_floating_preview as I don't like the way
-- it looks in master
if vim.lsp.util._normalize_markdown then
    require("nvim-lsp-extras.treesitter_hover.hack")
end

local M = {}

M.ns = vim.api.nvim_create_namespace("lsp_markdown_highlight")

local function on_module(module, fn)
    if package.loaded[module] then
        return fn(package.loaded[module])
    end

    package.preload[module] = function()
        package.preload[module] = nil
        for _, loader in pairs(package.loaders) do
            local ret = loader(module)
            if type(ret) == "function" then
                local mod = ret()
                fn(mod)
                return mod
            end
        end
    end
end

--- Return empty table if contents only contains empty strings
local function assert_content(contents)
    -- Avoid that the content is only a table of empty strings
    for _, line in ipairs(contents) do
        if line ~= "" then
            return contents
        end
    end
    return {}
end

function M.setup()
    on_module("cmp.entry", function(mod)
        mod.get_documentation = function(self)
            local item = self:get_completion_item()

            local lines = item.documentation and markdown.format_markdown(item.documentation) or {}
            local ret = table.concat(lines, "\n")

            if item.detail and not ret:find(item.detail, 1, true) then
                local ft = self.context.filetype
                local dot_index = string.find(ft, "%.")
                if dot_index ~= nil then
                    ft = string.sub(ft, 0, dot_index - 1)
                end
                ret = ("```%s\n%s\n```\n%s"):format(ft, vim.trim(item.detail), ret)
            end
            return vim.split(ret, "\n")
        end
    end)

    ---@diagnostic disable-next-line: duplicate-set-field
    vim.lsp.util.convert_input_to_markdown_lines = function(input, contents)
        contents = contents or {}
        local ret = markdown.format_markdown(input)
        vim.list_extend(contents, ret)
        return assert_content(contents)
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    vim.lsp.util.stylize_markdown = function(buf, contents, _)
        vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
        local content = table.concat(contents, "\n")
        local formatted_text = text.format(content)
        text.render(formatted_text, buf, M.ns)
        markdown.set_keymap(buf)
        return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    end
end

return M
