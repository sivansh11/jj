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

-- Run command and return its results
function M.run(cmd, input)
  local output
  if input then
    output = vim.fn.system(cmd, input)
  else
    output = vim.fn.system(cmd)
  end
  local success = vim.v.shell_error == 0

  if not success then
    return "", false
  end

  return output, success
end

-- Get Change ID in line
function M.get_change_id_in_line(line)
  -- The change ID is the first word after the symbols and spaces
  local change_id = line:match("^[%s│├─╯○◆×@]+%s+([a-z]+)")

  if not change_id then
    return nil
  end

  -- Verify the change ID exists by checking if jj log -r returns output
  local _, success = M.run("jj log -r " .. change_id)
  if success then
    return change_id
  end

  return nil
end

-- get change id in the current line or the line above
function M.get_change_id()
  local line = vim.api.nvim_get_current_line()
  local change_id = M.get_change_id_in_line(line)
  if not change_id then
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local current_line_num = cursor_pos[1]

    local line_above_num = current_line_num - 1
    if line_above_num < 1 then
      vim.notify("EasyJJ: change_id not found", vim.log.levels.ERROR)
      return
    end

    local line_above = vim.api.nvim_buf_get_lines(0,
      line_above_num - 1, line_above_num, false)[1]
    change_id = M.get_change_id_in_line(line_above)
  end
  return change_id
end

return M
