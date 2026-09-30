return {
    "pwntester/octo.nvim",
    cmd = "Octo",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "folke/snacks.nvim" },
    opts = {
        picker = "snacks",
        -- Local right-side buffers let Roslyn attach; historical left-side buffers cannot.
        use_local_fs = true,
        timeout = 30000,
    },
}
