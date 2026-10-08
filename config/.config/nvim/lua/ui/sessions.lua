local M = {}
local operation

local function notify(message, level)
    vim.notify(message, level or vim.log.levels.WARN, { title = "Sessions" })
end

local function saved_session(persistence)
    local file = persistence.current()
    if vim.fn.filereadable(file) == 1 then
        return file
    end
    file = persistence.current({ branch = false })
    if vim.fn.filereadable(file) == 1 then
        return file
    end
end

local function clean_directory_state()
    local seen = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        vim.api.nvim_win_call(win, function()
            local id = vim.fn.arglistid()
            if seen[id] then
                return
            end
            seen[id] = true
            for index = vim.fn.argc(), 1, -1 do
                if vim.fn.isdirectory(vim.fn.argv(index - 1)) == 1 then
                    vim.cmd.argdelete({ range = { index } })
                end
            end
        end)
    end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].buftype == "" and not vim.bo[buf].modified
            and vim.fn.isdirectory(vim.api.nvim_buf_get_name(buf)) == 1
            and #vim.fn.win_findbuf(buf) == 0 then
            vim.api.nvim_buf_delete(buf, {})
        end
    end
end

function M.setup()
    vim.api.nvim_create_autocmd("User", {
        group = vim.api.nvim_create_augroup("WorkspaceSessions", { clear = true }),
        pattern = { "PersistenceSavePre", "PersistenceLoadPost" },
        callback = clean_directory_state,
    })
end

local function buffers_unchanged(approved)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].modified and approved[buf] ~= vim.api.nvim_buf_get_changedtick(buf) then
            notify("Buffers changed while confirming; retry clearing the session")
            return false
        end
    end
    return true
end

local function prepare_buffers()
    local approved, saves = {}, {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then
            local name = vim.api.nvim_buf_get_name(buf)
            local choice = vim.fn.confirm("Save changes to " .. (name ~= "" and name or "[No Name]") .. "?",
                "&Save\n&Discard\n&Cancel", 3)
            if choice == 1 then
                local path
                if name == "" or vim.bo[buf].buftype ~= "" then
                    path = vim.fn.input("Save buffer as: ", "", "file")
                    if path == "" then
                        return
                    end
                end
                saves[#saves + 1] = { buf = buf, path = path }
            elseif choice ~= 2 then
                return
            end
            approved[buf] = vim.api.nvim_buf_get_changedtick(buf)
        end
    end
    if buffers_unchanged(approved) then
        return approved, saves
    end
end

local function save_buffers(saves)
    for _, save in ipairs(saves) do
        if vim.api.nvim_buf_is_valid(save.buf) then
            local ok, err = pcall(vim.api.nvim_buf_call, save.buf, function()
                vim.cmd("write" .. (save.path and " " .. vim.fn.fnameescape(save.path) or ""))
            end)
            if not ok then
                notify("Could not save buffer: " .. err, vim.log.levels.ERROR)
                return false
            end
            if vim.bo[save.buf].modified then
                notify("Buffer is still modified; save it before clearing the session")
                return false
            end
        end
    end
    return true
end

local function close_pickers(callback)
    local pickers = Snacks.picker.get({ tab = false })
    local tasks = {}
    for _, picker in ipairs(pickers) do
        for _, task in ipairs({ picker.finder.task, picker.matcher.task }) do
            if task:running() then
                tasks[#tasks + 1] = task
            end
        end
    end
    if #tasks == 0 then
        for _, picker in ipairs(pickers) do
            picker:close()
        end
        vim.schedule(callback)
        return
    end
    -- Let aborted finders finish before Snacks disposes their matcher and windows.
    local remaining = #tasks
    for _, task in ipairs(tasks) do
        task:on("done", function()
            remaining = remaining - 1
            if remaining == 0 then
                vim.schedule(function() close_pickers(callback) end)
            end
        end)
    end
    for _, task in ipairs(tasks) do
        task:abort()
    end
end

local function remove_blank_windows()
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        local windows = vim.tbl_filter(function(win)
            return vim.api.nvim_win_get_config(win).relative == ""
        end, vim.api.nvim_tabpage_list_wins(tab))
        local remaining = #windows
        for _, win in ipairs(windows) do
            local buf = vim.api.nvim_win_get_buf(win)
            if remaining > 1 and vim.api.nvim_buf_get_name(buf) == "" and vim.bo[buf].buftype == ""
                and not vim.bo[buf].modified and vim.api.nvim_buf_line_count(buf) == 1
                and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "" then
                vim.api.nvim_win_close(win, false)
                remaining = remaining - 1
                if vim.api.nvim_buf_is_valid(buf) and #vim.fn.win_findbuf(buf) == 0 then
                    vim.api.nvim_buf_delete(buf, {})
                end
            end
        end
    end
end

function M.reload()
    local persistence = require("persistence")
    local file = saved_session(persistence)
    if not file then
        notify("No saved session for this directory")
        return
    end
    if operation then
        notify("Session " .. operation .. " is already in progress")
        return
    end
    local current = persistence.current()
    local explorer = #Snacks.picker.get({ source = "explorer" }) > 0
    operation = "reload"
    close_pickers(function()
        operation = nil
        if persistence.current() ~= current then
            notify("Directory or branch changed while closing pickers; retry reloading the session")
            return
        end
        persistence.load()
        -- Older sessions saved explorer sidebars as empty editing windows.
        remove_blank_windows()
        if explorer then
            Snacks.explorer({ cwd = vim.fn.getcwd(), focus = false })
        end
    end)
end

local function clear_editor(persistence, cwd, file)
    local active = persistence.active()
    persistence.stop()
    if file then
        local ok, err = vim.uv.fs_unlink(file)
        if not ok then
            if active then
                persistence.start()
            end
            notify("Could not delete saved session: " .. err, vim.log.levels.ERROR)
            return
        end
    end
    local lifecycle = package.loaded["codediff.ui.lifecycle"]
    if lifecycle then
        lifecycle.cleanup_all()
    end
    vim.cmd.tabnew()
    local blank = vim.api.nvim_get_current_buf()
    vim.cmd.tabonly({ bang = true })
    vim.cmd.only({ bang = true })
    vim.cmd.cd(cwd)
    vim.cmd.argglobal()
    if vim.fn.argc() > 0 then
        vim.cmd("%argdelete")
    end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if buf ~= blank then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end
    for name, option in pairs(vim.api.nvim_get_all_options_info()) do
        if option.scope == "win" then
            vim.wo[name] = vim.api.nvim_get_option_value(name, { scope = "global" })
        end
    end
    persistence.fire("ClearPost")
    if active then
        persistence.start()
    end
    Snacks.explorer({ cwd = cwd })
end

function M.clear()
    if operation then
        notify("Session " .. operation .. " is already in progress")
        return
    end
    local persistence = require("persistence")
    local cwd, current = vim.fn.getcwd(), persistence.current()
    local file = saved_session(persistence)
    local approved, saves = prepare_buffers()
    if not approved then
        return
    end
    operation = "clear"
    close_pickers(function()
        operation = nil
        if vim.fn.getcwd() ~= cwd or persistence.current() ~= current then
            notify("Directory or branch changed while confirming; retry clearing the session")
            return
        end
        if buffers_unchanged(approved) and save_buffers(saves) and buffers_unchanged(approved) then
            clear_editor(persistence, cwd, file)
        end
    end)
end

return M
