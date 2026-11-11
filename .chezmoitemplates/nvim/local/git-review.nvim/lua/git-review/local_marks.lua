local M = {}

local function with_comments(filter, action)
    local store = require("review.store")
    local get_for_file = store.get_for_file
    store.get_for_file = function(...)
        return filter(get_for_file(...))
    end
    local ok, err = xpcall(action, debug.traceback)
    store.get_for_file = get_for_file
    if not ok then
        error(err, 0)
    end
end

function M.setup(marks)
    local render = marks.render_for_buffer
    local align = marks.align_buffers
    local namespace = vim.api.nvim_create_namespace("review")

    marks.render_for_buffer = function(buf, side, file)
        if not require("git-review.workflow").local_annotations() then
            return
        end
        local comments
        with_comments(function(items)
            comments = items
            return items
        end, function() render(buf, side, file) end)
        if not comments or not vim.api.nvim_buf_is_valid(buf) then
            return
        end

        local by_line = {}
        local line_count = vim.api.nvim_buf_line_count(buf)
        for _, comment in ipairs(comments) do
            local first = math.max(comment.line - 1, 0)
            local last = comment.line == 0 and 0 or (comment.line_end or comment.line) - 1
            if first < line_count and last >= first and last < line_count then
                by_line[last] = by_line[last] or {}
                table.insert(by_line[last], comment)
            end
        end
        for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })) do
            local details = mark[4]
            local line_comments = by_line[mark[2]]
            if details.virt_lines and line_comments and #line_comments > 0 then
                local comment = table.remove(line_comments, 1)
                if comment.resolved then
                    -- Keep the extmark ID so review.nvim can still track the comment through edits.
                    vim.api.nvim_buf_set_extmark(buf, namespace, mark[2], mark[3], {
                        id = mark[1],
                        sign_text = details.sign_text,
                        sign_hl_group = details.sign_hl_group,
                        line_hl_group = details.line_hl_group,
                        priority = details.priority,
                        right_gravity = details.right_gravity,
                    })
                end
            end
        end
    end

    marks.align_buffers = function(...)
        if not require("git-review.workflow").local_annotations() then
            return
        end
        local args = { ... }
        local count = select("#", ...)
        with_comments(function(items)
            return vim.tbl_filter(function(comment) return not comment.resolved end, items)
        end, function() align(unpack(args, 1, count)) end)
    end
end

return M
