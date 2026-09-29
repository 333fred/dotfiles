vim.g.mapleader = ","

vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.cursorline = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.smarttab = true
vim.opt.showmatch = true
vim.opt.incsearch = true
vim.opt.hlsearch = true
vim.opt.foldenable = true
vim.opt.foldmethod = "indent"
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99

vim.keymap.set("n", ";", ":")
vim.keymap.set("n", "j", "gj")
vim.keymap.set("n", "k", "gk")
vim.keymap.set("n", "<Esc>", "<Cmd>nohlsearch<CR>")
vim.keymap.set("n", "<Space>", "za")
vim.keymap.set("n", "<leader>e", "<Cmd>Neotree toggle<CR>", { desc = "Toggle file browser" })
vim.keymap.set("n", "<leader>b", function()
    require("neo-tree.command").execute({ source = "buffers", action = "focus", reveal = false })
end, { desc = "Focus open buffers" })
vim.keymap.set("n", "<leader>g", "<Cmd>Neotree git_status toggle<CR>", { desc = "Toggle Git changes" })
vim.keymap.set("n", "<leader>p", "<Cmd>GHOpenPR<CR>", { desc = "Open pull request for review" })
vim.keymap.set("n", "gd", "<Cmd>Telescope lsp_definitions<CR>", { desc = "Go to definition" })
vim.keymap.set("n", "gr", "<Cmd>Telescope lsp_references<CR>", { desc = "Find references" })
vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "Go to implementation" })
vim.keymap.set("n", "<leader>m", "<Cmd>Telescope lsp_document_symbols<CR>", { desc = "Find document symbol" })
vim.keymap.set("n", "<leader>,", "<Cmd>Telescope lsp_dynamic_workspace_symbols<CR>", { desc = "Find workspace symbol" })
vim.keymap.set("n", "<leader>f", "<Cmd>Telescope find_files<CR>", { desc = "Find file" })
vim.keymap.set("n", "<leader>h", "<C-o>", { desc = "Jump back" })
vim.keymap.set("n", "<leader>l", "<C-i>", { desc = "Jump forward" })

vim.api.nvim_create_autocmd("FileType", {
    pattern = "cs",
    callback = function()
        vim.treesitter.start()
    end,
})

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
    { "chriskempson/base16-vim", lazy = false, priority = 1000 },
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "MunifTanjim/nui.nvim",
            "nvim-tree/nvim-web-devicons",
        },
        lazy = false,
        opts = {
            source_selector = {
                winbar = true,
                sources = {
                    { source = "filesystem", display_name = " Files " },
                    { source = "buffers", display_name = " Buffers " },
                    { source = "git_status", display_name = " Git " },
                },
            },
            git_status = {
                window = {
                    mappings = {
                        ["<cr>"] = function(state)
                            local node = state.tree:get_node()
                            if node.type ~= "file" then
                                require("neo-tree.sources.common.commands").open(state)
                                return
                            end

                            local path = vim.fs.relpath(state.path, node.path)
                            if not path then
                                vim.notify("Cannot diff a file outside the Git root: " .. node.path, vim.log.levels.ERROR)
                                return
                            end

                            vim.cmd("DiffviewOpen -C" .. vim.fn.fnameescape(state.path)
                                .. " --untracked-files=all -- " .. vim.fn.fnameescape(path))
                        end,
                    },
                },
            },
        },
    },
    {
        "sindrets/diffview.nvim",
        cmd = "DiffviewOpen",
        dependencies = { "nvim-lua/plenary.nvim" },
        opts = {
            keymaps = {
                view = { ["<leader>b"] = false },
                file_panel = { ["<leader>b"] = false },
                file_history_panel = { ["<leader>b"] = false },
            },
        },
    },
    {
        "ldelossa/gh.nvim",
        cmd = { "GHOpenPR", "GHRequestedReview", "GHSearchPRs", "GHReviewed", "GHStartReview", "GHSubmitReview" },
        dependencies = {
            "nvim-telescope/telescope.nvim",
            {
                "ldelossa/litee.nvim",
                config = function()
                    require("litee.lib").setup()
                end,
            },
        },
        config = function()
            require("litee.gh").setup()
        end,
    },
    {
        "nvim-telescope/telescope.nvim",
        tag = "v0.2.1",
        dependencies = {
            "nvim-lua/plenary.nvim",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
            "nvim-telescope/telescope-ui-select.nvim",
        },
        cmd = "Telescope",
        config = function()
            require("telescope").setup()
            require("telescope").load_extension("fzf")
            require("telescope").load_extension("ui-select")
        end,
    },
    {
        "nvim-treesitter/nvim-treesitter",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter").install({ "c_sharp" })
        end,
    },
    { "HiPhish/rainbow-delimiters.nvim", dependencies = { "nvim-treesitter/nvim-treesitter" } },
    { "seblyng/roslyn.nvim", opts = {} },
    {
        "nvim-lualine/lualine.nvim",
        event = "VeryLazy",
        opts = {
            options = {
                theme = require("ocean-theme").statusline_theme(),
                globalstatus = true,
                component_separators = { left = "|", right = "|" },
                section_separators = { left = "", right = "" },
            },
            sections = {
                lualine_a = { "mode" },
                lualine_b = { "branch" },
                lualine_c = { { "filename", path = 1, symbols = { modified = " [+]", readonly = " [RO]" } } },
                lualine_x = {
                    { "diagnostics", symbols = { error = "E:", warn = "W:", info = "I:", hint = "H:" } },
                    function()
                        local clients = vim.lsp.get_clients({ bufnr = 0 })
                        if #clients == 0 then
                            return ""
                        end
                        return "LSP: " .. table.concat(vim.tbl_map(function(client)
                            return client.name
                        end, clients), ", ")
                    end,
                    "filetype",
                },
                lualine_y = { "progress" },
                lualine_z = { "location" },
            },
        },
    },
})

vim.cmd.colorscheme("base16-ocean")
require("ocean-theme").setup()

local roslyn_root_dir = vim.lsp.config.roslyn.root_dir

local function start_roslyn_folder(root)
    local config = vim.deepcopy(vim.lsp.config.roslyn)
    config.root_dir = root
    config.on_init = nil
    -- The shared daemon keeps its original startup flags, so auto-loading needs its own server.
    config.cmd = vim.tbl_filter(function(arg)
        return arg ~= "--daemon-mode"
    end, config.cmd)
    config.cmd[#config.cmd + 1] = "--autoLoadProjects"
    return vim.lsp.start(config, { attach = false })
end

vim.lsp.config("roslyn", {
    root_dir = function(bufnr, on_dir)
        local file = vim.api.nvim_buf_get_name(bufnr)
        for _, client in ipairs(vim.lsp.get_clients({ name = "roslyn" })) do
            if
                type(client.config.cmd) == "table"
                and vim.tbl_contains(client.config.cmd, "--autoLoadProjects")
                and client.config.root_dir
                and vim.fs.relpath(client.config.root_dir, file)
            then
                on_dir(client.config.root_dir)
                return
            end
        end

        local decision = require("roslyn.target").resolve(bufnr)
        if decision.kind == "ambiguous" then
            local root = vim.fs.dirname(decision.targets[1])
            for _, target in ipairs(decision.targets) do
                while not vim.fs.relpath(root, target) do
                    root = vim.fs.dirname(root)
                end
            end
            if start_roslyn_folder(root) then
                on_dir(root)
            end
            return
        end

        roslyn_root_dir(bufnr, on_dir)
    end,
})

vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        if vim.fn.argc() ~= 1 or vim.fn.isdirectory(vim.fn.argv(0)) ~= 1 then
            return
        end

        local root = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.argv(0), ":p"))
        for name, kind in vim.fs.dir(root) do
            if (kind == "file" or kind == "link") and (name:match("%.slnx?$") or name:match("%.csproj$")) then
                start_roslyn_folder(root)
                return
            end
        end
    end,
})
