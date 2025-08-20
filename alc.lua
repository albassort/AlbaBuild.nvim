local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local Job = require("plenary.job")
local Path = require("plenary.path")

vim.keymap.set("n", "gw", vim.diagnostic.open_float, { desc = "Show diagnostics under cursor" })

--https://zenn.dev/kawarimidoll/scraps/d51d3407a5bd3b
string.gfind = function(str, pattern)
	local from_idx = nil
	local to_idx = 0
	return function()
		from_idx, to_idx = string.find(str, pattern, to_idx + 1)
		return from_idx, to_idx
	end
end

--https://zenn.dev/kawarimidoll/scraps/d51d3407a5bd3b
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

local str = "oil:///my/path/"
local pattern = "://"
print(vim.inspect(string.split(str, pattern)))
_G.test = _G.test or {}
function _G.addToTest(key, val)
	_G.test[key] = val
end

function _G.getTest()
	return _G.test
end

function _G.restTest()
	_G.test = {}
end

local function open_popup(buff, time, name, result_val)
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

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf })
end

local RunCommand = function(ops)
	local index = tonumber(ops.fargs[1])

	local topMostGit = nil
	local path = vim.api.nvim_buf_get_name(0)

	if path == nil then
		return
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
	if oil == false then
		local p = Path:new(path)
		dir = p:parent():absolute()
	else
		dir = root
	end

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

	local pathTest = Path:new(topMostGit):joinpath(".albabc.json")
	if pathTest:exists() == false then
		print(".albabc.json does not exist")
		return
	end

	local success, jsonResult = pcall(function()
		-- risky code here
		local buildData = pathTest:read()
		print(buildData)
		return vim.fn.json_decode(buildData)
	end)

	if success == false then
		print("failed to parse!")
		return
	end

	local jsonBuildCommands = jsonResult.buildCommands
	local envVars = jsonResult.envVars

	envVars["BUF"] = vim.api.nvim_buf_get_name(0)

	print(index)
	print("!!!!")
	if jsonBuildCommands[index] == nil then
		print("Index out of bounds; the json is supposed to be array of objects")
		return
	end
	if
		jsonBuildCommands[index].cwd == nil
		or jsonBuildCommands[index].shell_cmd == nil
		or jsonBuildCommands[index].name == nil
	then
		print("name, shell_cmd, and, cwd are all required fields, but one of them was not found.")
		return
	end

	local entries = {}
	for i, value in ipairs(jsonBuildCommands) do
		table.insert(entries, value.name)
	end

	local relapth = Path:new(dir):joinpath(jsonBuildCommands[index].cwd)
	if relapth:exists() == false then
		print("The cwd provided does not exist!")
		return
	end
	print(relapth)
	local std = {}
	local time = os.time()
	Job:new({
		command = "sh",
		args = { "-c", jsonBuildCommands[index].shell_cmd },
		stderr_to_stdout = true,
		cwd = relapth:absolute(),
		env = envVars,
		on_stdout = function(_, line)
			if line then
				table.insert(std, line)
			end
		end,
		on_stderr = function(_, line)
			if line then
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
				vim.notify(
					"Your job: " .. jsonBuildCommands[index].name .. ", has exited: " .. returny,
					vim.log.levels.INFO,
					{ title = "MyStatus" }
				)
				if jsonBuildCommands[index].print_result == true then
				end
				if jsonBuildCommands[index].autoopen == true then
					open_popup(std, time, jsonBuildCommands[index].name, return_val)
				end
			end, 20)

			_G.addToTest(tostring(time) .. " " .. jsonBuildCommands[index].name, test)
		end,
	}):start()
end

function ShowResults()
	local test = getTest()
	local keys = {}
	local buffs = {}

	for k, v in pairs(test) do
		table.insert(keys, k)
		table.insert(buffs, v)
	end

	print(vim.inspect(keys))

	table.sort(keys, function(k1, k2)
		return test[k1].time > test[k2].time
	end)

	local currentIndex = 1
	local conf = require("telescope.config").values
	local opts = opts or {}
	pickers
		.new(opts, {
			prompt_title = "RunCommand",
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
					vim.cmd("new")
					local key = keys[currentIndex]
					vim.api.nvim_buf_set_lines(0, 0, -1, false, test[key].buff)
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

vim.api.nvim_create_user_command("ABExecute", RunCommand, { nargs = 1 })
vim.api.nvim_create_user_command("ABView", ShowResults, {})

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

--vim.keymap.set("n", "<leader>xbl", "<cmd>:source ~/.config/nvim/lua/config/keymaps.lua <CR>")
