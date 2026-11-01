local M = {}

local function save()
    local path = assert(require("review.storage").get_storage_path(), "No local review storage path")
    local data = require("review.store").get_all_by_file()
    assert(vim.fn.writefile({ vim.json.encode(data) }, path) == 0, "Could not save local review status")
end

function M.status(comment)
    if comment.resolved then
        return "Resolved"
    end
    return comment.submitted_text == comment.text and "Submitted" or "Pending"
end

function M.pending()
    return vim.tbl_filter(function(comment)
        return M.status(comment) == "Pending"
    end, require("review.store").get_all())
end

function M.resolve(comment, resolved)
    comment.resolved = resolved
    if not resolved then
        comment.submitted_text = nil
    end
    save()
end

function M.mark_submitted(comments)
    for _, comment in ipairs(comments) do
        comment.submitted_text = comment.text
    end
    save()
end

function M.markdown(comments)
    local lines = { require("review.config").get().export.header, "" }
    for i, comment in ipairs(comments) do
        local location = comment.file
        if comment.line ~= 0 then
            local prefix = comment.side == "old" and "~" or ""
            location = location .. ":" .. prefix .. comment.line
            if comment.line_end and comment.line_end ~= comment.line then
                location = location .. "-" .. prefix .. comment.line_end
            end
        end
        lines[#lines + 1] = ("%d. `%s` - %s"):format(i, location, comment.text)
    end
    return table.concat(lines, "\n")
end

return M
