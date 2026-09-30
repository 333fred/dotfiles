return {
    "pwntester/octo.nvim",
    cmd = "Octo",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "folke/snacks.nvim" },
    opts = {
        picker = "snacks",
        use_local_fs = true,
        timeout = 30000,
    },
}
