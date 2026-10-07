local M = {}
local win

function M.open()
    if win and win:valid() then
        win:focus()
        return
    end
    local config, err = vim.uv.fs_realpath(vim.fn.stdpath("config"))
    if not config then
        vim.notify("Could not locate the Neovim cheat sheet: " .. err, vim.log.levels.ERROR)
        return
    end
    local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(config)))
    local path = vim.fs.joinpath(root, "NEOVIM-CHEATSHEET.md")
    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok then
        vim.notify("Could not read the Neovim cheat sheet: " .. lines, vim.log.levels.ERROR)
        return
    end
    win = Snacks.win({
        text = lines,
        title = "Neovim cheat sheet",
        border = "rounded",
        width = 0.85,
        height = 0.85,
        enter = true,
        bo = {
            buftype = "nofile", bufhidden = "wipe", filetype = "markdown",
            swapfile = false, modified = false, modifiable = false, readonly = true,
        },
        wo = { wrap = true, linebreak = true, foldenable = false },
        keys = { ["<Esc>"] = { "close", mode = { "n", "x" } } },
    })
end

return M
