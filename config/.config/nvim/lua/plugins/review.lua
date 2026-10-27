return {
    "georgeguimaraes/review.nvim",
    dependencies = {
        "esmuellert/codediff.nvim",
        "MunifTanjim/nui.nvim",
        "folke/sidekick.nvim",
    },
    event = "VeryLazy",
    cmd = "Review",
    opts = function()
        local keys = {}
        for key in pairs(require("review.config").defaults.keymaps) do
            keys[key] = false
        end
        keys.popup_submit = "<C-s>"
        keys.popup_cancel = "<Esc>"
        return {
            codediff = { readonly = false },
            comment_types = { note = { name = "Comment", icon = "C" } },
            export = {
                clear_on_close = false,
                header = "Please address the following review comments.\nLines prefixed with ~ refer to the old (left) side of the diff.",
            },
            keymaps = keys,
        }
    end,
    config = function(_, opts)
        local review = require("review")
        for _, name in ipairs({ "_check_codediff_session", "_on_file_select" }) do
            local original = review[name]
            review[name] = function(...)
                local workflow = require("git-review.workflow")
                local target = workflow.target()
                if target and target.kind == "local" and workflow.valid(target) then
                    original(...)
                end
            end
        end
        review.setup(opts)
        local marks = require("review.marks")
        for _, name in ipairs({ "render_for_buffer", "align_buffers" }) do
            local render = marks[name]
            marks[name] = function(...)
                if require("git-review.workflow").local_annotations() then
                    render(...)
                end
            end
        end
        local popup = require("review.popup")
        popup.open = function(_, text, callback)
            local workflow = require("git-review.workflow")
            local target = workflow.target()
            local previous_win = vim.api.nvim_get_current_win()
            local editor = require("nui.popup")({
                enter = true,
                position = "50%",
                size = { width = 60, height = 10 },
                border = {
                    style = "rounded",
                    text = { top = " Comment (Ctrl+S: save, Esc: cancel) ", top_align = "center" },
                },
                win_options = { wrap = true, linebreak = true },
                buf_options = { filetype = "markdown", modifiable = true, readonly = false },
            })
            local function finish(input)
                editor:unmount()
                if vim.api.nvim_win_is_valid(previous_win) then
                    vim.api.nvim_set_current_win(previous_win)
                end
                vim.cmd.stopinsert()
                if input and not workflow.valid(target) then
                    vim.cmd.new()
                    vim.bo.buftype = "nofile"
                    vim.bo.bufhidden = "hide"
                    vim.bo.filetype = "markdown"
                    vim.wo.wrap = true
                    vim.wo.linebreak = true
                    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(input, "\n"))
                    vim.notify("Review changed; draft retained, not saved", vim.log.levels.ERROR)
                    return
                end
                callback(input and "note" or nil, input)
            end
            editor:mount()
            if text then
                vim.api.nvim_buf_set_lines(editor.bufnr, 0, -1, false, vim.split(text, "\n"))
            end
            vim.keymap.set({ "n", "i" }, "<C-s>", function()
                local input = table.concat(vim.api.nvim_buf_get_lines(editor.bufnr, 0, -1, false), "\n")
                    :gsub("%s+$", "")
                finish(input ~= "" and input or nil)
            end, { buffer = editor.bufnr, desc = "Save comment" })
            vim.keymap.set("n", "<Esc>", function() finish(nil) end,
                { buffer = editor.bufnr, desc = "Cancel comment" })
            vim.cmd.startinsert()
        end
    end,
}
