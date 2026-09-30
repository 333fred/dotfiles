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
                        -- Escape should leave the sidebar open, not use the picker's close action.
                        cancel = function()
                            vim.cmd.stopinsert()
                            vim.cmd.nohlsearch()
                        end,
                        toggle_terminal = function()
                            Snacks.terminal()
                        end,
                    },
                    win = {
                        input = {
                            keys = {
                                ["<C-`>"] = { "toggle_terminal", mode = { "n", "i" } },
                            },
                        },
                        list = {
                            keys = {
                                ["<C-`>"] = "toggle_terminal",
                            },
                        },
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
        terminal = { enabled = true },
        lazygit = {
            enabled = true,
            config = {
                -- Let Lazygit dismiss inner dialogs before exiting at the top level.
                quitOnTopLevelReturn = true,
            },
            theme = {
                inactiveBorderColor = { fg = "StatusLineNC" },
                inactiveViewSelectedLineBgColor = { bg = "NormalFloat" },
            },
            win = {
                keys = {
                    term_normal = false,
                    ["<Esc>"] = {
                        function(self)
                            vim.api.nvim_chan_send(vim.bo[self.buf].channel, "\27")
                            vim.cmd.startinsert()
                        end,
                        mode = "n",
                    },
                },
            },
        },
    },
}
