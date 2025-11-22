# jj

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

### Keymaps (log)

- `Enter` - Edit the selected change
- `s` - Squash `@` into the selected change
- `n` - Create new change from selected change
- `u` - Undo
- `Ctrl+r` - Redo
- `d` - Describe the selected change
- `r` - Set custom revset
- `b` - Bookmark operations
- `q` or `Esc` - Close the panel

### Keymaps (status)

- `Enter` - Open file

### Special Operations

- If a change is immutable, you can force operations by pressing `Shift` with the key:
  - `Shift+Enter` - Edit immutable change
  - `Shift+S` - Squash into immutable change
  - `Shift+D` - Describe immutable change
- In status view, press `Enter` on a file to open it

## Features

- Interactive jj log viewer with syntax highlighting
- Change editing, squashing, and describing
- Change creation from existing changes
- Undo/redo operations
- Status viewing with file navigation
- Bookmark management (create, set)
- Custom revset support
- Support for immutable changes with force operations

Here is a video of me messing around with jj<br>
[![Watch the demo](https://img.youtube.com/vi/15dgpAzwx5A/0.jpg)](https://www.youtube.com/watch?v=15dgpAzwx5A)
