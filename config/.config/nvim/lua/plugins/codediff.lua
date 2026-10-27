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
        local group = vim.api.nvim_create_augroup("CodeDiffMarkdownWrap", { clear = true })
        vim.api.nvim_create_autocmd("User", {
            group = group,
            pattern = { "CodeDiffOpen", "CodeDiffFileSelect" },
            callback = function(event)
                local tab = event.data.tabpage
                vim.schedule(function()
                    if not tab or not vim.api.nvim_tabpage_is_valid(tab) then
                        return
                    end
                    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
                        local buf = vim.api.nvim_win_get_buf(win)
                        if vim.bo[buf].filetype == "markdown" then
                            vim.wo[win].wrap = true
                            vim.wo[win].linebreak = true
                        end
                    end
                end)
            end,
        })
    end,
}
