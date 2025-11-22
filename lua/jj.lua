local M = {}

local utils = require('utils')

local config = {
}

-- jj edit
function M.jj_edit(state, ignore_immutable)
  local change_id = utils.get_change_id()
  if not change_id then
    vim.notify("Change ID not found", vim.log.levels.ERROR)
    return
  end

  local cmd = "jj edit -r " .. change_id
  if ignore_immutable then
    cmd = cmd .. " --ignore-immutable"
  end

  local _, success = utils.run(cmd)
  if not success then
    vim.notify("Edit " .. change_id .. " failed", vim.log.levels.ERROR)
  end

  vim.notify("Editing " .. change_id, vim.log.levels.INFO)

  vim.cmd('checktime')

  local win = vim.fn.bufwinid(state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  M.jj_log()

  win = vim.fn.bufwinid(state.buf)
  vim.api.nvim_win_set_cursor(win, cursor_pos)
end

-- jj undo
function M.jj_undo(state)
  local cmd = "jj undo"

  local output, success = utils.run(cmd)
  if not success then
    vim.notify("EasyJJ: undo not successful", vim.log.levels.ERROR)
    vim.notify(output, vim.log.levels.ERROR)
  end

  vim.notify("EasyJJ: undo", vim.log.levels.INFO)

  vim.cmd('checktime')

  local win = vim.fn.bufwinid(state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  M.jj_log()

  win = vim.fn.bufwinid(state.buf)
  vim.api.nvim_win_set_cursor(win, cursor_pos)
end

-- jj redo
function M.jj_redo(state)
  local cmd = "jj redo"

  local output, success = utils.run(cmd)
  if not success then
    vim.notify("EasyJJ: redo not successful", vim.log.levels.ERROR)
    vim.notify(output, vim.log.levels.ERROR)
  end

  vim.notify("EasyJJ: redo", vim.log.levels.INFO)

  vim.cmd('checktime')

  local win = vim.fn.bufwinid(state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  M.jj_log()

  win = vim.fn.bufwinid(state.buf)
  vim.api.nvim_win_set_cursor(win, cursor_pos)
end

-- jj new
function M.jj_new(state)
  local change_id = utils.get_change_id()
  if not change_id then
    vim.notify("Change ID not found", vim.log.levels.ERROR)
    return
  end

  local cmd = "jj new -r " .. change_id

  local output, success = utils.run(cmd)
  if not success then
    vim.notify("EasyJJ: new not successful", vim.log.levels.ERROR)
    vim.notify(output, vim.log.levels.ERROR)
  end

  vim.notify("EasyJJ: new", vim.log.levels.INFO)

  vim.cmd('checktime')

  local win = vim.fn.bufwinid(state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  M.jj_log()

  win = vim.fn.bufwinid(state.buf)
  vim.api.nvim_win_set_cursor(win, cursor_pos)
end

function M.jj_log_keymaps(state)
  -- Close jj-log
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_buf_delete(state.buf, { force = true })
    state.buf = nil
  end, {
    buffer = state.buf,
    desc = "Close jj buffer"
  })
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_buf_delete(state.buf, { force = true })
    state.buf = nil
  end, {
    buffer = state.buf,
    desc = "Close jj buffer"
  })

  -- Edit
  vim.keymap.set('n', 'e', function()
    M.jj_edit(state, false)
  end, {
    buffer = state.buf,
    desc = "Edit"
  })
  vim.keymap.set('n', 'e', function()
    M.jj_edit(state, true)
  end, {
    buffer = state.buf,
    desc = "Edit(immutable)"
  })

  -- Undo
  vim.keymap.set('n', 'u', function()
    M.jj_undo(state)
  end, {
    buffer = state.buf,
    desc = "Undo"
  })

  -- Redo
  vim.keymap.set('n', '<C-r>', function()
    M.jj_redo(state)
  end, {
    buffer = state.buf,
    desc = "Redo"
  })

  -- New
  vim.keymap.set('n', 'n', function()
    M.jj_new(state)
  end, {
    buffer = state.buf,
    desc = "New"
  })

  local disabled_keys = { "i", "c", "a" }
  for _, key in ipairs(disabled_keys) do
    vim.keymap.set({ "n", "v" }, key, function() end, {
      buffer = state.buf,
      desc = "Disabled"
    })
  end
end

function M.jj_log()
  utils.run_and_display("jj log --no-pager", "jj-log", M.jj_log_keymaps)
end

function M.setup(user_config)
  config = vim.tbl_deep_extend('force', config, user_config or {})

  vim.api.nvim_create_user_command('J', function()
    M.jj_log()
  end, {
    desc = 'Show jj log in configured style (split or float)'
  })
end

return M
