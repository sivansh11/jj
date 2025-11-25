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
- `d` (in visual line mode) - Diff between start and end changes
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

Basic Usage Example

![Basic usage](assets/J-enter-n.gif)

Abandon-undo-redo Example

![Abandon](assets/Abandon-undo-redo.gif)

Squash-undo-redo Example

![Squash](assets/Squash-undo-redo.gif)

Describe Example

![Describe](assets/Describe.gif)

Diff Example

![Diff](assets/Diff.gif)

Bookmarks Example

![Bookmarks](assets/Bookmarks.gif)

Status-file-nav Example

![Status](assets/Status-file-nav.gif)
