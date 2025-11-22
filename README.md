jj integrations for nvim

install the plugin using your favourite plugin manager
I am on nvim 0.12, so I use vim.pack
vim.pack.add{'https://github.com/sivansh11/jj'}

run :J to open jj panel
press Enter on a change to edit it,
if the change is @, it will transition to show the status
s to squash @ into change
u to undo
ctrl-r to redo
d to describe

if a change is immutable, you can force by pressing shift
