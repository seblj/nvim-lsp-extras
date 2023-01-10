# nvim-lsp-extras

Some extra functionality I use to make neovim lsp a bit better. Depends on new functionality in Neovim 0.9 that was merged 10.01.2023

## Installation

### lazy.nvim

```lua
require('lazy').setup({
    { 'seblj/nvim-lsp-extras' },
})
```

### packer.nvim

```lua
use({ 'seblj/nvim-lsp-extras' })
```

## Setup

This plugin provides a setup function with the following default values.
Each module can be set to `false` if you do not wish the functionality

```lua
require('nvim-lsp-extras').setup({
    signature = {
        border = 'rounded',
    },
    mouse_hover = {
        border = 'rounded',
    },
    lightbulb = {
        icon = '',
        diagnostic_only = true, -- Only lightbulb if line contains diagnostic
    },
})
```
