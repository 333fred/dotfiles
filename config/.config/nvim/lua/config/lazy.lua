local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
    local output = vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "--branch=stable",
        "https://github.com/folke/lazy.nvim.git",
        lazypath,
    })
    if vim.v.shell_error ~= 0 then
        error("Failed to install lazy.nvim:\n" .. output)
    end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = { { import = "plugins" } },
    performance = {
        rtp = {
            -- Ubuntu's PPA puts vimdoc in an architecture-specific library directory.
            -- Keep that runtime path entry or plugin helptag generation fails.
            reset = false,
        },
    },
})
