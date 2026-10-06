return {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    keys = {
        { "<leader>Gb", function() require("gitsigns").toggle_current_line_blame() end, desc = "Toggle line blame" },
        { "<leader>Gh", function() require("gitsigns").preview_hunk_inline() end, desc = "Preview Git hunk inline" },
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
        on_attach = function(bufnr)
            for key, direction in pairs({ ["]c"] = "next", ["[c"] = "prev" }) do
                vim.keymap.set("n", key, function()
                    if vim.wo.diff then
                        vim.cmd.normal({ key, bang = true })
                    else
                        require("gitsigns").nav_hunk(direction)
                    end
                end, { buffer = bufnr, desc = direction .. " Git hunk" })
            end
        end,
    },
}
