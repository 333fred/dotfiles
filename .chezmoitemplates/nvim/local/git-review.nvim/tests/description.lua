-- Run with: nvim --headless -u NONE -l <path-to-this-file>
local plugin = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = plugin .. "/lua/?.lua;" .. plugin .. "/lua/?/init.lua;" .. package.path

package.loaded["codediff.ui.lifecycle"] = { get_session = function() end }
package.loaded["git-review.workflow"] = { set_target = function() end }
local description = require("git-review.description")
local pr = {
    url = "https://github.com/example/repo/pull/1", number = 1, title = "Test",
    state = "OPEN", headRefName = "feature", baseRefName = "main",
    additions = 3, deletions = 5, changedFiles = 2,
    files = {
        { path = "src/first.lua", additions = 3, deletions = 1 },
        { path = "old file.lua", additions = 0, deletions = 4 },
    },
    statusCheckRollup = { { __typename = "CheckRun", name = "build", status = "COMPLETED", conclusion = "SUCCESS" } },
}

description.open(pr, vim.fn.getcwd())
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
local changes, checks
for i, line in ipairs(lines) do
    if line:find("Changes:", 1, true) then changes = i end
    if line:find("### Checks:", 1, true) then checks = i end
end
assert(lines[changes + 1] == "- src/first.lua  +3 / -1")
assert(lines[changes + 2] == "- old file.lua  +0 / -4")
assert(vim.fn.foldclosed(changes) == changes and vim.fn.foldclosed(checks) == checks)
vim.api.nvim_win_set_cursor(0, { changes, 0 })
vim.api.nvim_feedkeys(" ", "xt", false)
assert(vim.fn.foldclosed(changes) == -1 and vim.fn.foldclosed(checks) == checks)
vim.api.nvim_feedkeys(" ", "xt", false)
assert(vim.fn.foldclosed(changes) == changes)
vim.api.nvim_win_set_cursor(0, { checks, 0 })
vim.api.nvim_feedkeys(" ", "xt", false)
assert(vim.fn.foldclosed(checks) == -1 and vim.fn.foldclosed(changes) == changes)

local marks = vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces()["git-review.summary"], 0, -1,
    { details = true })
local count = 0
for _, mark in ipairs(marks) do
    if mark[2] == changes and (mark[4].hl_group == "GitSignsAdd" or mark[4].hl_group == "GitSignsDelete") then
        count = count + 1
    end
end
assert(count == 2, "Per-file additions and deletions should be highlighted")

pr.files = {}
description.open(pr, vim.fn.getcwd())
lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(table.concat(lines, "\n"):find("Only 0 of 2 returned", 1, true))
pr.files = nil
description.open(pr, vim.fn.getcwd())
lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(table.concat(lines, "\n"):find("Files: ? Unavailable", 1, true))
