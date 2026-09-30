return {
    "seblyng/roslyn.nvim",
    opts = {},
    config = function(_, opts)
        require("roslyn").setup(opts)
        -- Use a dedicated server so each workspace owns its project-loading state.
        vim.lsp.config("roslyn", {
            cmd = vim.tbl_filter(function(arg)
                return arg ~= "--daemon-mode"
            end, vim.lsp.config.roslyn.cmd),
        })
        local roslyn_root_dir = vim.lsp.config.roslyn.root_dir

        local function start_roslyn_folder(root)
            local config = vim.deepcopy(vim.lsp.config.roslyn)
            config.root_dir = root
            local solutions, projects = require("roslyn.sln.discovery").find_target_files(root)
            if #solutions == 0 and #projects > 0 then
                -- Standalone projects need an explicit open request during initialization.
                config.on_init = function(client)
                    require("roslyn.lsp.on_init").project(client, projects)
                end
            else
                config.on_init = nil
                config.cmd[#config.cmd + 1] = "--autoLoadProjects"
            end
            return vim.lsp.start(config, { attach = false })
        end

        vim.api.nvim_create_autocmd("User", {
            pattern = "ReviewCheckout",
            callback = function(event)
                -- A branch checkout can change projects; reload the server and reattach buffers.
                local root = event.data.root
                local has_roslyn = false
                for _, client in ipairs(vim.lsp.get_clients({ name = "roslyn" })) do
                    if client.config.root_dir == root then
                        has_roslyn = true
                        client:stop(true)
                    end
                end
                local buffers = {}
                for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
                    if
                        vim.api.nvim_buf_is_loaded(bufnr)
                        and vim.bo[bufnr].filetype == "cs"
                        and vim.bo[bufnr].buftype == ""
                        and vim.fs.relpath(root, vim.api.nvim_buf_get_name(bufnr))
                    then
                        buffers[#buffers + 1] = bufnr
                    end
                end
                if not has_roslyn and #buffers == 0 then
                    return
                end
                local client_id = start_roslyn_folder(root)
                if not client_id then
                    vim.notify("Failed to restart Roslyn after PR checkout", vim.log.levels.ERROR)
                    return
                end
                for _, bufnr in ipairs(buffers) do
                    vim.lsp.buf_attach_client(bufnr, client_id)
                end
            end,
        })

        vim.lsp.config("roslyn", {
            root_dir = function(bufnr, on_dir)
                local file = vim.api.nvim_buf_get_name(bufnr)
                for _, client in ipairs(vim.lsp.get_clients({ name = "roslyn" })) do
                    if
                        client.config.root_dir
                        and vim.fs.relpath(client.config.root_dir, file)
                    then
                        on_dir(client.config.root_dir)
                        return
                    end
                end

                local decision = require("roslyn.target").resolve(bufnr)
                if decision.kind == "project" then
                    if start_roslyn_folder(decision.root_dir) then
                        on_dir(decision.root_dir)
                    end
                    return
                end
                if decision.kind == "ambiguous" then
                    -- Load from the common folder rather than attach to an empty workspace.
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
                -- Starting with `nvim .` should load projects before any C# buffer is opened.
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
    end,
}
