return {
    "esmuellert/codediff.nvim",
    cmd = "CodeDiff",
    keys = {
        { "<leader>Gd", function() require("config.git-review").local_diff() end, desc = "Toggle Git changes explorer" },
        { "<leader>Gf", "<Cmd>CodeDiff file HEAD<CR>", desc = "Diff current file against HEAD" },
    },
    opts = {
        highlights = {
            line_insert = "DiffAdd",
            line_delete = "DiffDelete",
            char_insert = "#43563f",
            char_delete = "#604047",
        },
        explorer = { view_mode = "tree", width = 40 },
        keymaps = {
            view = {
                toggle_explorer = "<leader>GE",
                focus_explorer = "<leader>Ge",
            },
        },
    },
    config = function(_, opts)
        require("config.codediff-content").setup()
        require("codediff").setup(opts)
    end,
}
