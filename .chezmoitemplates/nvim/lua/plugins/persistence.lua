return {
    "folke/persistence.nvim",
    dependencies = { "folke/snacks.nvim" },
    event = "BufReadPre",
    opts = {},
    config = function(_, opts)
        vim.opt.sessionoptions:remove("blank")
        require("ui.sessions").setup()
        require("persistence").setup(opts)
    end,
    keys = {
        {
            "<leader>sr",
            function() require("ui.sessions").reload() end,
            desc = "Reload session",
        },
        {
            "<leader>sc",
            function() require("ui.sessions").clear() end,
            desc = "Clear session and open explorer",
        },
    },
}
