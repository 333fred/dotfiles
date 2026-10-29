local function is_bufferline_buffer(buf)
    return vim.bo[buf].buflisted
        and (vim.bo[buf].buftype == "" or vim.b[buf].git_review_pr_url ~= nil)
end

vim.api.nvim_create_user_command("QuitBuffer", function(opts)
    local buf = vim.api.nvim_get_current_buf()
    if not opts.bang and is_bufferline_buffer(buf) and vim.bo[buf].modified
        and #vim.fn.win_findbuf(buf) == 1
    then
        local choice = vim.fn.confirm(
            ("Save changes to %q?"):format(vim.api.nvim_buf_get_name(buf)),
            "&Save\n&Discard\n&Cancel",
            3
        )
        if choice == 1 then
            vim.cmd.update()
        elseif choice == 2 then
            vim.cmd.quit({ bang = true })
            return
        else
            return
        end
    end
    vim.cmd.quit({ bang = opts.bang })
end, { bang = true })

for _, command in ipairs({ "q", "quit" }) do
    vim.cmd(("cnoreabbrev <expr> %s getcmdtype() == ':' && getcmdline() == '%s' ? 'QuitBuffer' : '%s'")
        :format(command, command, command))
end

vim.api.nvim_create_autocmd("QuitPre", {
    group = vim.api.nvim_create_augroup("CloseQuitBuffer", { clear = true }),
    callback = function()
        local win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_win_get_buf(win)
        if not is_bufferline_buffer(buf) then
            return
        end
        vim.schedule(function()
            if vim.api.nvim_win_is_valid(win)
                or not vim.api.nvim_buf_is_valid(buf)
                or not vim.bo[buf].buflisted
                or #vim.fn.win_findbuf(buf) > 0
            then
                return
            end
            if vim.bo[buf].modified then
                vim.notify("Kept modified buffer open: " .. vim.api.nvim_buf_get_name(buf), vim.log.levels.WARN)
                return
            end
            vim.cmd.bdelete({ args = { tostring(buf) } })
        end)
    end,
})

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
