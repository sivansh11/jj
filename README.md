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

Run `:Jsplit` to open the jj split panel

Run `:Jresolve` to open the jj resolve panel

### Keymaps (log)

- `Enter` - Edit the selected change
- `s` - Squash `@` into the selected change
- `n` - Create new change from selected change
- `u` - Undo
- `Ctrl+r` - Redo
- `d` - Describe the selected change
- `r` - Set custom revset
- `b` - Bookmark operations
- `a` - Abandon change
- `m` - Rebase change
- `p` - Push change
- `f` - Fetch change
- `Ctrl+s` - Split change
- `d` (in visual line mode) - Diff between start and end changes (Note: requires diffview plugin)
- `n` (in visual line mode) - New over start and end changes
- `q` or `Esc` - Close the panel

### Keymaps (status)

- `Enter` - Open file

### Special Operations

- If a change is immutable, you can force operations by pressing `Shift` with the key:
  - `Shift+Enter` - Edit immutable change
  - `Shift+S` - Squash into immutable change
  - `Shift+D` - Describe immutable change
  - `Shift+A` - Abandon immutable change
    - Note: this is not an exhaustible list, if you ever get a notification that the change is immutable try it with Shift
    - Note: `Ctrl+Shift+s` might not work on some terminals, check if your terminal properly emmits s with ctrl and shift modifiers
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

## About vim.ui.input and vim.ui.select

- If your bookmark selection panel or the revset/bookmark name input box appears visually inconsistent, you need to check that your chosen plugin provides overrides for the vim.ui.input and vim.ui.select functions.

# Basic Usage Example
!!! WARNING: This Section is in progress !!!

## log-Enter
- :J to open jj log
- enter on change to edit

![log-enter](https://media.githubusercontent.com/media/sivansh11/jj/refs/heads/main/assets/log-enter.gif)
