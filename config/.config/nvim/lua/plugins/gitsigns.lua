return {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    keys = {
        { "<localleader>b", function() require("gitsigns").toggle_current_line_blame() end, desc = "Toggle line blame" },
        { "<localleader>h", function() require("gitsigns").preview_hunk_inline() end, desc = "Preview Git hunk inline" },
    },
    opts = {
        signs = {
            add = { text = "+" },
            change = { text = "~" },
            delete = { text = "_" },
            topdelete = { text = "^" },
            changedelete = { text = "~" },
        },
        signs_staged_enable = true,
        current_line_blame_opts = { delay = 500 },
    },
}
