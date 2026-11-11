-- Run with: nvim --headless -u NONE -l <path-to-this-file>
local plugin = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local review = vim.fn.stdpath("data") .. "/lazy/review.nvim"
package.path = plugin .. "/lua/?.lua;" .. plugin .. "/lua/?/init.lua;"
    .. review .. "/lua/?.lua;" .. review .. "/lua/?/init.lua;" .. package.path

local items = {
    { id = "file", file = "test", line = 0, type = "note", text = "File", resolved = true },
    { id = "range", file = "test", line = 1, line_end = 3, side = "new", type = "note", text = "Range", resolved = true },
    { id = "open", file = "test", line = 3, side = "new", type = "note", text = "Open" },
    { id = "resolved", file = "test", line = 3, side = "new", type = "note", text = "Resolved", resolved = true },
}
local store
store = {
    get_for_file = function(file, side)
        return vim.tbl_filter(function(comment)
            return comment.file == file and (not side or comment.line == 0 or (comment.side or "new") == side)
        end, items)
    end,
    get = function(id)
        for _, comment in ipairs(items) do
            if comment.id == id then return comment end
        end
    end,
    move = function(id, line, line_end)
        local comment = store.get(id)
        comment.line, comment.line_end = line, line_end
    end,
}
package.loaded["review.store"] = store
package.loaded["review.config"] = { get = function()
    return { comment_types = { note = { icon = "C", name = "Comment" } } }
end }
package.loaded["review.utils"] = { normalize_path = function(path) return path end }
package.loaded["git-review.workflow"] = { local_annotations = function() return true end }

local marks = require("review.marks")
require("git-review.local_marks").setup(marks)
local left, right = vim.api.nvim_create_buf(false, true), vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(left, 0, -1, false, { "a", "b", "c", "d" })
vim.api.nvim_buf_set_lines(right, 0, -1, false, { "a", "b", "c", "d" })
local ns = vim.api.nvim_create_namespace("review")
local padding = vim.api.nvim_create_namespace("review_padding")
local function annotations(buf)
    return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
end
local function counts(buf)
    local signs, boxes = 0, 0
    for _, mark in ipairs(annotations(buf)) do
        if mark[4].sign_text then
            assert(mark[4].sign_text:match("^C"))
            signs = signs + 1
        end
        if mark[4].virt_lines then boxes = boxes + 1 end
    end
    return signs, boxes
end

marks.render_for_buffer(right, "new", "test")
local signs, boxes = counts(right)
assert(signs == 4 and boxes == 1, "Resolved file, range, and line comments must retain signs without boxes")
marks.render_for_buffer(left, "old", "test")
marks.align_buffers(left, right, "test", "test")
local pads = vim.api.nvim_buf_get_extmarks(left, padding, 0, -1, { details = true })
assert(#pads == 1 and #pads[1][4].virt_lines == 3, "Only the open comment should add diff padding")

vim.api.nvim_buf_set_lines(right, 0, 0, false, { "inserted" })
assert(marks.sync_positions(right) == 3)
assert(items[2].line == 2 and items[2].line_end == 4 and items[4].line == 4,
    "Resolved comment anchors must continue to track edits")
items[4].resolved = false
marks.render_for_buffer(right, "new", "test")
signs, boxes = counts(right)
assert(signs == 4 and boxes == 2, "Reopening a comment must restore its box")
items[3].resolved = true
marks.render_for_buffer(right, "new", "test")
signs, boxes = counts(right)
assert(signs == 4 and boxes == 1, "Resolving a comment must hide its box immediately")
print("Passed local review annotation scenarios")
