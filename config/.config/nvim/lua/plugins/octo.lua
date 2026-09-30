return {
    "pwntester/octo.nvim",
    cmd = "Octo",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "folke/snacks.nvim" },
    opts = {
        picker = "snacks",
        -- Local right-side buffers let Roslyn attach; historical left-side buffers cannot.
        use_local_fs = true,
        timeout = 30000,
        mappings = {
            review_diff = {
                select_prev_entry = { lhs = "\\k", desc = "move to previous changed file" },
                select_next_entry = { lhs = "\\j", desc = "move to next changed file" },
            },
            review_thread = {
                select_prev_entry = { lhs = "\\k", desc = "move to previous changed file" },
                select_next_entry = { lhs = "\\j", desc = "move to next changed file" },
            },
            file_panel = {
                select_prev_entry = { lhs = "\\k", desc = "move to previous changed file" },
                select_next_entry = { lhs = "\\j", desc = "move to next changed file" },
            },
        },
    },
}
