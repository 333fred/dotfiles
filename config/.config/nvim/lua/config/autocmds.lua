vim.api.nvim_create_autocmd("BufHidden", {
    group = vim.api.nvim_create_augroup("DiscardEmptyBuffers", { clear = true }),
    callback = function(event)
        -- Navigation can still be changing windows while BufHidden fires.
        vim.schedule(function()
            local buf = event.buf
            if not vim.api.nvim_buf_is_valid(buf)
                or not vim.api.nvim_buf_is_loaded(buf)
                or vim.api.nvim_buf_get_name(buf) ~= ""
                or vim.bo[buf].buftype ~= ""
                or vim.bo[buf].modified
                or #vim.fn.win_findbuf(buf) > 0
                or vim.api.nvim_buf_line_count(buf) ~= 1
                or vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] ~= ""
            then
                return
            end
            vim.api.nvim_buf_delete(buf, {})
        end)
    end,
})

require("ui.editor").setup()
