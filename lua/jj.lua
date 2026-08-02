local M = {}

local utils = require('utils')

local config = {
  keymaps = {
    log = {
      close = 'q',
      close_esc = '<Esc>',
      edit = '<CR>',
      edit_immutable = '<S-CR>',
      undo = 'u',
      redo = '<C-r>',
      new = 'n',
      describe = 'd',
      describe_immutable = 'D',
      squash = 's',
      squash_immutable = '<S-s>',
      set_revset = 'r',
      bookmark = 'b',
      abandon = 'a',
      abandon_immutable = '<S-a>',
      diff = 'd',
      new_merge = 'n',
      rebase = 'm',
      rebase_immutable = '<S-m>',
      push = 'p',
      fetch = 'f',
      split = '<C-s>',
      split_immutable = '<C-S-s>',
      disabled = { 'i', 'c' },
    },
    status = {
      close = 'q',
      close_esc = '<Esc>',
      open_file = '<CR>',
      disabled = { 'i', 'c', 'a' },
    },
    rebase = {
      close = 'q',
      close_esc = '<Esc>',
      rebase_to = '<CR>',
      rebase_to_immutable = '<S-CR>',
      disabled = { 'i', 'c', 'a' },
    },
  },
}

local function set_keymap(modes, key, callback, desc)
  if not key or key == '' then
    return
  end
  vim.keymap.set(modes, key, callback, {
    buffer = utils.state.buf,
    desc = desc,
  })
end

-- jj edit
function M.jj_edit(ignore_immutable)
  local cmd = "jj status"
  local output, success = utils.run(cmd)
  if not success then
    vim.notify("jj: Unable to get status", vim.log.levels.ERROR)
    return
  end
  local pattern = "Working copy[^\n]*%(@%)[^\n]*:%s*([%w]+)"
  local id = output:match(pattern)
  local line_number = vim.fn.line('.')
  local change_id = utils.get_change_id(line_number)
  if not change_id then
    vim.notify("jj: Change ID not found", vim.log.levels.ERROR)
    return
  end
  if change_id == id then
    M.jj_status()
    return
  end

  cmd = "jj edit -r " .. change_id
  if ignore_immutable then
    cmd = cmd .. " --ignore-immutable"
  end

  output, success = utils.run(cmd)
  if not success then
    vim.notify("jj: Edit " .. change_id .. " failed", vim.log.levels.ERROR)
    vim.notify(output, vim.log.levels.ERROR)
    return
  end

  utils.checktime()

  local win = vim.fn.bufwinid(utils.state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  M.jj_log()

  win = vim.fn.bufwinid(utils.state.buf)
  utils.set_cursor_safe(win, cursor_pos)
end

-- jj undo
function M.jj_undo()
  local cmd = "jj undo"

  local output, success = utils.run(cmd)
  if not success then
    vim.notify("jj: undo not successful", vim.log.levels.ERROR)
    vim.notify(output, vim.log.levels.ERROR)
    return
  end

  utils.checktime()

  local win = vim.fn.bufwinid(utils.state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  M.jj_log()

  win = vim.fn.bufwinid(utils.state.buf)
  utils.set_cursor_safe(win, cursor_pos)
end

-- jj redo
function M.jj_redo()
  local cmd = "jj redo"

  local output, success = utils.run(cmd)
  if not success then
    vim.notify("jj: redo not successful", vim.log.levels.ERROR)
    vim.notify(output, vim.log.levels.ERROR)
    return
  end

  utils.checktime()

  local win = vim.fn.bufwinid(utils.state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  M.jj_log()

  win = vim.fn.bufwinid(utils.state.buf)
  utils.set_cursor_safe(win, cursor_pos)
end

-- jj new
function M.jj_new(merge)
  local cmd
  if not merge then
    local line_number = vim.fn.line('.')
    local change_id = utils.get_change_id(line_number)
    if not change_id then
      vim.notify("jj: Change ID not found", vim.log.levels.ERROR)
      return
    end
    cmd = "jj new " .. change_id
  else
    local a_num = vim.fn.line("'<")
    local b_num = vim.fn.line("'>")
    local a_change_id = utils.get_change_id(a_num)
    local b_change_id = utils.get_change_id(b_num)

    cmd = "jj new " .. a_change_id .. " " .. b_change_id
  end


  local output, success = utils.run(cmd)
  if not success then
    vim.notify("jj: new not successful", vim.log.levels.ERROR)
    vim.notify(output, vim.log.levels.ERROR)
    return
  end

  utils.checktime()

  local win = vim.fn.bufwinid(utils.state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  M.jj_log()

  win = vim.fn.bufwinid(utils.state.buf)
  utils.set_cursor_safe(win, cursor_pos)
end

-- jj describe
function M.jj_describe(ignore_immutable)
  local line_number = vim.fn.line('.')
  local change_id = utils.get_change_id(line_number)
  if not change_id then
    vim.notify("jj: Change ID not found", vim.log.levels.ERROR)
    return
  end

  if not ignore_immutable then
    local is_mutable = utils.is_change_mutable(change_id)
    if not is_mutable then
      vim.notify("jj: change is not mutable, try again with Shift", vim.log.levels.ERROR)
      return
    end
  end

  -- Get current description
  local cmd = "jj log --ignore-working-copy -r "
      .. change_id
      .. " --no-graph -T 'coalesce(description, \"(no description set)\n\")'"
  local old_description_raw, success = utils.run(cmd)
  if not success then
    vim.notify("jj: failed to get current description", vim.log.levels.ERROR)
    return
  end
  local old_description = vim.trim(old_description_raw)

  -- Get status files
  local status_cmd = "jj log --ignore-working-copy -r " .. change_id .. " --no-graph -T 'self.diff().summary()'"
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
  local text = {}
  for line in vim.gsplit(old_description, "\n") do
    table.insert(text, line)
  end
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
    _, success = utils.run(describe_cmd, trimmed_description)
    if not success then
      vim.notify("jj: Failed to describe " .. change_id, vim.log.levels.ERROR)
    else
      vim.notify("jj: described " .. change_id, vim.log.levels.INFO)
    end

    local win = vim.fn.bufwinid(utils.state.buf)
    local cursor_pos
    if win ~= -1 then
      cursor_pos = vim.api.nvim_win_get_cursor(win)
    end

    M.jj_log()

    win = vim.fn.bufwinid(utils.state.buf)
    utils.set_cursor_safe(win, cursor_pos)
  end)
end

-- jj squash
function M.jj_squash(ignore_immutable)
  local line_number = vim.fn.line('.')
  local change_id = utils.get_change_id(line_number)
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

  utils.checktime()

  local win = vim.fn.bufwinid(utils.state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  M.jj_log()

  win = vim.fn.bufwinid(utils.state.buf)
  utils.set_cursor_safe(win, cursor_pos)
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

function M.jj_status_keymaps()
  local keys = config.keymaps.status
  local close = function()
    vim.api.nvim_buf_delete(utils.state.buf, { force = true })
    utils.state.buf = nil
    M.jj_log()
  end

  set_keymap('n', keys.close, close, "Close jj buffer")
  set_keymap('n', keys.close_esc, close, "Close jj buffer")
  set_keymap('n', keys.open_file, function()
    M.jj_status_file()
  end, "Select File")

  for _, key in ipairs(keys.disabled or {}) do
    set_keymap({ "n", "v" }, key, function() end, "Disabled")
  end
end

function M.jj_status()
  utils.run_and_display("jj status --no-pager", "jj-status", M.jj_status_keymaps)
end

function M.jj_set_revset()
  vim.ui.input({ prompt = "Enter Revset: ", default = utils.state.revset }, function(revset)
    if revset == nil then
      return
    end
    utils.state.revset = revset

    local win = vim.fn.bufwinid(utils.state.buf)
    local cursor_pos
    if win ~= -1 then
      cursor_pos = vim.api.nvim_win_get_cursor(win)
    end

    M.jj_log()

    win = vim.fn.bufwinid(utils.state.buf)
    utils.set_cursor_safe(win, cursor_pos)
  end)
end

function M.jj_bookmark()
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

  local line_number = vim.fn.line('.')
  local change_id = utils.get_change_id(line_number)
  if not change_id then
    vim.notify("jj: Change ID not found", vim.log.levels.ERROR)
    return
  end

  local function on_choice(choice, idx)
    if not idx then
      -- silent exit
      -- maybe notify canceled ?
      return
    end
    if choice == "create" then
      vim.defer_fn(function()
        vim.ui.input({ prompt = "Enter Name: " }, function(name)
          if not name then
            -- silent exit
            -- maybe notify canceled ?
            return
          end

          local cmd = "jj bookmark create -r " .. change_id .. " " .. name
          _, success = utils.run(cmd)
          if not success then
            vim.notify("jj: Failed to create bookmark " .. name, vim.log.levels.ERROR)
            return
          end

          local win = vim.fn.bufwinid(utils.state.buf)
          local cursor_pos
          if win ~= -1 then
            cursor_pos = vim.api.nvim_win_get_cursor(win)
          end

          M.jj_log()

        win = vim.fn.bufwinid(utils.state.buf)
        utils.set_cursor_safe(win, cursor_pos)
        end)
      end, 100)
    else
      local cmd = "jj bookmark set " ..
          choice ..
          " -r " ..
          change_id ..
          " --allow-backwards"
      _, success = utils.run(cmd)
      if not success then
        vim.notify("jj: Failed to move bookmark " .. choice, vim.log.levels.ERROR)
        return
      end
      local win = vim.fn.bufwinid(utils.state.buf)
      local cursor_pos
      if win ~= -1 then
        cursor_pos = vim.api.nvim_win_get_cursor(win)
      end

      M.jj_log()

      win = vim.fn.bufwinid(utils.state.buf)
      utils.set_cursor_safe(win, cursor_pos)
    end
  end

  vim.ui.select(names, { prompt = "Select Bookmark: " }, on_choice)
end

function M.jj_abandon(ignore_immutable)
  local line_number = vim.fn.line('.')
  local change_id = utils.get_change_id(line_number)
  if not change_id then
    vim.notify("jj: Change ID not found", vim.log.levels.ERROR)
    return
  end

  local cmd = "jj abandon " .. change_id

  if ignore_immutable then
    cmd = cmd .. " --ignore-immutable"
  end

  local output, success = utils.run(cmd)
  if not success then
    vim.notify("jj: abandon not successful", vim.log.levels.ERROR)
    vim.notify(output, vim.log.levels.ERROR)
    return
  end

  utils.checktime()

  local win = vim.fn.bufwinid(utils.state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  M.jj_log()

  win = vim.fn.bufwinid(utils.state.buf)
  utils.set_cursor_safe(win, cursor_pos)
end

function M.jj_diff()
  local ok, _ = pcall(require, 'codediff')
  if not ok then
    vim.notify('jj: codediff not found, codediff is required for previewing diffs',
      vim.log.levels.ERROR)
    return
  end

  local start_num = vim.fn.line("'<")
  local end_num = vim.fn.line("'>")

  if start_num < 1 or end_num < 1 then
    vim.notify("jj: lines not found", vim.log.levels.ERROR)
    return
  end

  local start_git_id = utils.get_git_commit_id(start_num)
  local end_git_id = utils.get_git_commit_id(end_num)

  if not start_git_id or not end_git_id then
    vim.notify("jj: unable to get git ids to diff", vim.log.levels.ERROR)
    return
  end

  if start_git_id == end_git_id then
    vim.notify("jj: please select 2 commits to diff", vim.log.levels.ERROR)
    return
  end

  local cmd = "CodeDiff " .. end_git_id .. " " .. start_git_id
  vim.cmd(cmd)
end

function M.jj_rebase_to(ignore_immutable)
  if not utils.state.rebase_from then
    vim.notify("jj: rebase from not set", vim.log.levels.ERROR)
    return
  end

  local line_number = vim.fn.line('.')
  local change_id = utils.get_change_id(line_number)
  if not change_id then
    vim.notify("jj: Change ID not found", vim.log.levels.ERROR)
    return
  end

  local cmd = "jj rebase -s " .. utils.state.rebase_from .. " -d " .. change_id

  if ignore_immutable then
    cmd = cmd .. ' --ignore-immutable'
  end

  local output, success = utils.run(cmd)
  if not success then
    vim.notify('jj: failed to rebase '
      .. utils.state.rebase_from
      .. ' onto '
      .. change_id,
      vim.log.levels.ERROR)
    vim.notify(output, vim.log.levels.ERROR)
    return
  end

  utils.checktime()

  local win = vim.fn.bufwinid(utils.state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  M.jj_log()

  win = vim.fn.bufwinid(utils.state.buf)
  utils.set_cursor_safe(win, cursor_pos)
end

function M.jj_rebase_keymaps()
  local keys = config.keymaps.rebase
  local close = function()
    vim.notify("jj: canceled rebase", vim.log.levels.INFO)
    local win = vim.fn.bufwinid(utils.state.buf)
    local cursor_pos
    if win ~= -1 then
      cursor_pos = vim.api.nvim_win_get_cursor(win)
    end

    M.jj_log()

    win = vim.fn.bufwinid(utils.state.buf)
    utils.set_cursor_safe(win, cursor_pos)
  end

  set_keymap('n', keys.close, close, "Close jj buffer")
  set_keymap('n', keys.close_esc, close, "Close jj buffer")
  set_keymap('n', keys.rebase_to, function()
    M.jj_rebase_to(utils.state.rebase_immutable)
  end, "Rebase To")
  set_keymap('n', keys.rebase_to_immutable, function()
    M.jj_rebase_to(utils.state.rebase_immutable)
  end, "Rebase To(immutable)")

  for _, key in ipairs(keys.disabled or {}) do
    set_keymap({ "n", "v" }, key, function() end, "Disabled")
  end
end

function M.jj_rebase(ignore_immutable)
  local cmd
  if utils.state.revset == "" then
    cmd = "jj log --no-pager"
  else
    cmd = "jj log --no-pager -r '" .. utils.state.revset .. "'"
  end

  local line_number = vim.fn.line('.')
  local change_id = utils.get_change_id(line_number)
  if not change_id then
    vim.notify("jj: Change ID not found", vim.log.levels.ERROR)
    return
  end

  if not ignore_immutable then
    local is_mutable = utils.is_change_mutable(change_id)
    if not is_mutable then
      vim.notify("jj: change is not mutable, try again with Shift",
        vim.log.levels.ERROR)
      return
    end
  end

  utils.state.rebase_immutable = ignore_immutable

  utils.state.rebase_from = change_id

  local win = vim.fn.bufwinid(utils.state.buf)
  local cursor_pos
  if win ~= -1 then
    cursor_pos = vim.api.nvim_win_get_cursor(win)
  end

  utils.run_and_display(cmd, "jj-rebase", M.jj_rebase_keymaps)

  win = vim.fn.bufwinid(utils.state.buf)
  utils.set_cursor_safe(win, cursor_pos)

  vim.notify("jj: rebasing", vim.log.levels.INFO)

  utils.highlight_current_change()
end

function M.jj_split(ignore_immutable)
  local cmd = "jj split"
  if ignore_immutable then
    cmd = cmd .. " --ignore-immutable"
  end

  local cursor_pos
  if utils.state.buf then
    local win = vim.fn.bufwinid(utils.state.buf)
    if win ~= -1 then
      cursor_pos = vim.api.nvim_win_get_cursor(win)
    end
  end

  utils.run_interactive(cmd, "jj-split", function()
    if cursor_pos then
      M.jj_log()
      win = vim.fn.bufwinid(utils.state.buf)
      utils.set_cursor_safe(win, cursor_pos)
    end
  end)
end

function M.jj_resolve(ignore_immutable)
  local cmd = "jj resolve"
  if ignore_immutable then
    cmd = cmd .. " --ignore-immutable"
  end

  local cursor_pos
  if utils.state.buf then
    local win = vim.fn.bufwinid(utils.state.buf)
    if win ~= -1 then
      cursor_pos = vim.api.nvim_win_get_cursor(win)
    end
  end

  utils.run_interactive(cmd, "jj-resolve", function()
    if cursor_pos then
      M.jj_log()
      win = vim.fn.bufwinid(utils.state.buf)
      utils.set_cursor_safe(win, cursor_pos)
    end
  end)
end

function M.jj_push()
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
  table.insert(names, "all")

  for i = #names, 1, -1 do
    local name = names[i]
    if string.sub(name, 1, 1) == '@' then
      table.remove(names, i)
    end
  end

  local function on_choice(choice, idx)
    if not idx then
      -- silent exit
      -- maybe notify canceled ?
      return
    end
    if choice == "all" then
      local cmd = "jj git push --all"
      output, success = utils.run(cmd)
      if not success then
        vim.notify("jj: Failed to push bookmarks", vim.log.levels.ERROR)
        vim.notify(output, vim.log.levels.ERROR)
        return
      end
      local win = vim.fn.bufwinid(utils.state.buf)
      local cursor_pos
      if win ~= -1 then
        cursor_pos = vim.api.nvim_win_get_cursor(win)
      end

      M.jj_log()

      win = vim.fn.bufwinid(utils.state.buf)
      utils.set_cursor_safe(win, cursor_pos)
    else
      local cmd = "jj git push -b " .. choice
      output, success = utils.run(cmd)
      if not success then
        vim.notify("jj: Failed to push bookmark " .. choice, vim.log.levels.ERROR)
        vim.notify(output, vim.log.levels.ERROR)
        return
      end
      local win = vim.fn.bufwinid(utils.state.buf)
      local cursor_pos
      if win ~= -1 then
        cursor_pos = vim.api.nvim_win_get_cursor(win)
      end

      M.jj_log()

      win = vim.fn.bufwinid(utils.state.buf)
      utils.set_cursor_safe(win, cursor_pos)
    end
  end

  vim.ui.select(names, { prompt = "Select Bookmark: " }, on_choice)
end

function M.jj_fetch()
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
  table.insert(names, "all")

  for i = #names, 1, -1 do
    local name = names[i]
    if string.sub(name, 1, 1) == '@' then
      table.remove(names, i)
    end
  end

  local function on_choice(choice, idx)
    if not idx then
      -- silent exit
      -- maybe notify canceled ?
      return
    end
    if choice == "all" then
      local cmd = "jj git fetch --all-remotes"
      output, success = utils.run(cmd)
      if not success then
        vim.notify("jj: Failed to fetch bookmarks", vim.log.levels.ERROR)
        vim.notify(output, vim.log.levels.ERROR)
        return
      end
      local win = vim.fn.bufwinid(utils.state.buf)
      local cursor_pos
      if win ~= -1 then
        cursor_pos = vim.api.nvim_win_get_cursor(win)
      end

      M.jj_log()

      win = vim.fn.bufwinid(utils.state.buf)
      utils.set_cursor_safe(win, cursor_pos)
    else
      local cmd = "jj git fetch -b " .. choice
      output, success = utils.run(cmd)
      if not success then
        vim.notify("jj: Failed to fetch bookmark " .. choice, vim.log.levels.ERROR)
        vim.notify(output, vim.log.levels.ERROR)
        return
      end
      local win = vim.fn.bufwinid(utils.state.buf)
      local cursor_pos
      if win ~= -1 then
        cursor_pos = vim.api.nvim_win_get_cursor(win)
      end

      M.jj_log()

      win = vim.fn.bufwinid(utils.state.buf)
      utils.set_cursor_safe(win, cursor_pos)
    end
  end

  vim.ui.select(names, { prompt = "Select Bookmark: " }, on_choice)
end

function M.jj_log_keymaps()
  local keys = config.keymaps.log
  local close = function()
    vim.api.nvim_buf_delete(utils.state.buf, { force = true })
    utils.state.buf = nil
  end

  set_keymap('n', keys.close, close, "Close jj buffer")
  set_keymap('n', keys.close_esc, close, "Close jj buffer")
  set_keymap('n', keys.edit, function()
    M.jj_edit(false)
  end, "Edit")
  set_keymap('n', keys.edit_immutable, function()
    M.jj_edit(true)
  end, "Edit(immutable)")
  set_keymap('n', keys.undo, function()
    M.jj_undo()
  end, "Undo")
  set_keymap('n', keys.redo, function()
    M.jj_redo()
  end, "Redo")
  set_keymap('n', keys.new, function()
    M.jj_new(false)
  end, "New")
  set_keymap('n', keys.describe, function()
    M.jj_describe(false)
  end, "Describe")
  set_keymap('n', keys.describe_immutable, function()
    M.jj_describe(true)
  end, "Describe(immutable)")
  set_keymap('n', keys.squash, function()
    M.jj_squash(false)
  end, "Squash")
  set_keymap('n', keys.squash_immutable, function()
    M.jj_squash(true)
  end, "Squash(immutable)")
  set_keymap('n', keys.set_revset, function()
    M.jj_set_revset()
  end, "Set Revset")
  set_keymap('n', keys.bookmark, function()
    M.jj_bookmark()
  end, "Bookmarks")
  set_keymap('n', keys.abandon, function()
    M.jj_abandon(false)
  end, "Abandon")
  set_keymap('n', keys.abandon_immutable, function()
    M.jj_abandon(true)
  end, "Abandon(immutable)")
  set_keymap('v', keys.diff, "<Esc><Cmd>lua require('jj').jj_diff()<CR>", "Diff")
  set_keymap('v', keys.new_merge, "<Esc><Cmd>lua require('jj').jj_new(true)<CR>", "New(merge)")
  set_keymap('n', keys.rebase, function()
    M.jj_rebase(false)
  end, "Rebase")
  set_keymap('n', keys.rebase_immutable, function()
    M.jj_rebase(true)
  end, "Rebase(immutable)")
  set_keymap('n', keys.push, function()
    M.jj_push()
  end, "Push")
  set_keymap('n', keys.fetch, function()
    M.jj_fetch()
  end, "Fetch")
  set_keymap('n', keys.split, function()
    M.jj_split(false)
  end, "Split")
  set_keymap('n', keys.split_immutable, function()
    M.jj_split(true)
  end, "Split(immutable)")

  for _, key in ipairs(keys.disabled or {}) do
    set_keymap({ "n", "v" }, key, function() end, "Disabled")
  end
end

function M.jj_log()
  local cmd
  if utils.state.revset == "" then
    cmd = "jj log --no-pager"
  else
    cmd = "jj log --no-pager -r '" .. utils.state.revset .. "'"
  end
  utils.run_and_display(cmd, "jj-log", M.jj_log_keymaps)
end

function M.setup(user_config)
  config = vim.tbl_deep_extend('force', config, user_config or {})
  utils.setup(config)

  if vim.fn.executable('jj') ~= 1 then
    vim.notify("jj: jj executable not found! jj not enabled", vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_create_user_command('J', function()
    M.jj_log()
  end, {
    desc = 'Log'
  })
  vim.api.nvim_create_user_command('Jsplit', function(opts)
    local args = opts.args
    local args_table = vim.split(args, "%s+", { trimempty = true })

    for _, arg in ipairs(args_table) do
      if arg == "--ignore-immutable" then
        M.jj_split(true)
        return
      end
    end
    M.jj_split(false)
  end, {
    desc = 'Split',
    nargs = '*',
  })
  vim.api.nvim_create_user_command('Jresolve', function(opts)
    local args = opts.args
    local args_table = vim.split(args, "%s+", { trimempty = true })

    for _, arg in ipairs(args_table) do
      if arg == "--ignore-immutable" then
        M.jj_resolve(true)
        return
      end
    end
    M.jj_resolve(false)
  end, {
    desc = 'Resolve',
    nargs = '*',
  })
end

return M
