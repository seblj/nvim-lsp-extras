# nvim-lsp-extras

Some extra functionality I use to make neovim lsp a bit better.

## Requirements

- Neovim 0.9

## Installation

### lazy.nvim

```lua
require("lazy").setup({
    { "seblj/nvim-lsp-extras" },
})
```

### packer.nvim

```lua
use({ "seblj/nvim-lsp-extras" })
```

## Setup

This plugin provides a setup function with the following default values.
Each module can be set to `false` if you do not wish the functionality

```lua
require("nvim-lsp-extras").setup({
    signature = {
        border = "rounded",
    },
    mouse_hover = {
        border = "rounded",
    },
    lightbulb = {
        icon = "",
        diagnostic_only = true, -- Only lightbulb if line contains diagnostic
    },
    treesitter_hover = {
        highlights = {
            ["|%S-|"] = "@text.reference",
            ["@%S+"] = "@parameter",
            ["^%s*(Parameters:)"] = "@text.title",
            ["^%s*(Return:)"] = "@text.title",
            ["^%s*(See also:)"] = "@text.title",
            ["{%S-}"] = "@parameter",
        },
    },
})
```

## Acknowledgement

Huge thanks to [`noice.nvim`](https://github.com/folke/noice.nvim) for initial
implementation of treesitter injection in lsp hover doc. Check it out for an
awesome UI-experience in neovim
