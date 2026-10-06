vim.keymap.set("n", ";", ":")
vim.keymap.set("n", "j", "gj")
vim.keymap.set("n", "k", "gk")
vim.keymap.set("n", "<Esc>", "<Cmd>nohlsearch<CR>")
vim.keymap.set("n", "<Space>", "za")
vim.keymap.set({ "i", "c" }, "<C-BS>", "<C-w>", { desc = "Delete previous word" })
vim.keymap.set("x", "<C-S-c>", '"+y', { desc = "Copy selection" })
-- Older terminals encode Ctrl+Space as Ctrl+@ (NUL).
for _, key in ipairs({ "<C-Space>", "<C-@>" }) do
    vim.keymap.set("i", key, vim.lsp.completion.get, { desc = "Show completions" })
end
vim.keymap.set("i", "<Up>", function()
    return vim.fn.pumvisible() == 1 and "<C-p>" or "<Up>"
end, { expr = true, desc = "Select previous completion or move up" })
vim.keymap.set("i", "<Down>", function()
    return vim.fn.pumvisible() == 1 and "<C-n>" or "<Down>"
end, { expr = true, desc = "Select next completion or move down" })
vim.keymap.set("i", "<CR>", function()
    if vim.fn.pumvisible() == 1 then
        return vim.fn.complete_info({ "selected" }).selected == -1 and "<C-n><C-y>" or "<C-y>"
    end
    return "<CR>"
end, { expr = true, desc = "Accept completion or insert newline" })
vim.keymap.set({ "n", "i", "x" }, "<C-.>", vim.lsp.buf.code_action, { desc = "Show quick fixes and code actions" })
for key, direction in pairs({ h = "left", j = "below", k = "above", l = "right" }) do
    local command = "<Cmd>wincmd " .. key .. "<CR>"
    local opts = { desc = "Focus pane " .. direction }
    vim.keymap.set({ "n", "i" }, "<M-" .. key .. ">", command, opts)
    vim.keymap.set("t", "<M-" .. key .. ">", "<C-\\><C-n>" .. command, opts)
end
vim.keymap.set({ "n", "i", "t" }, "<C-`>", function()
    Snacks.terminal()
end, { desc = "Toggle terminal pane" })
vim.keymap.set("n", "<leader>e", function()
    Snacks.explorer()
end, { desc = "Toggle file browser" })
vim.keymap.set("n", "<leader>b", function()
    Snacks.picker.buffers()
end, { desc = "Find open buffer" })
local lazygit_cwd = vim.fn.getcwd()
if vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1 then
    lazygit_cwd = vim.fn.fnamemodify(vim.fn.argv(0), ":p")
end
vim.keymap.set("n", "<leader>g", function()
    if vim.fn.executable("lazygit") ~= 1 then
        vim.notify("Install lazygit to use the Git interface", vim.log.levels.ERROR)
        return
    end
    Snacks.lazygit({ cwd = lazygit_cwd })
end, { desc = "Toggle Lazygit" })
vim.keymap.set("n", "<leader>p", function()
    Snacks.picker.gh_pr({ limit = 100, live = false })
end, { desc = "Open pull request for review" })
vim.keymap.set("n", "<leader>P", function()
    Snacks.picker.gh_pr({
        search = "(mentions:@me OR assignee:@me OR team-review-requested:dotnet/roslyn-compiler OR user-review-requested:@me)",
        limit = 100,
        live = false,
    })
end, { desc = "Pull requests mentioning, assigned to, or requesting review from you or your team" })
vim.keymap.set("n", "<leader>r", function()
    require("plugins.octo.review").open()
end, { desc = "Review PR with local code" })
vim.keymap.set("n", "gd", function()
    Snacks.picker.lsp_definitions()
end, { desc = "Go to definition" })
vim.keymap.set("n", "gr", function()
    Snacks.picker.lsp_references()
end, { desc = "Find references" })
vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "Go to implementation" })
vim.keymap.set("n", "<leader>m", function()
    Snacks.picker.lsp_symbols({ tree = false })
end, { desc = "Find document symbol" })
vim.keymap.set("n", "<leader>,", function()
    Snacks.picker.lsp_workspace_symbols()
end, { desc = "Find workspace symbol" })
vim.keymap.set("n", "<leader>f", function()
    Snacks.picker.files({
        main = { current = vim.bo.filetype == "octo" and vim.bo.buftype == "acwrite" },
    })
end, { desc = "Find file" })
vim.keymap.set("n", "<leader>h", "<C-o>", { desc = "Jump back" })
vim.keymap.set("n", "<leader>l", "<C-i>", { desc = "Jump forward" })
