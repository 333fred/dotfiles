local M = {}

local function is_blank(buf)
    return vim.api.nvim_buf_get_name(buf) == ""
        and vim.bo[buf].buftype == ""
        and not vim.bo[buf].modified
        and vim.api.nvim_buf_line_count(buf) == 1
        and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

local function editor_windows(explorer)
    return vim.tbl_filter(function(win)
        return win ~= explorer.layout.root.win and vim.api.nvim_win_get_config(win).relative == ""
    end, vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(explorer.layout.root.win)))
end

function M.on_explorer_show(explorer)
    vim.schedule(function()
        if explorer.closed or not vim.api.nvim_win_is_valid(explorer.main) then
            return
        end
        local buf = vim.api.nvim_win_get_buf(explorer.main)
        if is_blank(buf) then
            Snacks.dashboard({ buf = buf, win = explorer.main })
        end
    end)
end

function M.setup()
    vim.api.nvim_create_autocmd("WinClosed", {
        group = vim.api.nvim_create_augroup("ExplorerEditorWindow", { clear = true }),
        callback = function(event)
            if not Snacks then
                return
            end
            local win = tonumber(event.match)
            for _, explorer in ipairs(Snacks.picker.get({ source = "explorer" })) do
                local windows = editor_windows(explorer)
                if #windows == 1 and windows[1] == win then
                    local closed_buf = vim.api.nvim_win_get_buf(win)
                    local width = vim.api.nvim_win_get_width(win)
                    local alternate = vim.fn.bufnr("#")
                    local buffers = vim.tbl_filter(function(info)
                        return info.bufnr ~= closed_buf
                            and #vim.fn.win_findbuf(info.bufnr) == 0
                            and not is_blank(info.bufnr)
                    end, vim.fn.getbufinfo({ buflisted = 1 }))
                    table.sort(buffers, function(a, b)
                        if a.lastused ~= b.lastused then
                            return a.lastused > b.lastused
                        end
                        if a.bufnr == alternate or b.bufnr == alternate then
                            return a.bufnr == alternate
                        end
                        return a.bufnr > b.bufnr
                    end)
                    vim.schedule(function()
                        if explorer.closed or not explorer.layout.root:win_valid()
                            or #editor_windows(explorer) > 0 then
                            return
                        end
                        local buf
                        for _, info in ipairs(buffers) do
                            if vim.api.nvim_buf_is_valid(info.bufnr) and vim.bo[info.bufnr].buflisted
                                and #vim.fn.win_findbuf(info.bufnr) == 0 and not is_blank(info.bufnr) then
                                buf = info.bufnr
                                break
                            end
                        end
                        local homepage = buf == nil
                        buf = buf or vim.api.nvim_create_buf(false, true)
                        local main = vim.api.nvim_open_win(buf, true, {
                            split = "right",
                            win = explorer.layout.root.win,
                            width = width,
                        })
                        if homepage then
                            Snacks.dashboard({ buf = buf, win = main })
                        end
                    end)
                end
            end
        end,
    })
end

return M
