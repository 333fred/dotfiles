return {
    "esmuellert/codediff.nvim",
    dependencies = { "git-review.nvim" },
    cmd = "CodeDiff",
    keys = {
        { "<localleader>g", function() require("git-review").local_diff() end, desc = "Toggle Git changes explorer" },
        { "<localleader>d", function() require("git-review").local_diff() end, desc = "Toggle Git changes explorer" },
        { "<localleader>f", "<Cmd>CodeDiff file HEAD<CR>", desc = "Diff current file against HEAD" },
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
                next_hunk = "<localleader>j",
                prev_hunk = "<localleader>k",
                next_file = "<localleader>J",
                prev_file = "<localleader>K",
                toggle_explorer = "<localleader>E",
                focus_explorer = "<localleader>e",
                stage_hunk = "<localleader>hs",
                unstage_hunk = "<localleader>hu",
                discard_hunk = "<localleader>hr",
            },
            conflict = {
                accept_incoming = "<localleader>ct",
                accept_current = "<localleader>co",
                accept_both = "<localleader>cb",
                discard = "<localleader>cx",
                accept_all_incoming = "<localleader>cT",
                accept_all_current = "<localleader>cO",
                accept_all_both = "<localleader>cB",
                discard_all = "<localleader>cX",
            },
        },
    },
    config = function(_, opts)
        require("git-review.content").setup()
        require("codediff").setup(opts)
    end,
}
