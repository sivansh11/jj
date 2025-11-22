local M = {}

local state = {
  buf = nil
}

-- Run command and display its result in a buffer
function M.run_and_display(cmd, name, set_keymaps_callback)
  if state.buf then
    vim.api.nvim_buf_delete(state.buf, { force = true })
    state.buf = nil
  end
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(state.buf, name)

  if set_keymaps_callback then
    set_keymaps_callback(state)
  end

  vim.api.nvim_open_win(state.buf, true, {
    split = 'below',
    win = 0,
  })

  local chan = vim.api.nvim_open_term(state.buf, {})
  local job_id = vim.fn.jobstart(cmd, {
    pty = true,
    on_stdout = function(_, data)
      local output = table.concat(data, '\n')
      vim.api.nvim_chan_send(chan, output)
    end,
    on_exit = function(_, _)
      vim.bo[state.buf].modifiable = false
    end
  })

  if job_id <= 0 then
    vim.notify("Failed to start job with cmd: " .. cmd, vim.log.levels.ERROR)
  end
end

return M
