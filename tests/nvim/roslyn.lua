-- Run with: nvim --headless -u NONE -l tests/nvim/roslyn.lua
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
local config = root .. "/.chezmoitemplates/nvim"
local lazy = vim.fn.stdpath("data") .. "/lazy"
vim.opt.rtp:prepend(config)
vim.opt.rtp:append(lazy .. "/roslyn.nvim")
vim.opt.rtp:append(lazy .. "/snacks.nvim")

local uri = "roslyn-source-generated://project/Generated%20Syntax.cs?documentId=document&hintName=Generated%20Syntax.cs"
local content = "\r\n// Generated\r\n\r\nclass GeneratedSyntax {}\r\n\r\n"
local requests = 0
local client = {
    id = 42,
    request_sync = function(_, method, params, _, bufnr)
        assert(method == "workspace/textDocumentContent")
        assert(params.uri == uri)
        assert(vim.api.nvim_buf_get_name(bufnr) == uri)
        requests = requests + 1
        return { result = { text = content } }
    end,
}
local attached
local get_clients = vim.lsp.get_clients
vim.lsp.get_clients = function() return { client } end
vim.lsp.buf_attach_client = function(bufnr, id)
    assert(id == client.id)
    attached = bufnr
    return true
end
vim.lsp.enable = function() end
package.loaded["roslyn.commands"] = { create_roslyn_commands = function() end }
dofile(lazy .. "/roslyn.nvim/plugin/roslyn.lua")
require("config.roslyn").setup()

local position = { line = 3, character = 6 }
local range = { start = position, ["end"] = { line = 3, character = 21 } }
for _, location in ipairs({
    { uri = uri, range = range },
    { targetUri = uri, targetRange = range, targetSelectionRange = range },
}) do
    local loc = vim.lsp.util.locations_to_items({ location }, "utf-16")[1]
    assert(loc.lnum == 4 and loc.col == 7 and loc.text == "class GeneratedSyntax {}",
        "Location and LocationLink results must preserve generated line and column offsets")
end
local buf = vim.uri_to_bufnr(uri)
assert(requests == 1 and attached == buf)
assert(vim.bo[buf].buftype == "nofile" and vim.bo[buf].readonly and not vim.bo[buf].modifiable)
assert(not vim.bo[buf].modified and not vim.bo[buf].swapfile and vim.bo[buf].filetype == "cs")
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false),
    { "", "// Generated", "", "class GeneratedSyntax {}", "" }))

local snacks = require("plugins.snacks")
local item = { file = uri, pos = { 4, 6 } }
snacks.opts.picker.transform(item)
assert(item.buf == buf, "Generated picker results must reference their virtual buffer")
local preview_buf
require("snacks.picker.preview").file({
    item = item,
    preview = {
        set_title = function() end,
        set_buf = function(_, target) preview_buf = target end,
        loc = function() end,
        notify = function(_, message) error(message) end,
    },
})
assert(preview_buf == buf, "Picker preview must display generated content, not read a filesystem path")
vim.lsp.get_clients = get_clients
_G.Snacks = require("snacks")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "GeneratedSyntax" })
require("snacks.picker.actions").jump({
    selected = function() return { item } end,
    main = vim.api.nvim_get_current_win(),
    opts = { jump = { jumplist = true, tagstack = true } },
}, item, {})
assert(vim.api.nvim_get_current_buf() == buf)
assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 4, 6 }))
vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "GeneratedSyntax" })
vim.lsp.util.show_document({ uri = uri, range = range }, "utf-16", { focus = true })
assert(vim.api.nvim_get_current_buf() == buf)
assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 4, 6 }))

for _, text in ipairs({ "", "\n", "\n\n", "class LastLine {}", "class LastLine {}\n" }) do
    content = text
    require("roslyn.utils").populate_virtual_buffer_content(client, uri, buf)
    local actual = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    if vim.bo[buf].endofline then
        actual = actual .. "\n"
    end
    assert(actual == text, "Refreshing generated documents must preserve whitespace and final newlines")
    assert(vim.bo[buf].readonly and not vim.bo[buf].modifiable and not vim.bo[buf].modified)
end
local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
for _, request in ipairs({
    function() return nil, "timeout" end,
    function() return { err = { message = "Document unavailable" } } end,
    function() return { result = vim.NIL } end,
}) do
    assert(not pcall(require("roslyn.utils").populate_virtual_buffer_content,
        { request_sync = request }, uri, buf), "Failed content requests must surface errors")
    assert(vim.deep_equal(before, vim.api.nvim_buf_get_lines(buf, 0, -1, false)))
end
local regular = { file = "/tmp/Regular.cs" }
snacks.opts.picker.transform(regular)
assert(regular.buf == nil, "Ordinary picker items must remain unchanged")
print("Passed Roslyn generated document navigation scenarios")
