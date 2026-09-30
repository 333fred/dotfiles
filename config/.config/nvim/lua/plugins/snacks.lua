return {
    "folke/snacks.nvim",
    priority = 900,
    lazy = false,
    opts = {
        picker = {
            enabled = true,
            sources = {
                explorer = {
                    hidden = true,
                    ignored = true,
                    actions = {
                        cancel = function()
                            vim.cmd.stopinsert()
                            vim.cmd.nohlsearch()
                        end,
                    },
                },
                gh_pr = {
                    finder = function(opts, ctx)
                        return require("plugins.snacks.pr-picker").finder(opts, ctx)
                    end,
                    show_delay = 0,
                    confirm = function(picker, item)
                        if not item then
                            return
                        end
                        picker:close()
                        vim.cmd("Octo " .. item.url)
                    end,
                },
            },
        },
        gh = { enabled = true },
        explorer = { enabled = true },
        lazygit = {
            enabled = true,
            win = {
                keys = {
                    term_normal = false,
                    ["<Esc>"] = { "hide", mode = { "n", "t" } },
                },
            },
        },
    },
}
