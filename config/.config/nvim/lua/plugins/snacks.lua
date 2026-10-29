local function update_preview_context(win)
    local context = package.loaded["treesitter-context"]
    if not (context and context.enabled() and win and vim.api.nvim_win_is_valid(win)) then
        return
    end
    local buf = vim.api.nvim_win_get_buf(win)
    local highlighter = vim.treesitter.highlighter.active[buf]
    if vim.bo[buf].filetype == "snacks_picker_preview" and highlighter then
        vim.api.nvim_win_call(win, function()
            vim.cmd("noautocmd setlocal filetype=" .. highlighter.tree:lang())
        end)
    end
    if highlighter then
        -- Context calculation needs a completed parse of newly populated previews.
        highlighter.tree:parse()
    end
    vim.api.nvim_exec_autocmds("FileType", {
        group = "treesitter_context_update",
        buffer = buf,
    })
    vim.api.nvim_win_call(win, function()
        vim.api.nvim_exec_autocmds("CursorMoved", { group = "treesitter_context_update" })
    end)
end

return {
    "folke/snacks.nvim",
    priority = 900,
    lazy = false,
    opts = {
        dashboard = { enabled = true },
        picker = {
            enabled = true,
            on_change = function(picker)
                -- Preview buffers suppress FileType events and are not the current window.
                vim.schedule(function()
                    local win = picker.preview and picker.preview.win.win
                    update_preview_context(win)
                end)
            end,
            actions = {
                preview_scroll_up = function(picker)
                    Snacks.picker.actions.preview_scroll_up(picker)
                    update_preview_context(picker.preview.win.win)
                end,
                preview_scroll_down = function(picker)
                    Snacks.picker.actions.preview_scroll_down(picker)
                    update_preview_context(picker.preview.win.win)
                end,
            },
            win = {
                -- Leave room above the cursor for context while paging the preview.
                preview = { wo = { scrolloff = 3 } },
            },
            matcher = {
                smartcase = false,
                ignorecase = true,
            },
            sources = {
                explorer = {
                    hidden = true,
                    ignored = true,
                    on_show = function(picker)
                        require("ui.editor").on_explorer_show(picker)
                    end,
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
                        return require("git-review.picker").finder(opts, ctx)
                    end,
                    show_delay = 0,
                    confirm = function(picker, item)
                        if not item then
                            return
                        end
                        picker:close()
                        require("git-review").select_pr(item.url)
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
