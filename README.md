# What is AlbaBuild.nvim
AlbaBuild.nvim is a simple, git portable, json configured, hotkey-driven, build system for nvim

AlbaBuild.nvim is a simple nvim plugin, to allow build commands to be hotkey-bound and embedded in git repositories. This enables you to simplify your work flow, remove repetitive terminal usage, and get new contributors in sync with established contributors easier.

It is 
- Primarily git based, your git repo determines the commands.
- Easy to setup 
- Portable

### Why?

I have, for years, only ever programmed with a terminal open, somewhere. Be it on a different monitors, different tab, using :term, using screen or tmux, etc. And, usually its with predefined commands. I will often loose, or forget about one, and have to rewrite it if its not saved in a .sh. And, critically, if I were to leave and comeback to a given repository over years, I would need to relearn the commands, and what they do. This is my solution to streamline this process.

### Features
- Json configuration
- Stores logs for all programs, accessible from nvim.
- Keep track of ongoing commands, and kill them when needed.`
- Provide arguments for each command, from your nvim command line.
- Show the std+stderr output in a popup window after exiting.
- Blacklist or whitelist this popup via exitcode (e.g only popup when the program fails, or if timeout (140) is called).
- Print ongoing std/stderr out to your nvim-status line .
- Portable, other developers can pickup where you left off and reuse commonly used bash commands.
- Specify env_vars in a dedicated section for re-use throughout. Very useful for developers, makes configuring the commands for the given environment simple.
- Makes you the coolest (or least cool?) person working on a given project, or your (no) money back!

# Dependencies
Only two dependencies, none are optional.
- Telescope 
    - Used for choice popups, in ABView and ABShowOngoing.
- Plenary
    - General helper library, used for executing shell commands and a bunch of small things

# Platform Support

AlbaBuild.nvim has been tested on
```
NVIM v0.11.3
LuaJIT 2.1.1741730670
```
As a linux developer, it is difficult to test and support other platforms. As such, it is currently only designed to work on Linux. Contributions are welcome to support multiple platforms

# Lazy

This works for the lazy.nvim package manager.
```lua
{
    "https://github.com/albassort/AlbaBuild.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim"},
}
```

# File placement
To specify the given build commands you want, you must, of course, have them be on disk. The places I find most convenient is in the git root.

`.albabc.json` is the name used for the files in which build commands are stored. And, you cannot use build commands without a git repo. But this can be limiting, so each directory can also have their own .albabc.json, separate. The decision for which to use is based on **the current buffer file path**, if this can't be found, it used the pwd vim pwd (configurable with cd).  For example:

```
├── .albabc.json
├── .git
├── README.md
└── src
    ├── my_stuff.py
    └── special_stuff
        ├── .albabc.json
        ├── bash_to_test.sh
        └── extra_secret
            └── dont_modify_me.c
```
1. While you are editing my_stuff.py, it will use the root .albabc.json, next to your .git.
2. But if you are editing bash_to_test.sh, it will use the .albabc.json in its own folder, with its own keybinds.
3. You may think dont_modify_me.c would use the .albabc specified in the folder above. No, it would not. It would use the .git configuration, as it lacks one.

In all cases `git rev-parse --show-toplevel` is executed to determine the root of the directory, and thus, the primary .albabc to be used.
# Json Format
## EnvVars 
EnvVars can be specified in an "env_vars" block on the root of the build commands. But, specifying env_vars is **not required**.
```json
{
  "env_vars": 
    {
      "Key1": "hello World"
    }
}

```
Each key is assigned to the env with the corresponding value. It can then be used as `Key1`.

When the command is executed, it merges the env_vars with the default system env_vars in your bash configuration, as used by sh -c. That is to say, your normal $PATH is used. Specifically the `vim.fn.environ()` function is used. These can be overridden by you, by specifying them in the env_vars section.

## build_commands
### Mandatory values
- "name": The name of the variable. Should be unique for your convenience but this is not required, it shouldn't cause any issues.
- "shell_cmd": The command you want to execute
- "cwd": The directory you wish to execute the shell_cmd in. If you don't wish to use this, please set it to "." which will use the directory that plenary uses by default
### Optional values
- "autoopen" (bool): Automatically opens the command output 
- "print_result" (bool): prints the result using nvim print(), lighter than auto open, same principle 
- "autoopen_whitelist" (array[int]): If the return code is equal to any of these values, perform autoopen. This is incompatible with autoopen_blacklist
- "autoopen_blacklist" (array[int]): If the return code not is equal to any of these values, perform autoopen. This is incompatible with autoopen_whitelist
- "print_ongoing" (bool): If you wish to be notified as a program is ongoing, of the std and stderr outputs, this will print them in the status line.
- "autoopen_ongoing" (bool): Automatically opens the STDOUT+STDERR in a new vim buffer. This can be done otherwise with ABShowOngoing and hitting "o".
- "min_args" (int): If your given command requires parameters, you can mandate that they are given. If there are less arguments given than min_args, it will prompt you again to re-enter the command.
- "prompt": (string) This will be shown when the arguments given is less than min_args

### Format
The commands are given in an array. The array can be formatted in two different ways as per the json spec
```json
{
    "build_commands": 
        [
            {
              "name": "Hello, World!",
              "shell_cmd": "echo 'Hello, World!' ",
              "cwd": ".",
            }

        ]
}
```

This binds hello world to 1, `<leader> xb1`. 

```json
{
  "build_commands": {
    "1": {
      "name": "Hello, World!",
      "shell_cmd": "echo 'Hello, World!'",
      "cwd": "."
    },
    "4": {
      "name": "I forgot who I was ",
      "shell_cmd": "whoami",
      "cwd": ".",
      "autoopen": true
    },
    "named": {
      "name": "I am named! I also take args, and open if they do not equal 'Hello'!",
      "shell_cmd": "if [ \"$ARG1\" != 'Hello' ]; then echo '$ARG1'; exit 1; fi",
      "cwd": ".",
      "min_args": 1,
      "autoopen_whitelist": [
        1
      ]
    }
  }
}
```

This also allows for each of the objects to be bound to xb1-9, as, it matches by string. It also allows names, easily executable through `<leader>xb0`. Numbers are arbitrary, and do not require order.

### Example
```json
{
  "env_vars": {
    "WALADR": "bcrt1q5ezrg7u0v43g0dvya2m85f8h2ftd9r5839xme7",
    "RPCP": "password1",
    "RPCU": "user1",
    "RPCX": "/mnt/btc/bitcoin-28.0/bin/bitcoin-cli",
    "RPCPORT": "18011"
  },
  "build_commands": [
    {
      "name": "Compile and run upper",
      "shell_cmd": "nim c upper",
      "cwd": "./src/",
      "autoopen": true,
      "print_result": false
    },
    {
      "name": "Generate RPC",
      "shell_cmd": "$RPCX -rpcport=$RPCPORT -rpcpassword=$RPCP -rpcuser=$RPCU -regtest generatetoaddress 50 $WALADR",
      "cwd": "./src/",
      "autoopen": false,
      "print_result": true
    }
  ]
}

```
This allows for an easily configurable, portable unix focused testing apparatus. Developers can replace the envvars and build commands become usable to them.

## Notes
### Maximum number of commands 
This is **no maximum** number of commands. ABExecute, as described below, takes in an arbitrary integer. In the suggested keymap, <leader>xb0 fills the command with ABExecute but without cr, to make arbitrary indexes and using arguments easier 

# Recommended keybinds 
```lua
-- Executers
vim.keymap.set("n", "<leader>xb1", "<cmd>ABExecute 1<cr>", {})
vim.keymap.set("n", "<leader>xb2", "<cmd>ABExecute 2<cr>", {})
vim.keymap.set("n", "<leader>xb3", "<cmd>ABExecute 3<cr>", {})
vim.keymap.set("n", "<leader>xb4", "<cmd>ABExecute 4<cr>", {})
vim.keymap.set("n", "<leader>xb5", "<cmd>ABExecute 5<cr>", {})
vim.keymap.set("n", "<leader>xb6", "<cmd>ABExecute 6<cr>", {})
vim.keymap.set("n", "<leader>xb7", "<cmd>ABExecute 7<cr>", {})
vim.keymap.set("n", "<leader>xb8", "<cmd>ABExecute 8<cr>", {})
vim.keymap.set("n", "<leader>xb9", "<cmd>ABExecute 9<cr>", {})

vim.api.nvim_set_keymap("n", "<leader>xb0", ":ABExecute ", {})
-- View logs
vim.keymap.set("n", "<leader>xbs", "<cmd>ABView<cr>", {})

-- View active ongoing tasks to kill them.
vim.keymap.set("n", "<leader>xba", "<cmd>ShowOngoing<cr>", {})

```

# :ABExecute
## Args
#### Arg 1
- The first arg for ABExecute is the indice of the command. There is no max amount of commands that can be bound, but it is necessary that the json is in array format.
#### Arg 2 +
- Each argument after the first argument is bound to $ARGV and the corresponding number of arguments from the first additional argument. e.g 

```json
{
  "build_commands": {
    "1": {
      "name": "Nvim Args Example",
      "shell_cmd": "I like $ARG1 and I also like $ARG2",
      "cwd": "./src/"
    }
  }
}
```
- When executed with `ABExecute 1 Cats Cows` you get `I like Cats and I also like Cows`

# :ABView
ABView opens a telescope with all commands executed, from oldest to newest. Hitting enter will open, in a new buffer

- After a task is started, its stdout and stderr is saved in `_G.ABLogs`.

- This is not persistent between startups, and is saved in memory. 

# :ABShowOngoing
There is an obvious issue with executing commands with &, and not logging the PID. For a lot of shell commands, you need to kill them, eventually. Hence ABShowOngoing.

- After a task is started with ABExecute it is added to `_G.OngoingPid`, and, as new lines come from stdout and stderr, it is added to the given PID's `std` value

- These ongoing tasks can then be killed by hitting ENTER, from ABShowOngoing

- The current buffer can also be opened with o

- This is not persistent between startups, and is saved in memory. 

- After execution ends, each PID is explicitly removed from memory, and can no longer be seen with ABShowOngoing. But it can be seen with ABView.

### NOTE
Because some programs use buffered stdouts and stderrs, sometimes you cannot preview the std err/out after killing a program, or before killing it. See section below

# Precautions
### MITM (Man In the Middle)
Storing arbitrary bash commands, then executing them without checking, a risk of a carries MITM attack. This can be mitigated by setting your `.albabc.json`'s permissions to umask `600`, so only you can read and write to the given file.
### To Timeout or Not To Timeout
#### To timeout
Timeout is a Linux command to automatically kill a given command should it live too long. `timeout 50 g++ ...` would kill g++ should it live longer than 50 seconds.

By using this in your .albabc.json e.g `"shell_cmd": "timeout 20 python3 ./example.py"`, you can preemptively kill the command without needing to do use :ABShowOngoing.

#### Gotchas
Some commands, such as python3, buffer the stdout and if they are killed by SIGKILL through timeout, it can inadvertently prevent the flushing out stdout to nvim.

This can be mitigated by using `timeout --signal=SIGINT 20s` where possible. This allows programs with buffered stdout to flush to stdout. 

#### Python Specific
adding `-u` to python3 allows it to run in unbuffered mode, for which, this ceases to be an issue. E.g `"shell_cmd": "timeout 2 python3 -u ./example.py"`

# TODO 
- Implement standard testing (plenary testing breaks shell commands for some reason)

##### Support
*If you like the project, and wish to show your support, you can go to [page](https://donate.albassort.com) where you send me XMR, BTC, and SOL. Anything is deeply appreciated, and keeps me motivated. Thank you.*
 

