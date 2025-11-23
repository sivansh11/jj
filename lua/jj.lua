local M = {}

local utils = require('utils')

local config = {
}

-- jj edit
function M.jj_edit(state, ignore_immutable)
  local cmd = "jj status"
  local output, success = utils.run(cmd)
  if not success then
    vim.notify("jj: Unable to get status", vim.log.levels.ERROR)
    return
  end
  local pattern = "Working copy[^\n]*%(@%)[^\n]*:%s*([%w]+)"
  local id = output:match(pattern)
  local change_id = utils.get_change_id()
  if not change_id then
    vim.notify("jj: Change ID not found", vim.log.levels.ERROR)
    return
  end
  if change_id == id then
    M.jj_status()
    return
  end

  local cmd = "jj edit -r " .. change_id
  if ignore_immutable then
    cmd = cmd .. " --ignore-immutable"
  end

  local output, success = utils.run(cmd)
  if not success then
    vim.notify("jj: Edit " .. change_id .. " failed", vim.log.levels.ERROR)
    vim.notify(output, vim.log.levels.ERROR)
    return
  end

  vim.cmd('checktime')

  local win = vim.fn.bufwinid(state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  M.jj_log(state)

  win = vim.fn.bufwinid(state.buf)
  vim.api.nvim_win_set_cursor(win, cursor_pos)
end

-- jj undo
function M.jj_undo(state)
  local cmd = "jj undo"

  local output, success = utils.run(cmd)
  if not success then
    vim.notify("jj: undo not successful", vim.log.levels.ERROR)
    vim.notify(output, vim.log.levels.ERROR)
    return
  end

  vim.cmd('checktime')

  local win = vim.fn.bufwinid(state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  M.jj_log(state)

  win = vim.fn.bufwinid(state.buf)
  vim.api.nvim_win_set_cursor(win, cursor_pos)
end

-- jj redo
function M.jj_redo(state)
  local cmd = "jj redo"

  local output, success = utils.run(cmd)
  if not success then
    vim.notify("jj: redo not successful", vim.log.levels.ERROR)
    vim.notify(output, vim.log.levels.ERROR)
    return
  end

  vim.cmd('checktime')

  local win = vim.fn.bufwinid(state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  M.jj_log(state)

  win = vim.fn.bufwinid(state.buf)
  vim.api.nvim_win_set_cursor(win, cursor_pos)
end

-- jj new
function M.jj_new(state)
  local change_id = utils.get_change_id()
  if not change_id then
    vim.notify("jj: Change ID not found", vim.log.levels.ERROR)
    return
  end

  local cmd = "jj new -r " .. change_id

  local output, success = utils.run(cmd)
  if not success then
    vim.notify("jj: new not successful", vim.log.levels.ERROR)
    vim.notify(output, vim.log.levels.ERROR)
    return
  end

  vim.cmd('checktime')

  local win = vim.fn.bufwinid(state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  M.jj_log(state)

  win = vim.fn.bufwinid(state.buf)
  vim.api.nvim_win_set_cursor(win, cursor_pos)
end

-- jj describe
function M.jj_describe(state, ignore_immutable)
  local change_id = utils.get_change_id()
  if not change_id then
    vim.notify("jj: Change ID not found", vim.log.levels.ERROR)
    return
  end

  -- Get current description
  local cmd = "jj log -r "
      .. change_id
      .. " --no-graph -T 'coalesce(description, \"(no description set)\n\")'"
  local old_description_raw, success = utils.run(cmd)
  if not success then
    vim.notify("jj: failed to get current description", vim.log.levels.ERROR)
    return
  end
  local old_description = vim.trim(old_description_raw)

  -- Get status files
  local status_cmd = "jj log -r " .. change_id .. " --no-graph -T 'self.diff().summary()'"
  local status_output, status_success = utils.run(status_cmd)
  local status_files = {}
  if status_success and status_output then
    for line in status_output:gmatch("[^\r\n]+") do
      if line ~= "" then
        table.insert(status_files, { status = line:match("^%S+"), file = line:match("%s+(.+)$") })
      end
    end
  end

  -- Create buffer content
  local text = { old_description }
  table.insert(text, "") -- Empty line to separate from user input
  table.insert(text, "JJ: Change ID: " .. change_id)
  table.insert(text, "JJ: This commit contains the following changes:")
  for _, item in ipairs(status_files) do
    table.insert(text, string.format("JJ:     %s %s", item.status or "", item.file or ""))
  end
  table.insert(text, "JJ:") -- blank line
  table.insert(text, 'JJ: Lines starting with "JJ:" (like this one) will be removed')

  utils.open_ephemeral_buffer(text, function(buf_lines)
    local user_lines = {}
    for _, line in ipairs(buf_lines) do
      if not line:match("^JJ:") then
        table.insert(user_lines, line)
      end
    end
    -- Join lines and trim leading/trailing whitespace
    local trimmed_description = table.concat(user_lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")

    local describe_cmd = "jj describe -r " .. change_id .. " --stdin"
    if ignore_immutable then
      describe_cmd = "jj describe -r " .. change_id .. " --ignore-immutable --stdin"
    end
    if trimmed_description == "(no description set)" or trimmed_description == "" then
      vim.notify("jj: cancelling description", vim.log.levels.INFO)
      return
    end
    local _, success = utils.run(describe_cmd, trimmed_description)
    if not success then
      vim.notify("jj: Failed to describe " .. change_id, vim.log.levels.ERROR)
    else
      vim.notify("jj: described " .. change_id, vim.log.levels.INFO)
    end

    M.jj_log(state)
  end)
end

-- jj squash
function M.jj_squash(state, ignore_immutable)
  local change_id = utils.get_change_id()
  if not change_id then
    vim.notify("jj: Change ID not found", vim.log.levels.ERROR)
    return
  end

  local cmd = "jj squash -t " .. change_id .. " --use-destination-message"
  if ignore_immutable then
    cmd = cmd .. " --ignore-immutable"
  end

  local output, success = utils.run(cmd)
  if not success then
    vim.notify("jj: squash not successful", vim.log.levels.ERROR)
    vim.notify(output, vim.log.levels.ERROR)
    return
  end

  vim.cmd('checktime')

  local win = vim.fn.bufwinid(state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  M.jj_log(state)

  win = vim.fn.bufwinid(state.buf)
  vim.api.nvim_win_set_cursor(win, cursor_pos)
end

function M.jj_status_file()
  local line = vim.api.nvim_get_current_line()
  local file_info = utils.get_file_path_from_line(line)

  if not file_info then
    -- silent failure, dont notify
    return
  end

  local filepath = file_info.new_path
  local stat = vim.uv.fs_stat(filepath)
  if not stat then
    utils.notify("jj: File " .. filepath .. " not found", vim.log.levels.ERROR)
    return
  end
  vim.cmd("wincmd p")
  vim.cmd("edit " .. vim.fn.fnameescape(filepath))
end

function M.jj_status_keymaps(state)
  -- Close jj-status
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_buf_delete(state.buf, { force = true })
    state.buf = nil
    M.jj_log(state)
  end, {
    buffer = state.buf,
    desc = "Close jj buffer"
  })
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_buf_delete(state.buf, { force = true })
    state.buf = nil
    M.jj_log(state)
  end, {
    buffer = state.buf,
    desc = "Close jj buffer"
  })

  -- file
  vim.keymap.set('n', '<CR>', function()
    M.jj_status_file()
  end, {
    buffer = state.buf,
    desc = "Select File"
  })

  local disabled_keys = { "i", "c", "a" }
  for _, key in ipairs(disabled_keys) do
    vim.keymap.set({ "n", "v" }, key, function() end, {
      buffer = state.buf,
      desc = "Disabled"
    })
  end
end

function M.jj_status()
  utils.run_and_display("jj status --no-pager", "jj-status", M.jj_status_keymaps)
end

function M.jj_set_revset(state)
  vim.ui.input({ prompt = "Enter Revset: ", default = state.revset }, function(revset)
    state.revset = revset
  end)

  M.jj_log(state)
end

function M.jj_bookmark(state)
  local output, success = utils.run("jj bookmark list --all-remotes --no-pager")

  if not success then
    vim.notify("jj: could not get bookmarks", vim.log.levels.ERROR)
    return
  end

  local names = {}
  for line in string.gmatch(output, "([^\n]+)") do
    local name = string.match(line, "^(.-):")
    if name then
      -- Trim any leading/trailing whitespace
      table.insert(names, vim.trim(name))
    end
  end
  table.insert(names, "create")

  for i = #names, 1, -1 do
    local name = names[i]
    if string.sub(name, 1, 1) == '@' then
      table.remove(names, i)
    end
  end

  local change_id = utils.get_change_id()
  if not change_id then
    vim.notify("jj: Change ID not found", vim.log.levels.ERROR)
    return
  end

  local function on_choice(choice, idx)
    if idx == 0 then
      -- silent exit
      -- maybe notify cancled ?
      return
    end
    if choice == "create" then
      vim.defer_fn(function()
        vim.ui.input({ prompt = "Enter Name: " }, function(name)
          if name then
            local cmd = "jj bookmark create -r " .. change_id .. " " .. name
            local _, success = utils.run(cmd)
            if not success then
              vim.notify("jj: Failed to create bookmark " .. name, vim.log.levels.ERROR)
              return
            end
          else
            -- silent exit
            -- maybe notify cancled ?
            return
          end
        end)
        local win = vim.fn.bufwinid(state.buf)
        local cursor_pos
        if win ~= -1 then
          cursor_pos = vim.api.nvim_win_get_cursor(win)
        end

        M.jj_log(state)

        win = vim.fn.bufwinid(state.buf)
        vim.api.nvim_win_set_cursor(win, cursor_pos)
      end, 50)
    else
      local cmd = "jj bookmark set " ..
          choice ..
          " -r " ..
          change_id ..
          " --allow-backwards"
      local _, success = utils.run(cmd)
      if not success then
        vim.notify("jj: Failed to move bookmark " .. name, vim.log.levels.ERROR)
        return
      end
      local win = vim.fn.bufwinid(state.buf)
      local cursor_pos
      if win ~= -1 then
        cursor_pos = vim.api.nvim_win_get_cursor(win)
      end

      M.jj_log(state)

      win = vim.fn.bufwinid(state.buf)
      vim.api.nvim_win_set_cursor(win, cursor_pos)
    end
  end

  vim.ui.select(names, { prompt = "Select Bookmark: " }, on_choice)
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
  vim.keymap.set('n', '<CR>', function()
    M.jj_edit(state, false)
  end, {
    buffer = state.buf,
    desc = "Edit"
  })
  vim.keymap.set('n', '<S-CR>', function()
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

  -- Describe
  vim.keymap.set('n', 'd', function()
    M.jj_describe(state, false)
  end, {
    buffer = state.buf,
    desc = "Describe"
  })
  vim.keymap.set('n', 'D', function()
    M.jj_describe(state, true)
  end, {
    buffer = state.buf,
    desc = "Describe(immutable)"
  })

  -- Squash
  vim.keymap.set('n', 's', function()
    M.jj_squash(state, false)
  end, {
    buffer = state.buf,
    desc = "Squash"
  })
  vim.keymap.set('n', '<S-s>', function()
    M.jj_squash(state, true)
  end, {
    buffer = state.buf,
    desc = "Squash(immutable)"
  })

  -- Set revset
  vim.keymap.set('n', 'r', function()
    M.jj_set_revset(state)
  end, {
    buffer = state.buf,
    desc = "Set Revset"
  })

  -- Bookmarks
  vim.keymap.set('n', 'b', function()
    M.jj_bookmark(state)
  end, {
    buffer = state.buf,
    desc = "Bookmarks"
  })

  local disabled_keys = { "i", "c", "a" }
  for _, key in ipairs(disabled_keys) do
    vim.keymap.set({ "n", "v" }, key, function() end, {
      buffer = state.buf,
      desc = "Disabled"
    })
  end
end

function M.jj_log(state)
  local cmd
  if state.revset == "" then
    cmd = "jj log --no-pager"
  else
    cmd = "jj log --no-pager -r '" .. state.revset .. "'"
  end
  utils.run_and_display(cmd, "jj-log", M.jj_log_keymaps)
end

function M.setup(user_config)
  config = vim.tbl_deep_extend('force', config, user_config or {})

  if not vim.fn.executable('jj') == 1 then
    vim.notify("jj: jj executable not found! jj not enabled", vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_create_user_command('J', function()
    M.jj_log(utils.state)
  end, {
    desc = 'Show jj log in configured style (split or float)'
  })
end

return M
