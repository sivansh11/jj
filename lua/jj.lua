local M = {}

local utils = require('utils')

local config = {
}

local function jj_log_keymaps(state)
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
end

function M.jj_log()
  utils.run_and_display("jj log --no-pager", "jj-log", jj_log_keymaps)
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
