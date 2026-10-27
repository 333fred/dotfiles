local M = {}
local targets = {}
local readonly_buffers = {}
local store_root
local annotations_visible = true

local function notify(message)
    vim.notify(message, vim.log.levels.WARN, { title = "Review" })
end

local function checkout()
    local result = vim.system({
        "git", "rev-parse", "--show-toplevel", "--abbrev-ref", "HEAD",
    }, { text = true }):wait()
    if result.code ~= 0 then
        return nil
    end
    local lines = vim.split(vim.trim(result.stdout), "\n", { plain = true })
    return { root = vim.uv.fs_realpath(lines[1]) or lines[1], branch = lines[2] }
end

function M.target(tab)
    return targets[tab or vim.api.nvim_get_current_tabpage()]
end

function M.status()
    local target = M.target()
    if not target then
        return ""
    end
    if target.kind == "pr" then
        local repo, number = target.url:match("/([^/]+/[^/]+)/pull/(%d+)$")
        return "PR " .. repo .. "#" .. number
    end
    return "Local -> Copilot"
end

function M.set_target(kind, root, url, tab)
    local state = checkout()
    if not state or (vim.uv.fs_realpath(root) or root) ~= state.root then
        notify("Open this review's repository first")
        return
    end
    targets[tab or vim.api.nvim_get_current_tabpage()] = {
        kind = kind, root = state.root, branch = state.branch, url = url,
    }
    if package.loaded["review.marks"] then
        require("review.marks").clear_all()
    end
    vim.cmd.redrawstatus()
end

function M.valid(target)
    local current = M.target()
    local state = checkout()
    return target and current and vim.deep_equal(target, current) and state
        and target.root == state.root and target.branch == state.branch
end

local function checked_target()
    local target = M.target()
    if not target then
        notify("Open a review first: \\rp for GitHub or \\rl/\\rb/\\rc for Copilot")
        return nil
    end
    if not M.valid(target) then
        notify("Repository or branch changed; reopen the review before acting")
        return nil
    end
    local name = vim.api.nvim_buf_get_name(0)
    if vim.bo.buftype == "" and name ~= "" and not vim.fs.relpath(target.root, name) then
        notify("This file is outside the review's repository")
        return nil
    end
    return target
end

local function load_local(target)
    if store_root ~= target.root then
        require("review.marks").clear_all()
        require("review.store").reset()
        require("review.reviewed").reset()
        store_root = target.root
    end
    require("review.store").load()
end

local function prepare_local(target)
    require("lazy").load({ plugins = { "review.nvim" } })
    load_local(target)
    local tab = vim.api.nvim_get_current_tabpage()
    if target.kind == "local" and M.target() and M.target().kind == "local"
        and require("codediff.ui.lifecycle").get_session(tab) then
        require("review.hooks").on_file_changed(tab)
    end
end

function M.local_annotations()
    local target = M.target()
    return annotations_visible and target and target.kind == "local" and M.valid(target)
end

function M.open_local(action)
    local state = checkout()
    if not state then
        notify("Open a Git checkout first")
        return
    end
    prepare_local({ kind = "local", root = state.root, branch = state.branch })
    if action == "open" then
        vim.cmd({ cmd = "CodeDiff", args = { "--repo", state.root } })
    else
        require("review")[action]()
    end
end

local function confirm(prompt, target, action)
    local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    vim.ui.select({ "Confirm", "Cancel" }, { prompt = prompt }, function(choice)
        if choice ~= "Confirm" then
            return
        end
        if not M.valid(target) or vim.api.nvim_get_current_win() ~= win
            or vim.api.nvim_get_current_buf() ~= buf then
            notify("Review or active pane changed; retry the action")
            return
        end
        action()
    end)
end

local function submit_local(target)
    local feedback = require("git-review.feedback")
    local function pending()
        local comments = feedback.pending()
        if #comments == 0 then
            notify("No new or edited unresolved comments to send")
            return
        end
        for _, comment in ipairs(comments) do
            if comment.branch and comment.branch ~= target.branch then
                notify("Pending comments include another branch; inspect \\cl before sending")
                return
            end
        end
        return comments
    end
    if not pending() then
        return
    end
    local win = vim.api.nvim_get_current_win()
    require("sidekick.cli.state").with(function(state)
        if not vim.api.nvim_win_is_valid(win) then
            notify("Review window closed; feedback was not sent")
            return
        end
        vim.api.nvim_win_call(win, function()
            if not M.valid(target) then
                notify("Review changed; feedback was not sent")
                return
            end
            load_local(target)
            local comments = pending()
            if not comments then
                return
            end
            if not state.session or not state.session:is_running() then
                notify("Copilot session is not running; feedback was not sent")
                return
            end
            local text = vim.tbl_map(function(line) return { { line } } end,
                vim.split(feedback.markdown(comments), "\n", { plain = true }))
            state.session:send(state.tool:format(text) .. "\n")
            state.session:submit()
            feedback.mark_submitted(comments)
            vim.notify(("Queued %d review comment(s) for Copilot; comments retained")
                :format(#comments), vim.log.levels.INFO, { title = "Review" })
        end)
    end, { attach = true, filter = { name = "copilot" }, focus = true, show = true })
end

function M.review(action)
    local target = checked_target()
    if not target then
        return
    end
    local commands = {
        start = "GHLitePRStartReview", submit = "GHLitePRSubmitReview",
        approve = "GHLitePRApprove", discard = "GHLitePRDiscardReview",
    }
    local function run()
        if target.kind == "pr" then
            require("git-review").review_command(commands[action])
            return
        end
        prepare_local(target)
        if action == "approve" then
            notify("Approval is a GitHub PR action; this review targets Copilot")
        elseif action == "discard" then
            require("review").clear()
        elseif action == "start" then
            vim.notify("Local feedback round ready; existing comments retained", vim.log.levels.INFO, { title = "Review" })
        elseif action == "submit" then
            submit_local(target)
        end
    end
    if action == "discard" then
        confirm("Discard pending " .. M.status() .. " feedback?", target, run)
    else
        run()
    end
end

local function change_local_comment(action, target, comment, buf, after)
    local function change()
        if not M.valid(target) then
            notify("Review changed; comment was not updated")
            return
        end
        local store = require("review.store")
        local current = store.get(comment.id)
        if not current then
            notify("Comment changed or was already deleted")
            return
        end
        if action == "delete" then
            if not store.delete(comment.id) then
                notify("Comment could not be deleted")
                return
            end
        else
            require("git-review.feedback").resolve(current, action == "resolve")
        end
        require("review.marks").refresh()
        require("review.marks").render_plain_buffer(buf)
        if after then
            after()
        end
    end
    if action == "delete" then
        confirm("Delete this local comment?", target, change)
    else
        change()
    end
end

local function open_local_comment(comment, target)
    local source_buf = vim.api.nvim_get_current_buf()
    local lines = {
        ("%s:%s [%s]"):format(comment.file, comment.line, require("git-review.feedback").status(comment)),
        "\\cr resolve | \\cR reopen | \\cd delete | Esc close",
        "",
    }
    vim.list_extend(lines, vim.split(comment.text, "\n", { plain = true }))
    local buf, win = vim.lsp.util.open_floating_preview(lines, "markdown", {
        border = "rounded", focusable = true, wrap = true,
    })
    vim.api.nvim_set_current_win(win)
    vim.wo[win].wrap = true
    vim.wo[win].linebreak = true
    local function close()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end
    vim.keymap.set("n", "<Esc>", close, { buffer = buf })
    for key, action in pairs({ cr = "resolve", cR = "unresolve", cd = "delete" }) do
        vim.keymap.set("n", "<localleader>" .. key, function()
            change_local_comment(action, target, comment, source_buf, close)
        end, { buffer = buf, desc = action .. " comment" })
    end
end

function M.comment(action)
    local target = checked_target()
    if not target then
        return
    end
    if target.kind == "pr" then
        if action == "file" then
            notify("File-level PR comments are not supported by GHLite; select a line with \\ca")
        elseif action == "delete" then
            confirm("Delete your PR comment?", target, function()
                require("git-review").comment_action(action)
            end)
        else
            require("git-review").comment_action(action)
        end
        return
    end
    prepare_local(target)
    local comments = require("review.comments")
    if action == "add" then
        if vim.fn.mode():match("[vV\22]") then
            local first, last = vim.fn.line("v"), vim.fn.line(".")
            vim.cmd.normal({ vim.keycode("<Esc>"), bang = true })
            comments.add_for_range(nil, first, last)
        else
            comments.add_at_cursor()
        end
    elseif action == "file" then
        comments.file_comment()
    elseif action == "edit" then
        comments.edit_at_cursor()
    elseif action == "delete" or action == "resolve" or action == "unresolve" then
        local file, line, side = require("review.hooks").get_cursor_position()
        local store = require("review.store")
        local comment = file and (store.get_at_line(file, line, side)
            or (line == 1 and store.get_file_comment(file)))
        if not comment then
            notify("No comment at cursor")
            return
        end
        change_local_comment(action, target, comment, vim.api.nvim_get_current_buf())
    elseif action == "list" then
        local items = require("review.store").get_all()
        if #items == 0 then
            notify("No local comments")
            return
        end
        vim.ui.select(items, {
            prompt = "Local comments:",
            format_item = function(comment)
                return ("%s:%s [%s] %s"):format(comment.file, comment.line,
                    require("git-review.feedback").status(comment), comment.text:gsub("\n", " "))
            end,
        }, function(comment)
            if comment then
                if not M.valid(target) then
                    notify("Review changed; reopen the comment list")
                    return
                end
                open_local_comment(comment, target)
            end
        end)
    elseif action == "next" or action == "prev" then
        comments["goto_" .. action]()
    elseif action == "yank" then
        local feedback = require("git-review.feedback")
        local pending = feedback.pending()
        if #pending == 0 then
            notify("No new or edited unresolved comments to copy")
            return
        end
        vim.fn.setreg("+", feedback.markdown(pending))
    elseif action == "toggle" then
        annotations_visible = not annotations_visible
        require("review.marks").clear_all()
        if annotations_visible then
            require("review.marks").refresh()
            require("review.marks").render_plain_buffer()
        end
    elseif action == "open" then
        local file, line, side = require("review.hooks").get_cursor_position()
        local store = require("review.store")
        local comment = file and (store.get_at_line(file, line, side) or store.get_file_comment(file))
        if not comment then
            notify("No comment at cursor")
            return
        end
        open_local_comment(comment, target)
    end
end

function M.mark_reviewed()
    local target = checked_target()
    if not target then
        return
    end
    prepare_local(target)
    local tab = vim.api.nvim_get_current_tabpage()
    local explorer = require("review.hooks").get_explorer(tab)
    if not explorer then
        notify("Open a changed-files explorer to mark files reviewed")
        return
    end
    require("review.reviewed").attach(tab)
    require("review.reviewed").toggle_current(explorer)
end

function M.toggle_readonly()
    if not checked_target() then
        return
    end
    local tab = vim.api.nvim_get_current_tabpage()
    local lifecycle = require("codediff.ui.lifecycle")
    if not lifecycle.get_session(tab) then
        notify("Open a review diff first")
        return
    end
    if readonly_buffers[tab] then
        M.restore_buffers(tab)
        return
    end
    readonly_buffers[tab] = {}
    M.freeze_buffers(tab)
    if not next(readonly_buffers[tab]) then
        readonly_buffers[tab] = nil
        notify("Revision snapshots are always read-only")
    end
end

function M.freeze_buffers(tab)
    local saved = readonly_buffers[tab]
    local lifecycle = require("codediff.ui.lifecycle")
    local original, modified = lifecycle.get_buffers(tab)
    for _, buf in pairs({ original, modified }) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
            saved[buf] = saved[buf] or { modifiable = vim.bo[buf].modifiable, readonly = vim.bo[buf].readonly }
            vim.bo[buf].modifiable = false
            vim.bo[buf].readonly = true
        end
    end
end

function M.restore_buffers(tab)
    for buf, options in pairs(readonly_buffers[tab] or {}) do
        if vim.api.nvim_buf_is_valid(buf) then
            vim.bo[buf].modifiable = options.modifiable
            vim.bo[buf].readonly = options.readonly
        end
    end
    readonly_buffers[tab] = nil
end

function M.close()
    local tab = vim.api.nvim_get_current_tabpage()
    if require("codediff.ui.lifecycle").get_session(tab) then
        require("codediff.ui.lifecycle").close()
    elseif vim.b.git_review_pr_url then
        Snacks.bufdelete()
    else
        notify("No review view to close")
    end
end

function M.setup()
    local group = vim.api.nvim_create_augroup("ReviewWorkflow", { clear = true })
    vim.api.nvim_create_autocmd("TabEnter", {
        group = group,
        callback = function()
            if package.loaded["review.marks"] then
                require("review.marks").clear_all()
                local target = M.target()
                if target and target.kind == "local" and M.valid(target) then
                    load_local(target)
                end
            end
        end,
    })
    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "CodeDiffFileSelect",
        callback = function(event)
            local tab = event.data.tabpage
            if readonly_buffers[tab] then
                M.freeze_buffers(tab)
            end
        end,
    })
    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "CodeDiffClose",
        callback = function(event)
            M.restore_buffers(event.data.tabpage)
            if package.loaded["review.hooks"] then
                require("review.hooks").on_session_closed()
            end
        end,
    })
    vim.api.nvim_create_autocmd("TabClosed", {
        group = group,
        callback = function()
            for tab in pairs(targets) do
                if not vim.api.nvim_tabpage_is_valid(tab) then
                    M.restore_buffers(tab)
                    targets[tab] = nil
                end
            end
        end,
    })
    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = { "PersistenceLoadPre", "PersistenceClearPost" },
        callback = function() targets = {} end,
    })
end

return M
