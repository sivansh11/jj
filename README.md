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
- `d` (in visual line mode) - Diff between start and end changes (Note: requires vscode-diff plugin)
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

- Note: if you press enter on @ change it will show status
- in the status window, pressing enter on file will open that file

![status-enter](https://media.githubusercontent.com/media/sivansh11/jj/refs/heads/main/assets/status-enter.gif)

## log-n
- n to create a new change

![log-n](https://media.githubusercontent.com/media/sivansh11/jj/refs/heads/main/assets/log-n.gif)

## log-u
- u to undo last jj operation

![log-u](https://media.githubusercontent.com/media/sivansh11/jj/refs/heads/main/assets/log-u.gif)

## log-ctrl-r
- ctrl-r to redo last jj operation

![log-ctrl-r](https://media.githubusercontent.com/media/sivansh11/jj/refs/heads/main/assets/log-ctrl-r.gif)

## log-a
- a to abandon change

![log-a](https://media.githubusercontent.com/media/sivansh11/jj/refs/heads/main/assets/log-a.gif)

## log-d
- d to describe change

![log-d](https://media.githubusercontent.com/media/sivansh11/jj/refs/heads/main/assets/log-d.gif)

## log-s
- s to squash change

![log-s](https://media.githubusercontent.com/media/sivansh11/jj/refs/heads/main/assets/log-s.gif)

## log-m
- m to rebase change

![log-m](https://media.githubusercontent.com/media/sivansh11/jj/refs/heads/main/assets/log-m.gif)

## log-b
- b to set/create bookmark

![log-b](https://media.githubusercontent.com/media/sivansh11/jj/refs/heads/main/assets/log-b.gif)

## log-r
- r to set working revset

![log-r](https://media.githubusercontent.com/media/sivansh11/jj/refs/heads/main/assets/log-r.gif)

## log-visual-d
- d in *visual mode* to diff changes

![log-visual-d](https://media.githubusercontent.com/media/sivansh11/jj/refs/heads/main/assets/log-visual-d.gif)

## log-visual-n
- n in *visual mode* to merge changes

![log-visual-n](https://media.githubusercontent.com/media/sivansh11/jj/refs/heads/main/assets/log-visual-n.gif)

## log-ctrl-s
- ctrl-s to split change

![log-ctrl-s](https://media.githubusercontent.com/media/sivansh11/jj/refs/heads/main/assets/log-ctrl-s.gif)

