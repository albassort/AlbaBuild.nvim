-- nvim --headless -c "PlenaryBustedDirectory tests/plenary/ {options}"
local lazy_path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

vim.opt.rtp:prepend(lazy_path)
require("lazy").setup({
	{
		"nvim-telescope/telescope.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
	},
	{
		dir = "/mnt/coding/QestBet/THB/subrepos/albaBuildNvim",
		name = "alc",
	},
})
local alc = require("alc")
local result = {}

describe("some basics", function()
	local bello = function(boo)
		return "bello " .. boo
	end

	local bounter

	before_each(function()
		bounter = 0
	end)

	it("some test", function() end)

	it("some other test", function()
		assert.equals(0, 0)
	end)
end)
