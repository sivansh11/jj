# jj.nvim

jj (Jujutsu VCS) integrations for Neovim

## Installation

Install the plugin using your favourite plugin manager:

```lua
-- Using vim.pack (Neovim 0.12+)
vim.pack.add{'https://github.com/sivansh11/jj'}

-- Using packer.nvim
use {'sivansh11/jj'}

-- Using lazy.nvim
{
  'sivansh11/jj',
  config = function()
    require('jj').setup()
  end
}
```

## Usage

Run `:J` to open the jj panel

### Keymaps

- `Enter` - Edit the selected change
- `s` - Squash `@` into the selected change
- `u` - Undo
- `Ctrl+r` - Redo
- `d` - Describe the selected change
- `q` or `Esc` - Close the panel

### Special Operations

- If the selected change is `@`, it will transition to show the status
- If a change is immutable, you can force operations by pressing `Shift` with the key:
  - `Shift+Enter` - Edit immutable change
  - `Shift+S` - Squash into immutable change
  - `Shift+D` - Describe immutable change

## Features

- Interactive jj log viewer with syntax highlighting
- Change editing, squashing, and describing
- Undo/redo operations
- Status viewing
- Support for immutable changes with force operations
