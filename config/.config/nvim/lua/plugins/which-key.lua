return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
        preset = "modern",
        win = { border = "rounded" },
        spec = {
            { "<leader>", group = "Editor", mode = { "n", "x" } },
            { "<leader>a", group = "Copilot", mode = { "n", "x" } },
            { "<leader>s", group = "Sessions" },
            { "<localleader>", group = "Git/review", mode = { "n", "x" } },
            { "<localleader>r", group = "Reviews", mode = { "n", "x" } },
            { "<localleader>c", group = "Comments", mode = { "n", "x" } },
            { "<localleader>p", group = "Pull requests" },
            { "<localleader>d", group = "Diffs" },
            { "<localleader>h", group = "Hunks" },
            { "<localleader>g", group = "Git" },
            { "<localleader>x", group = "Merge conflicts" },
        },
    },
    keys = {
        {
            "<leader>?",
            function() require("which-key").show({ global = true }) end,
            mode = { "n", "x" },
            desc = "Show available keymaps",
        },
    },
}
