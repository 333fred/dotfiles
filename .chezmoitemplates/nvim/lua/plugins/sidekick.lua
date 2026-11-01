return {
    "folke/sidekick.nvim",
    event = "VeryLazy",
    opts = {
        cli = {
            win = {
                keys = {
                    -- Keep Copilot's input editing and suspend shortcuts intact.
                    buffers = false,
                    files = false,
                    hide_ctrl_z = false,
                    prompt = false,
                    stopinsert = { "<Esc>", "stopinsert", mode = "t", desc = "Enter normal mode" },
                    send_escape = { "<M-Esc>", "<Esc>", mode = "t", desc = "Send Escape to CLI" },
                    nav_left = false,
                    nav_down = false,
                    nav_up = false,
                    nav_right = false,
                },
            },
        },
    },
    keys = {
        {
            "<M-CR>",
            function() require("sidekick").nes_jump_or_apply() end,
            mode = { "n", "i" },
            desc = "Jump to/accept next edit suggestion",
        },
        {
            "<leader>aa",
            function() require("sidekick.cli").toggle({ name = "copilot", focus = true }) end,
            desc = "Toggle Copilot CLI",
        },
        {
            "<leader>at",
            function() require("sidekick.cli").send({ name = "copilot", msg = "{this}" }) end,
            mode = { "n", "x" },
            desc = "Send code to Copilot",
        },
        {
            "<leader>af",
            function() require("sidekick.cli").send({ name = "copilot", msg = "{file}" }) end,
            desc = "Send file to Copilot",
        },
    },
}
