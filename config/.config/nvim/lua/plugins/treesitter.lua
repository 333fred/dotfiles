return {
    {
        "nvim-treesitter/nvim-treesitter",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter").install({ "c_sharp" })
            vim.api.nvim_create_autocmd("FileType", {
                pattern = "cs",
                callback = function()
                    vim.treesitter.start()
                end,
            })
        end,
    },
    { "HiPhish/rainbow-delimiters.nvim", dependencies = { "nvim-treesitter/nvim-treesitter" } },
}
