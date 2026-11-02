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
	revset = "",
	rebase_from = nil,
	rebase_immutable = false,
	job_id = nil,
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

function M.setup(user_config)
	local cfg = user_config or {}
	if cfg.highlights then
		M.highlights = vim.tbl_deep_extend("force", M.highlights, cfg.highlights)
	end
end

-- Clamp {line, col} to buffer bounds; uses the current cursor when pos is nil
function M.clamp_cursor(win, pos)
	if win == -1 or not vim.api.nvim_win_is_valid(win) then
		return nil
	end
	local buf = vim.api.nvim_win_get_buf(win)
	local cur = pos or vim.api.nvim_win_get_cursor(win)
	local line = math.max(1, math.min(cur[1], vim.api.nvim_buf_line_count(buf)))
	local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or ""
	local col = math.max(0, math.min(cur[2], #text))
	return { line, col }
end

function M.set_cursor_safe(win, pos)
	if win == -1 or not vim.api.nvim_win_is_valid(win) then
		return
	end
	vim.api.nvim_win_set_cursor(win, M.clamp_cursor(win, pos))
end

-- Graph rows hold the change id at the graph column and end with the commit id
local CHANGE_ROW_TAIL = "%s.+%x%x%x%x%x%x%x%x%s*$"

local function change_id_pattern(change_id)
	return "^[%s│╭╰├─╮╯○◆●×@~+%-]*"
		.. (change_id and vim.pesc(change_id) or "([a-z][a-z0-9]*)")
		.. CHANGE_ROW_TAIL
end

-- Get the change ID in line without verifying it against jj
function M.peek_change_id(buf, line)
	local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1]
	if not text then
		return nil
	end
	return text:match(change_id_pattern())
end

-- Get the line currently holding change_id
function M.find_change_line(buf, change_id)
	if not change_id or not vim.api.nvim_buf_is_valid(buf) then
		return nil
	end

	local pattern = change_id_pattern(change_id)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	for i = 1, #lines do
		if lines[i]:match(pattern) then
			return i
		end
	end

	return nil
end

-- Put the cursor back on the same change, falling back to the saved line
function M.restore_cursor(win, saved)
	if win == -1 or not vim.api.nvim_win_is_valid(win) or not saved then
		return
	end

	local buf = vim.api.nvim_win_get_buf(win)
	local line = M.find_change_line(buf, saved.change_id)
	if line then
		vim.api.nvim_win_set_cursor(win, { line, 0 })
	else
		M.set_cursor_safe(win, { saved.line, saved.col })
	end

	-- Terminal buffers scroll to the tail as output arrives
	vim.api.nvim_win_call(win, function()
		vim.cmd("normal! zt")
	end)
end

-- Close every window showing buf
function M.close_buffer(buf)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
end

-- Run callback once buf stops changing, on_exit fires before the output lands
function M.when_settled(buf, callback, timeout)
	if not callback then
		return
	end

	local deadline = vim.uv.now() + (timeout or 3000)
	local last_tick = -1
	local timer = vim.uv.new_timer()

	local function finish()
		timer:stop()
		if not timer:is_closing() then
			timer:close()
		end
		if vim.api.nvim_buf_is_valid(buf) then
			callback()
		end
	end

	timer:start(
		25,
		25,
		vim.schedule_wrap(function()
			if not vim.api.nvim_buf_is_valid(buf) then
				finish()
				return
			end

			local tick = vim.api.nvim_buf_get_changedtick(buf)
			if tick == last_tick or vim.uv.now() > deadline then
				finish()
				return
			end
			last_tick = tick
		end)
	)
end

-- Reload buffers from disk without erroring on out-of-bounds cursors
function M.checktime()
	local ok = pcall(vim.cmd, "checktime")
	if not ok then
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			M.set_cursor_safe(win)
		end
		local ok2, err = pcall(vim.cmd, "checktime")
		if not ok2 then
			vim.notify("jj: checktime failed: " .. tostring(err), vim.log.levels.WARN)
		end
	end
end

function M.open_ephemeral_buffer(initial_text, on_done)
	-- Initialize highlight groups once
	init_highlights()

	-- Create a horizontal split at the bottom, half the screen height
	local height = math.floor(vim.o.lines / 2)
	vim.cmd(string.format("botright %dsplit", height))

	-- Reclaim any leftover describe buffer so the fixed name isn't taken
	local existing = vim.fn.bufnr("jj:///DESCRIBE_EDITMSG")
	if existing ~= -1 then
		M.close_buffer(existing)
		if vim.api.nvim_buf_is_valid(existing) then
			vim.api.nvim_buf_delete(existing, { force = true })
		end
	end

	-- Create a new unlisted, scratch buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "jj:///DESCRIBE_EDITMSG")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, initial_text)
	vim.api.nvim_win_set_buf(0, buf)

	-- Configure buffer options
	vim.bo[buf].buftype = "acwrite" -- Allow custom write handling
	vim.bo[buf].bufhidden = "wipe" -- Automatically wipe buffer when hidden
	vim.bo[buf].swapfile = false -- Disable swapfile
	vim.bo[buf].modifiable = true -- Allow editing

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
				local status_pos = line:find("[MADRC] ", 4) -- Find status after "JJ:"
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

	-- Position cursor on the first line (editable description area)
	vim.schedule(function()
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
	end)

	-- Handle :w and :wq commands
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf,
		callback = function()
			local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			if on_done then
				on_done(buf, buf_lines)
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

-- Run command and display its result in a buffer, on_ready runs once it settles
function M.run_and_display(cmd, name, set_keymaps_callback, on_ready)
	if M.state.buf then
		vim.api.nvim_buf_delete(M.state.buf, { force = true })
		M.state.buf = nil
	end
	M.state.buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(M.state.buf, name)

	if set_keymaps_callback then
		set_keymaps_callback(M.state)
	end

	local buf = M.state.buf
	local win = vim.api.nvim_open_win(buf, true, {
		split = "below",
		win = 0,
	})

	-- Disable line numbers for jj buffers
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"

	local chan = vim.api.nvim_open_term(buf, {})
	local job_id = vim.fn.jobstart(cmd, {
		pty = true,
		on_stdout = function(_, data)
			local output = table.concat(data, "\n")
			vim.api.nvim_chan_send(chan, output)
		end,
		on_exit = function()
			if vim.api.nvim_buf_is_valid(buf) then
				vim.bo[buf].modifiable = false
			end
			M.when_settled(buf, on_ready)
		end,
	})

	if job_id <= 0 then
		vim.notify("jj: Failed to start job with cmd: " .. cmd, vim.log.levels.ERROR)
		return
	end

	M.state.job_id = job_id
end

-- Run command interactive
function M.run_interactive(cmd, name, on_exit)
	if M.state.buf then
		vim.api.nvim_buf_delete(M.state.buf, { force = true })
		M.state.buf = nil
	end
	M.state.buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(M.state.buf, name)

	local win = vim.api.nvim_open_win(M.state.buf, true, {
		split = "below",
		win = 0,
	})

	-- Disable line numbers for jj buffers
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"

	-- local chan = vim.api.nvim_open_term(M.state.buf, {})
	local job_id = vim.fn.jobstart(cmd, {
		term = true,
		-- pty = true,
		-- on_stdout = function(_, data)
		--   local output = table.concat(data, '\n')
		--   vim.api.nvim_chan_send(chan, output)
		-- end,
		on_exit = function(_, _, _)
			vim.schedule(function()
				vim.cmd("stopinsert")
				vim.api.nvim_win_close(win, true)
				if M.state.buf and vim.api.nvim_buf_is_loaded(M.state.buf) then
					vim.api.nvim_buf_delete(M.state.buf, { force = true })
					M.state.buf = nil
				end
				if on_exit then
					on_exit()
				end
				M.checktime()
			end)
		end,
	})

	vim.cmd("startinsert")

	if job_id <= 0 then
		vim.notify("jj: Failed to start job with cmd: " .. cmd, vim.log.levels.ERROR)
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
	local change_id = line:match("^[%s│├─╯○◆×@]+([a-z]+)")

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
function M.get_change_id(line_number)
	local line = vim.api.nvim_buf_get_lines(M.state.buf, line_number - 1, line_number, false)[1]
	local change_id = M.get_change_id_in_line(line)
	if not change_id then
		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		local current_line_num = cursor_pos[1]

		local line_above_num = current_line_num - 1
		if line_above_num < 1 then
			vim.notify("jj: change_id not found", vim.log.levels.ERROR)
			return
		end

		local line_above = vim.api.nvim_buf_get_lines(0, line_above_num - 1, line_above_num, false)[1]
		change_id = M.get_change_id_in_line(line_above)
	end
	return change_id
end

function M.get_git_commit_id_in_line(line)
	local git_id = string.match(line, "([^%s]+)$")
	if git_id then
		local cmd = "git cat-file -t " .. git_id .. " > /dev/null 2>&1"
		local _, success = M.run(cmd)
		if not success then
			return nil
		end
	end
	return git_id
end

function M.get_git_commit_id(line_number)
	local line = vim.api.nvim_buf_get_lines(M.state.buf, line_number - 1, line_number, false)[1]
	local git_id = M.get_git_commit_id_in_line(line)
	if not git_id then
		local line_above_num = line_number - 1
		if line_above_num < 1 then
			vim.notify("jj: git_id not found", vim.log.levels.ERROR)
			return
		end

		local line_above = vim.api.nvim_buf_get_lines(0, line_above_num - 1, line_above_num, false)[1]
		git_id = M.get_git_commit_id_in_line(line_above)
	end
	return git_id
end

function M.get_file_path_from_line(line)
	-- Handle renamed files: "R path/{old_name => new_name}" or "R old_path => new_path"
	local rename_pattern_curly = "^R (.*)/{(.*) => ([^}]+)}"
	local dir_path, old_name, new_name = line:match(rename_pattern_curly)

	if dir_path and old_name and new_name then
		return {
			old_path = dir_path .. "/" .. old_name,
			new_path = dir_path .. "/" .. new_name,
			is_rename = true,
		}
	else
		-- Try simple rename pattern: "R old_path => new_path"
		local rename_pattern_simple = "^R (.*) => (.+)$"
		local old_path, new_path = line:match(rename_pattern_simple)
		if old_path and new_path then
			return {
				old_path = old_path,
				new_path = new_path,
				is_rename = true,
			}
		end
	end

	-- Not a rename, try regular status patterns
	local filepath
	-- Handle renamed files: "R path/{old_name => new_name}" or "R old_path => new_path"
	local rename_pattern_curly_new = "^R (.*)/{.* => ([^}]+)}"
	local dir_path_new, renamed_file = line:match(rename_pattern_curly_new)

	if dir_path_new and renamed_file then
		filepath = dir_path_new .. "/" .. renamed_file
	else
		-- Try simple rename pattern: "R old_path => new_path"
		local rename_pattern_simple_new = "^R .* => (.+)$"
		filepath = line:match(rename_pattern_simple_new)
	end

	if not filepath then
		-- jj status format: "M filename" or "A filename"
		-- Match lines that start with status letter followed by space and filename
		local pattern = "^[MAD?!] (.+)$"
		filepath = line:match(pattern)
	end

	if filepath then
		return {
			old_path = filepath,
			new_path = filepath,
			is_rename = false,
		}
	end

	return nil
end

function M.highlight_line(line_number)
	init_highlights()
	if line_number < 1 then
		vim.notify("jj: invalid line number " .. line_number, vim.log.levels.ERROR)
		return
	end
	local line_count = vim.api.nvim_buf_line_count(M.state.buf)
	if line_number > line_count then
		vim.notify("jj: invalid line number " .. line_number, vim.log.levels.ERROR)
		return
	end
	local ns_id = vim.api.nvim_create_namespace("jj_rebasing_highlights")
	local line = vim.api.nvim_buf_get_lines(M.state.buf, line_number - 1, line_number, false)[1]
	vim.api.nvim_buf_set_extmark(M.state.buf, ns_id, line_number - 1, 0, {
		end_col = #line,
		hl_group = "JJComment",
	})
end

function M.highlight_current_change()
	-- local running = vim.fn.jobwait({ M.state.job_id }, 0)[0] == 1
	-- while running do
	--   running = vim.fn.jobwait({ M.state.job_id }, 0)[0] == 1
	-- end
	-- running = vim.fn.jobwait({ M.state.job_id }, 0)[0] == 1
	-- vim.notify("running: " .. tostring(running))

	-- workaround for jobwait not waiting
	vim.defer_fn(function()
		local line = vim.api.nvim_get_current_line()
		local line_number = vim.fn.line(".")
		line = vim.api.nvim_buf_get_lines(M.state.buf, line_number - 1, line_number, false)[1]
		local change_id = M.get_change_id_in_line(line)

		if not change_id then
			-- highlight current and above
			M.highlight_line(line_number - 1)
			M.highlight_line(line_number)
		else
			-- highlight current and below
			M.highlight_line(line_number)
			M.highlight_line(line_number + 1)
		end
	end, 100)
end

-- Check whether ancestor is an ancestor of (or the same change as) descendant
function M.is_ancestor(ancestor, descendant)
	local cmd = "jj log --ignore-working-copy --no-graph -r '"
		.. ancestor
		.. "::"
		.. descendant
		.. "' -T 'change_id.short() ++ \"\\n\"'"
	local output, success = M.run(cmd)
	return success and vim.trim(output) ~= ""
end

function M.is_change_mutable(change_id)
	local cmd = 'jj show --ignore-working-copy -T \'if(immutable, "immutable", "mutable")\' --no-patch -r ' .. change_id
	local output, success = M.run(cmd)
	if not success then
		vim.notify("jj: unable to get if change is mutable", vim.log.levels.ERROR)
		vim.notify(output, vim.log.levels.ERROR)
		return nil
	end
	if output == "mutable" then
		return true
	end
	return false
end

return M
