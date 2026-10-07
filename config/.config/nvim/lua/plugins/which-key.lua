return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
        preset = "modern",
        win = { border = "rounded" },
        spec = {
            { "<leader>", group = "Editor", mode = { "n", "x" } },
            { "<localleader>", group = "Git/review", mode = { "n", "x" } },
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
