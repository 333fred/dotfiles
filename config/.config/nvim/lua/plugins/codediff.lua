return {
    "esmuellert/codediff.nvim",
    dependencies = { "git-review.nvim" },
    cmd = "CodeDiff",
    keys = {
        { "<localleader>dh", "<Cmd>CodeDiff history<CR>", desc = "Git history for current branch" },
        { "<localleader>df", "<Cmd>CodeDiff file HEAD<CR>", desc = "Diff current file against HEAD" },
    },
    opts = {
        highlights = {
            line_insert = "DiffAdd",
            line_delete = "DiffDelete",
            char_insert = "#43563f",
            char_delete = "#604047",
        },
        explorer = { view_mode = "tree", width = 40 },
        keymaps = {
            view = {
                next_hunk = "<localleader>j",
                prev_hunk = "<localleader>k",
                next_file = "<localleader>J",
                prev_file = "<localleader>K",
                toggle_explorer = "<localleader>dE",
                focus_explorer = "<localleader>de",
                stage_hunk = "<localleader>hs",
                unstage_hunk = "<localleader>hu",
                discard_hunk = "<localleader>hr",
            },
            conflict = {
                accept_incoming = "<localleader>xt",
                accept_current = "<localleader>xo",
                accept_both = "<localleader>xb",
                discard = "<localleader>xx",
                accept_all_incoming = "<localleader>xT",
                accept_all_current = "<localleader>xO",
                accept_all_both = "<localleader>xB",
                discard_all = "<localleader>xX",
            },
        },
    },
    config = function(_, opts)
        require("git-review.content").setup()
        require("codediff").setup(opts)
        local group = vim.api.nvim_create_augroup("CodeDiffWrap", { clear = true })
        local function wrap_diff(tab)
            vim.schedule(function()
                if not tab or not vim.api.nvim_tabpage_is_valid(tab) then
                    return
                end
                local original, modified = require("codediff.ui.lifecycle").get_windows(tab)
                for _, win in pairs({ original, modified }) do
                    if vim.api.nvim_win_is_valid(win) then
                        if not vim.wo[win].wrap then
                            vim.wo[win].wrap = true
                        end
                        vim.wo[win].linebreak = true
                    end
                end
            end)
        end
        vim.api.nvim_create_autocmd("User", {
            group = group,
            pattern = { "CodeDiffOpen", "CodeDiffFileSelect" },
            callback = function(event)
                wrap_diff(event.data.tabpage)
            end,
        })
        vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter", "WinEnter", "FileType" }, {
            group = group,
            callback = function()
                wrap_diff(vim.api.nvim_get_current_tabpage())
            end,
        })
        -- CodeDiff also resets wrap during asynchronous renders and pane focus.
        vim.api.nvim_create_autocmd("OptionSet", {
            group = group,
            pattern = "wrap",
            callback = function()
                if vim.v.option_new == false then
                    wrap_diff(vim.api.nvim_get_current_tabpage())
                end
            end,
        })
    end,
}
