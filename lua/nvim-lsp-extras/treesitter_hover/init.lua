local text = require("nvim-lsp-extras.treesitter_hover.text")
local markdown = require("nvim-lsp-extras.treesitter_hover.markdown")

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

function M.setup()
    on_module("cmp.entry", function(mod)
        mod.get_documentation = function(self)
            local item = self:get_completion_item()
            return item.documentation and markdown.format_markdown(item.documentation) or {}
        end
    end)

    vim.lsp.util.convert_input_to_markdown_lines = function(input, contents)
        contents = contents or {}
        local ret = markdown.format_markdown(input)
        vim.list_extend(contents, ret)
        return contents
    end

    vim.lsp.util.stylize_markdown = function(buf, contents, _)
        local content = table.concat(contents, "\n")
        local formatted_text = text.format(content)
        text.render(formatted_text, buf, M.ns)
        markdown.set_keymap(buf)
        return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    end
end

return M
