return {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
        options = {
            theme = require("plugins.theme.ocean").statusline_theme(),
            globalstatus = true,
            component_separators = { left = "|", right = "|" },
            section_separators = { left = "", right = "" },
        },
        sections = {
            lualine_a = { "mode" },
            lualine_b = { "branch" },
            lualine_c = { { "filename", path = 1, symbols = { modified = " [+]", readonly = " [RO]" } } },
            lualine_x = {
                {
                    "diagnostics",
                    sources = {
                        function()
                            local counts = require("config.git-diagnostics").counts()
                            return { error = counts[1], warn = counts[2], info = counts[3], hint = counts[4] }
                        end,
                    },
                    symbols = { error = "E:", warn = "W:", info = "I:", hint = "H:" },
                },
                function()
                    local clients = vim.lsp.get_clients({ bufnr = 0 })
                    if #clients == 0 then
                        return ""
                    end
                    return "LSP: " .. table.concat(vim.tbl_map(function(client)
                        return client.name
                    end, clients), ", ")
                end,
                "filetype",
            },
            lualine_y = { "progress" },
            lualine_z = { "location" },
        },
    },
}
