local M = {
  highlights_initialized = false,
  highlights = {
    added = { fg = "#3fb950", ctermfg = "Green" },
    modified = { fg = "#56d4dd", ctermfg = "Cyan" },
    deleted = { fg = "#f85149", ctermfg = "Red" },
    renamed = { fg = "#d29922", ctermfg = "Yellow" },
  },
}

M.state = {
  buf = nil,
  revset = ''
}

local function init_highlights()
  if M.highlights_initialized then
    return
  end

  vim.api.nvim_set_hl(0, "JJComment", { link = "Comment" })
  vim.api.nvim_set_hl(0, "JJAdded", M.highlights.added)
  vim.api.nvim_set_hl(0, "JJModified", M.highlights.modified)
  vim.api.nvim_set_hl(0, "JJDeleted", M.highlights.deleted)
  vim.api.nvim_set_hl(0, "JJRenamed", M.highlights.renamed)

  M.highlights_initialized = true
end

function M.open_ephemeral_buffer(initial_text, on_done)
  -- Initialize highlight groups once
  init_highlights()

  -- Create a horizontal split at the bottom, half the screen height
  local height = math.floor(vim.o.lines / 2)
  vim.cmd(string.format("botright %dsplit", height))

  -- Create a new unlisted, scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "jj:///DESCRIBE_EDITMSG")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, initial_text)
  vim.api.nvim_win_set_buf(0, buf)

  -- Configure buffer options
  vim.bo[buf].buftype = "acwrite" -- Allow custom write handling
  vim.bo[buf].bufhidden = "wipe"  -- Automatically wipe buffer when hidden
  vim.bo[buf].swapfile = false    -- Disable swapfile
  vim.bo[buf].modifiable = true   -- Allow editing

  -- Create a namespace for our highlights
  local ns_id = vim.api.nvim_create_namespace("jj_describe_highlights")

  -- Function to apply highlights to the buffer
  local function apply_highlights()
    -- Clear existing highlights
    vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

    -- Get all lines
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    for i, line in ipairs(lines) do
      local line_idx = i - 1 -- 0-indexed

      -- First, check if line starts with JJ: and highlight it as comment
      if line:match("^JJ:") then
        -- Highlight the "JJ:" prefix as comment (first 3 characters)
        vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx, 0, {
          end_col = 3,
          hl_group = "JJComment",
        })

        -- Then check for status indicators and highlight the rest of the line
        local status_pos = line:find("[MADRC] ", 4)       -- Find status after "JJ:"
        if status_pos then
          local status = line:sub(status_pos, status_pos) -- Get the status character
          local hl_group = nil

          if status == "A" or status == "C" then
            hl_group = "JJAdded"
          elseif status == "M" then
            hl_group = "JJModified"
          elseif status == "D" then
            hl_group = "JJDeleted"
          elseif status == "R" then
            hl_group = "JJRenamed"
          end

          if hl_group then
            -- Highlight from the status character to the end of the line
            vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx, status_pos - 1, {
              end_col = #line,
              hl_group = hl_group,
            })
          else
            -- No status, keep rest as comment
            vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx, 3, {
              end_col = #line,
              hl_group = "JJComment",
            })
          end
        else
          -- No status indicator, highlight rest of line as comment
          vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx, 3, {
            end_col = #line,
            hl_group = "JJComment",
          })
        end
      end
    end
  end

  -- Apply highlights initially
  apply_highlights()

  -- Reapply highlights when text changes
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = buf,
    callback = apply_highlights,
  })

  -- Position cursor at the end (after the last JJ: line) and enter insert mode
  vim.schedule(function()
    local line_count = vim.api.nvim_buf_line_count(buf)
    local target_line_idx = line_count - 1 -- 0-indexed line number for API calls
    local last_line_content = vim.api.nvim_buf_get_lines(buf, target_line_idx, line_count, false)[1]
    local col_index = #last_line_content
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end)

  -- Handle :w and :wq commands
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      if on_done then
        on_done(buf_lines)
      end
      vim.bo[buf].modified = false
    end,
  })

  -- Add keymap to close the buffer with 'q' in normal mode
  vim.keymap.set(
    "n",
    "q",
    "<cmd>close!<CR>",
    { buffer = buf, noremap = true, silent = true, desc = "Close describe buffer" }
  )

  -- Add keymap to close the buffer with '<Esc>' in normal mode
  vim.keymap.set(
    "n",
    "<Esc>",
    "<cmd>close!<CR>",
    { buffer = buf, noremap = true, silent = true, desc = "Close describe buffer" }
  )
end

-- Run command and display its result in a buffer
function M.run_and_display(cmd, name, set_keymaps_callback)
  if M.state.buf then
    vim.api.nvim_buf_delete(M.state.buf, { force = true })
    M.state.buf = nil
  end
  M.state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(M.state.buf, name)

  if set_keymaps_callback then
    set_keymaps_callback(M.state)
  end

  local win = vim.api.nvim_open_win(M.state.buf, true, {
    split = 'below',
    win = 0,
  })

  -- Disable line numbers for jj buffers
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false

  local chan = vim.api.nvim_open_term(M.state.buf, {})
  local job_id = vim.fn.jobstart(cmd, {
    pty = true,
    on_stdout = function(_, data)
      local output = table.concat(data, '\n')
      vim.api.nvim_chan_send(chan, output)
    end,
    on_exit = function(_, _)
      vim.bo[M.state.buf].modifiable = false
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
    return output, false
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
      vim.notify("jj: change_id not found", vim.log.levels.ERROR)
      return
    end

    local line_above = vim.api.nvim_buf_get_lines(0,
      line_above_num - 1, line_above_num, false)[1]
    change_id = M.get_change_id_in_line(line_above)
  end
  return change_id
end

return M
