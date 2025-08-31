local alb = {}

vim.keymap.set("n", "gw", vim.diagnostic.open_float, { desc = "Show diagnostics under cursor" })

table.listContains = function(list, findMe)
	for _, v in ipairs(list) do
		if v == findMe then
			return true
		end
	end
	return false
end

string.gfind = function(str, pattern)
	local from_idx = nil
	local to_idx = 0
	return function()
		from_idx, to_idx = string.find(str, pattern, to_idx + 1)
		return from_idx, to_idx
	end
end

string.split = function(str, pattern)
	local p = 1
	local result = {}

	for f, t in string.gfind(str, pattern) do
		table.insert(result, string.sub(str, p, f - 1))
		p = t + 1
	end
	table.insert(result, string.sub(str, p, -1))
	return result
end

_G.ABLogs = _G.ABLogs or {}
function _G.addToABLogs(key, val)
	_G.ABLogs[key] = val
end
function _G.getABLogs()
	return _G.ABLogs
end
alb.getABLogs = _G.getABLogs
function _G.resetABLogs()
	_G.ABLogs = {}
end

_G.OngoingPid = _G.OngoingPid or {}
function _G.addNewOnGoing(pid, commandName, timeStarted)
	_G.OngoingPid[pid] = { std = {}, commandName = commandName, timeStarted = timeStarted, bufs = {} }
end
function _G.addToOngoingStd(pid, line)
	table.insert(_G.OngoingPid[pid].std, line)

	for i, buf in ipairs(_G.OngoingPid[pid].bufs) do
		if buf ~= nil then
			local success, output = pcall(function()
				local result = true
				vim.schedule(function()
					vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
					local isModifiable = vim.api.nvim_get_option_value("modifiable", { buf = buf })
					if not isModifiable then
						result = false
					else
						vim.api.nvim_buf_set_lines(buf, 0, -1, false, _G.OngoingPid[pid].std)
						vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
					end
				end)
				return result
			end)
			if not success or not output then
				--print("ded lol")
				_G.OngoingPid[pid].bufs[i] = nil
			end
		end
	end
end

function _G.addStdWindowListener(pid, buf_number)
	table.insert(_G.OngoingPid[pid].bufs, buf_number)
end
function _G.removeStdWIndowListener(pid, buf_number)
	_G.OngoingPid[pid].bufs[buf_number] = nil
end
function _G.removeOngoig(pid)
	_G.OngoingPid[pid] = nil
end
function _G.getOngoing()
	return _G.OngoingPid
end

alb.getOngoing = _G.getOngoing

local function openPopup(buff, time, name, result_val)
	local buf = vim.api.nvim_create_buf(false, true)
	local time_str = os.date("%Y-%m-%d %H:%M:%S", time) .. " (" .. tostring(os.time() - time) .. " seconds ago)"
	local buffCopy = {}
	for i, v in ipairs(buff) do
		buffCopy[i] = v
	end

	table.insert(buffCopy, 1, "NVIM: TIME STARTED: " .. time_str)
	table.insert(buffCopy, 2, "NVIM: JOB NAME: " .. name)
	table.insert(buffCopy, 3, "NVIM: EXIT CODE: " .. tostring(result_val))
	table.insert(buffCopy, 4, "NVIM: STD+ERR OUT:")
	table.insert(buffCopy, "NVIM: PRESS Q TO EXIT")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, buffCopy)

	local width = 95
	local height = 20
	local opts = {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = "minimal",
		border = { "█", "█", "█", "█", "█", "█", "█", "█" },
	}

	local win = vim.api.nvim_open_win(buf, true, opts)
	vim.wo[win].statusline = "PRESS Q OR ENTER TO EXIT"
	vim.bo.modifiable = false
	vim.bo.buftype = "nofile"
	vim.bo.bufhidden = "hide"
	vim.bo.swapfile = false
	vim.cmd("stopinsert")
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf })
end

-- parses and executes jobs.
-- When testing execute wherein output = {} and ops = the command you intend to execute.
-- e.g RunCommand(1, passByRef)
--
alb.RunCommand = function(ops, output, useSync)
	local fileName = ".albabc.json"
	local Job = require("plenary.job")
	local Path = require("plenary.path")

	output = output or nil -- explicitly set default
	local index
	if output == nil then
		index = ops.fargs[1]
	else
		index = ops
	end

	local topMostGit = nil
	local path = vim.api.nvim_buf_get_name(0)

	if path == nil or string.len(path) == 0 then
		path = vim.fn.getcwd()
	end

	local split = string.split(path, ":/")
	local dir = nil
	local root = ""
	local oil = false
	if #split == 1 then
		root = split[1]
	else
		oil = split[1] == "oil"
		root = split[2]
	end
	if not oil then
		local p = Path:new(path)
		dir = p:parent():absolute()
	else
		dir = root
	end

	local targetCommands = nil
	local immediate = Path:new(dir):joinpath(fileName)

	if immediate:exists() then
		targetCommands = Path:new(immediate:absolute())
	else
		Job:new({
			command = "git",
			args = { "rev-parse", "--show-toplevel" },
			cwd = dir,
			on_exit = function(j, return_val)
				local result = j:result()
				topMostGit = result[1]
			end,
		}):sync() --

		if topMostGit == nil then
			print("buff is not in a git!")
			return
		end

		-- If we're in a git repo, we let you use a local .albabc.json for a given directory chain
		targetCommands = Path:new(dir):find_upwards(fileName) or Path:new(topMostGit):joinpath(fileName)
	end

	if targetCommands:exists() == false then
		print(".albabc.json does not exist in " .. targetCommands:absolute() .. " from path " .. path)
		return
	end

	local success, jsonResult = pcall(function()
		local buildData = targetCommands:read()
		return vim.fn.json_decode(buildData)
	end)

	if success == false then
		print("failed to parse!")
		return
	end

	local jsonBuildCommands = jsonResult.build_commands
	local env_vars = jsonResult.env_vars or {}
	env_vars["BUF"] = vim.api.nvim_buf_get_name(0)
	-- When output is nil its being used in a debugging context
	-- Otherwise its being executed from nvim's commands
	local nArgs = 0
	if output == nil then
		for i, a in ipairs(ops.fargs) do
			if i ~= 1 then
				nArgs = nArgs + 1
				-- The first arg in fargs is key of the command
				env_vars["ARG" .. tostring(i - 1)] = a
			end
		end
	end

	-- print(vim.inspect(env_vars))
	-- print(vim.inspect(ops.fargs))
	-- print(vim.inspect(index))
	-- print(vim.inspect(ops))
	local jsonBuildCommandsSelected = jsonBuildCommands[index] or jsonBuildCommands[tonumber(index)]
	if jsonBuildCommandsSelected == nil then
		print("The command provided was not found in the .albabc.json. Please check its formatting.")
		return
	end
	if
		jsonBuildCommandsSelected.cwd == nil
		or jsonBuildCommandsSelected.shell_cmd == nil
		or jsonBuildCommandsSelected.name == nil
	then
		print("name, shell_cmd, and, cwd are all required fields, but one of them was not found.")
		return
	end

	local mandatoryArgs = jsonBuildCommandsSelected.min_args or nil

	if mandatoryArgs ~= nil and mandatoryArgs > nArgs then
		print("Less args provided than the minimum: " .. tostring(mandatoryArgs))

		if jsonBuildCommandsSelected.prompt ~= nil then
			print(jsonBuildCommandsSelected.prompt)
		end

		vim.api.nvim_feedkeys(":ABExecute " .. index .. " ", "n", false)
		return
	end

	if jsonBuildCommandsSelected.autoopen_whitelist and jsonBuildCommandsSelected.autoopen_blacklist then
		print("You must pick either autoopen_whitelist or autoopen_blacklist.")
		return
	end

	local mode = "off"
	local list = {}
	if jsonBuildCommandsSelected.autoopen_whitelist then
		list = jsonBuildCommandsSelected.autoopen_whitelist
		mode = "white"
	elseif jsonBuildCommandsSelected.autoopen_blacklist then
		list = jsonBuildCommandsSelected.autoopen_blacklist
		mode = "black"
	end

	local entries = {}
	for i, value in ipairs(jsonBuildCommands) do
		table.insert(entries, value.name)
	end

	local relapth = targetCommands:parent():joinpath(jsonBuildCommandsSelected.cwd)
	if relapth:exists() == false then
		print("The cwd provided does not exist!")
		return
	end
	--print(relapth)
	local std = {}
	local time = os.time()

	-- Hard coding the envvars meerge because sometimes they wouldn't for some reason.
	local env = vim.tbl_extend("force", vim.fn.environ(), env_vars)
	local name = tostring(time) .. " " .. jsonBuildCommandsSelected.name
	local j = Job:new({
		command = "sh",
		args = { "-c", jsonBuildCommandsSelected.shell_cmd },
		stderr_to_stdout = true,
		cwd = relapth:absolute(),
		env = env,
		on_stdout = function(_, line, j)
			if line then
				if jsonBuildCommandsSelected.print_ongoing then
					vim.schedule_wrap(function()
						vim.notify(line)
					end)()
				end
				addToOngoingStd(j.pid, line)
				table.insert(std, line)
			end
		end,
		on_stderr = function(_, line, j)
			if line then
				if jsonBuildCommandsSelected.print_ongoing then
					vim.schedule_wrap(function()
						vim.notify(line)
					end)()
				end
				addToOngoingStd(j.pid, line)
				table.insert(std, line)
			end
		end,
		on_exit = function(j, return_val)
			local returny = tostring(return_val)
			local test = {
				time = time,
				buff = std,
			}

			vim.defer_fn(function()
				vim.notify("Your job: " .. jsonBuildCommandsSelected.name .. ", has exited: " .. returny)

				if not jsonBuildCommandsSelected.print_result and mode ~= "off" then
					local contains = table.listContains(list, return_val)
					local showPopup = (mode == "white" and contains) or (mode == "black" and not contains)
					if showPopup then
						openPopup(std, time, jsonBuildCommandsSelected.name, return_val)
					end
				end

				if jsonBuildCommandsSelected.print_result then
					print(vim.inspect(std))
				end
				if jsonBuildCommandsSelected.autoopen then
					openPopup(std, time, jsonBuildCommandsSelected.name, return_val)
				end
			end, 20)
			removeOngoig(j.pid)
			_G.addToABLogs(name, test)
		end,
	})

	if output ~= nil then
		output[0] = name
	end

	if useSync then
		j:sync()
	else
		j:start()
	end
	vim.notify("Your job: " .. jsonBuildCommandsSelected.name .. ", has started ")

	addNewOnGoing(j.pid, jsonBuildCommandsSelected.name, time)

	if jsonBuildCommandsSelected.autoopen_ongoing then
		vim.cmd("new")
		vim.bo.modifiable = false
		vim.bo.buftype = "nofile"
		vim.bo.bufhidden = "hide"
		vim.bo.swapfile = false

		local buf = vim.api.nvim_get_current_buf()
		_G.addStdWindowListener(j.pid, buf)
	end
end

function ShowResults()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local previewers = require("telescope.previewers")

	local test = getABLogs()
	local keys = {}
	local buffs = {}

	for k, v in pairs(test) do
		table.insert(keys, k)
		table.insert(buffs, v)
	end

	--print(vim.inspect(keys))

	table.sort(keys, function(k1, k2)
		return test[k1].time > test[k2].time
	end)

	local currentIndex = 1
	local conf = require("telescope.config").values
	local opts = opts or {}
	pickers
		.new(opts, {
			prompt_title = "Command logs. Enter to open, Q to close",
			finder = finders.new_table({
				results = keys,

				entry_maker = function(entry)
					return {
						value = entry,
						display = entry,
						ordinal = entry,
					}
				end,
			}),
			previewer = previewers.new_buffer_previewer({
				define_preview = function(self, entry, status)
					currentIndex = entry.index
					local key = keys[currentIndex]
					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, test[key].buff)
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(c, map)
				map("i", "<enter>", function()
					vim.cmd("stopinsert")
					-- TOOD: standardize, not call new and nvim_create_buf in different places.
					vim.cmd("new")
					local key = keys[currentIndex]
					vim.api.nvim_buf_set_lines(0, 0, -1, false, test[key].buff)
					vim.bo.modifiable = false
					vim.bo.buftype = "nofile"
					vim.bo.bufhidden = "hide"
					vim.bo.swapfile = false
				end)
				map("i", "q", function()
					require("telescope.actions").close(c)
				end)
				return true
			end,
		})
		:find()
end

function ShowOngoing()
	local Job = require("plenary.job")
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local previewers = require("telescope.previewers")

	local test = getOngoing()
	local keys = {}
	local buffs = {}

	for k, v in pairs(test) do
		table.insert(keys, tostring(k))
		table.insert(buffs, v)
	end

	--print(vim.inspect(keys))

	table.sort(keys, function(k1, k2)
		return test[tonumber(k1)].timeStarted > test[tonumber(k2)].timeStarted
	end)

	local currentIndex = 1
	local conf = require("telescope.config").values
	local opts = opts or {}
	pickers
		.new(opts, {
			prompt_title = "Kill ongoing task. Enter to kill, Q to exit, o to open",
			finder = finders.new_table({
				results = keys,
			}),
			previewer = previewers.new_buffer_previewer({
				define_preview = function(self, entry, status)
					currentIndex = entry.index
					local key = keys[currentIndex]
					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, test[tonumber(key)].std)
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(c, map)
				map("i", "<enter>", function()
					local key = keys[currentIndex]
					Job:new({
						command = "kill",
						args = { key },
					}):sync()
					require("telescope.actions").close(c)
				end)
				map("n", "q", function()
					require("telescope.actions").close(c)
				end)
				map("n", "o", function()
					require("telescope.actions").close(c)
					vim.cmd("stopinsert")
					-- TOOD: standardize, not call new and nvim_create_buf in different places.
					vim.cmd("new")
					local buf = vim.api.nvim_get_current_buf()
					local key = keys[currentIndex]
					_G.addStdWindowListener(tonumber(key), buf)
					vim.api.nvim_buf_set_lines(buf, 0, -1, false, test[tonumber(key)].std)
					vim.bo.modifiable = false
					vim.bo.buftype = "nofile"
					vim.bo.bufhidden = "hide"
					vim.bo.swapfile = false
				end)

				return true
			end,
		})
		:find()
end
-- to execute the function

vim.api.nvim_create_user_command("ABExecute", alb.RunCommand, { nargs = "+" })

vim.api.nvim_create_user_command("ABView", ShowResults, {})

vim.api.nvim_create_user_command("ABShowOngoing", ShowOngoing, {})

vim.keymap.set("n", "<leader>xb1", "<cmd>ABExecute 1<cr>", {})
vim.keymap.set("n", "<leader>xb2", "<cmd>ABExecute 2<cr>", {})
vim.keymap.set("n", "<leader>xb3", "<cmd>ABExecute 3<cr>", {})
vim.keymap.set("n", "<leader>xb4", "<cmd>ABExecute 4<cr>", {})
vim.keymap.set("n", "<leader>xb5", "<cmd>ABExecute 5<cr>", {})
vim.keymap.set("n", "<leader>xb6", "<cmd>ABExecute 6<cr>", {})
vim.keymap.set("n", "<leader>xb7", "<cmd>ABExecute 7<cr>", {})
vim.keymap.set("n", "<leader>xb8", "<cmd>ABExecute 8<cr>", {})
vim.keymap.set("n", "<leader>xb9", "<cmd>ABExecute 9<cr>", {})

vim.keymap.set("n", "<leader>xbs", "<cmd>ABView<cr>", {})
vim.keymap.set("n", "<leader>xba", "<cmd>ABShowOngoing<cr>", {})

vim.api.nvim_set_keymap("n", "<leader>xb5", ":ABExecute 5 ", {})

vim.api.nvim_set_keymap("n", "<leader>xb0", ":ABExecute ", {})
--v-vim.keymap.set("n", "<leader>xbl", "<cmd>:source ~/.config/nvim/lua/config/keymaps.lua <CR>")

return alb
