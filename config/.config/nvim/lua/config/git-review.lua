local M = {}
local context
local comments_enabled = false
local comment_win
local namespaces = {
    vim.api.nvim_create_namespace("GHLiteNamespace"),
    vim.api.nvim_create_namespace("GHLiteDiffNamespace"),
}
local file_maps = {}

local function notify(message, level)
    vim.notify(message, level or vim.log.levels.WARN, { title = "Git review" })
end

local function snapshot()
    local name = vim.api.nvim_buf_get_name(0)
    local path = name:sub(1, 1) == "/" and name or vim.fn.getcwd()
    local root = vim.fs.root(path, ".git")
    if not root then
        return nil
    end
    local result = vim.system({
        "git", "-C", root, "rev-parse", "HEAD", "--abbrev-ref", "HEAD",
    }, { text = true }):wait()
    if result.code ~= 0 then
        return nil
    end
    local lines = vim.split(vim.trim(result.stdout), "\n", { plain = true })
    return { root = root, head = lines[1], branch = lines[2] }
end

local function same_checkout(a, b)
    return a and b and a.root == b.root and a.head == b.head and a.branch == b.branch
end

local function clear_comments()
    if comment_win and vim.api.nvim_win_is_valid(comment_win) then
        vim.api.nvim_win_close(comment_win, true)
    end
    local state = require("ghlite.state")
    state.selected_PR = nil
    state.comments_list = {}
    state.comments_pr_number = nil
    state.pending_reviews = {}
    state.pending_reviews_checked = {}
    context = nil
    file_maps = {}
    comments_enabled = false
    for _, ns in ipairs(namespaces) do
        vim.diagnostic.reset(ns)
        vim.diagnostic.enable(false, { ns_id = ns })
    end
end

local function file_map(path)
    local checkout, cache = context, file_maps
    if not checkout then
        return nil
    end
    if cache[path] ~= nil then
        return cache[path] or nil
    end
    local contents = {}
    for _, revision in ipairs({ checkout.pr_head, checkout.head }) do
        local result = vim.system({
            "git", "-C", checkout.root, "show", revision .. ":" .. path,
        }, { text = true }):wait()
        if result.code ~= 0 or result.stdout:find("\0", 1, true) then
            cache[path] = false
            return nil
        end
        contents[#contents + 1] = result.stdout
    end
    if not same_checkout(context, checkout) or context.pr_head ~= checkout.pr_head then
        notify("Checkout changed while mapping PR lines; retry")
        return nil
    end
    cache[path] = require("config.git-review-lines").new(contents[1], contents[2])
    return cache[path]
end

local function ensure_pr_commits(pr, root)
    for _, revision in ipairs({ pr.headRefOid, pr.baseRefOid }) do
        local exists = require("ghlite.system").run_result({
            "git", "-C", root, "cat-file", "-e", revision .. "^{commit}",
        })
        if exists.code ~= 0 then
            local repository = assert(pr.url:match("^(https://[^/]+/[^/]+/[^/]+)/pull/%d+$"),
                "Could not determine the PR repository")
            local fetched = require("ghlite.system").run_result({
                "git", "-C", root, "fetch", "--no-tags", repository .. ".git", revision,
            })
            if fetched.code ~= 0 then
                error("Could not fetch PR snapshot: " .. vim.trim(fetched.stderr))
            end
        end
    end
end

local function clean_checkout(checkout)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].buftype == "" and vim.bo[buf].modified
            and vim.fs.relpath(checkout.root, vim.api.nvim_buf_get_name(buf)) then
            notify("Save or discard local changes before using PR line comments")
            return false
        end
    end
    local result = vim.system({
        "git", "-C", checkout.root, "diff", "--quiet", "HEAD", "--",
    }, { text = true }):wait()
    if result.code ~= 0 then
        notify(result.code == 1 and "PR comments require no tracked changes against HEAD"
            or "Could not check working tree: " .. result.stderr)
        return false
    end
    return true
end

local function run_pr(action, require_clean, with_comments)
    local checkout = snapshot()
    if not checkout then
        notify("Open a file in a Git checkout first")
        return
    end
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()
    return require("ghlite.task").run(function()
        local result = require("async").await(3, vim.system, {
            "gh", "pr", "view", "--json",
            "number,url,headRefName,headRefOid,baseRefName,baseRefOid,reviewDecision",
        }, { cwd = checkout.root, text = true })
        require("ghlite.ui").schedule()
        if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_get_current_win() ~= win
            or vim.api.nvim_get_current_buf() ~= buf or not same_checkout(checkout, snapshot()) then
            notify("The active pane or checkout changed; retry the PR command")
            return
        end
        if result.code ~= 0 then
            clear_comments()
            notify("Could not resolve the current branch's PR: " .. vim.trim(result.stderr))
            return
        end
        local pr = vim.json.decode(result.stdout)
        ensure_pr_commits(pr, checkout.root)
        require("ghlite.ui").schedule()
        if vim.api.nvim_get_current_win() ~= win or vim.api.nvim_get_current_buf() ~= buf
            or not same_checkout(checkout, snapshot()) then
            notify("The active pane or checkout changed; retry the PR command")
            return
        end
        if require_clean and not clean_checkout(checkout) then
            clear_comments()
            return
        end
        if not same_checkout(context, checkout) or context.pr ~= pr.number or context.pr_head ~= pr.headRefOid then
            clear_comments()
        end
        context = checkout
        context.pr = pr.number
        context.pr_head = pr.headRefOid
        require("ghlite.state").selected_PR = pr
        -- GHLite's Git/GitHub commands resolve their repository from the window cwd.
        vim.cmd.lcd(checkout.root)
        if with_comments and require("ghlite.state").comments_pr_number ~= pr.number then
            require("ghlite.comments").load_comments_only(pr.number)
            require("ghlite.ui").schedule()
            if vim.api.nvim_get_current_win() ~= win or vim.api.nvim_get_current_buf() ~= buf
                or not same_checkout(context, checkout) or not same_checkout(checkout, snapshot())
                or (require_clean and not clean_checkout(checkout)) then
                clear_comments()
                notify("The active pane or checkout changed while loading comments; retry")
                return
            end
        end
        action(pr)
    end)
end

function M.local_diff()
    local lifecycle = require("codediff.ui.lifecycle")
    if lifecycle.get_session(vim.api.nvim_get_current_tabpage()) then
        lifecycle.close()
    else
        vim.cmd.CodeDiff()
    end
end

function M.pr_diff()
    local lifecycle = require("codediff.ui.lifecycle")
    if lifecycle.get_session(vim.api.nvim_get_current_tabpage()) then
        lifecycle.close()
        return
    end
    return run_pr(function(pr)
        local win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_get_current_buf()
        local checkout = context
        local result = require("ghlite.system").run_result({
            "git", "-C", context.root, "merge-base", pr.baseRefOid, pr.headRefOid,
        })
        if result.code ~= 0 then
            error("Could not determine the PR merge base: " .. vim.trim(result.stderr))
        end
        require("ghlite.ui").schedule()
        if vim.api.nvim_get_current_win() ~= win or vim.api.nvim_get_current_buf() ~= buf
            or not same_checkout(checkout, snapshot()) or not clean_checkout(checkout) then
            notify("The active pane or checkout changed while preparing the PR diff; retry")
            return
        end
        if context.head == pr.headRefOid then
            vim.cmd("CodeDiff " .. vim.trim(result.stdout))
        else
            vim.cmd("CodeDiff " .. vim.trim(result.stdout) .. " " .. pr.headRefOid)
        end
    end, true, true)
end

function M.toggle_comments()
    if comments_enabled then
        if comment_win and vim.api.nvim_win_is_valid(comment_win) then
            vim.api.nvim_win_close(comment_win, true)
        end
        comments_enabled = false
        for _, ns in ipairs(namespaces) do
            vim.diagnostic.enable(false, { ns_id = ns })
        end
        notify("PR comment signs hidden", vim.log.levels.INFO)
        return
    end
    return run_pr(function(pr)
        local checkout = context
        require("ghlite.comments").load_comments_only(pr.number)
        require("ghlite.ui").schedule()
        if not same_checkout(context, checkout) or not same_checkout(checkout, snapshot())
            or not clean_checkout(checkout) then
            clear_comments()
            notify("Checkout changed while loading comments; retry")
            return
        end
        comments_enabled = true
        for _, ns in ipairs(namespaces) do
            vim.diagnostic.enable(true, { ns_id = ns })
        end
        require("ghlite.comments").load_comments_on_visible_buffers()
        notify("PR comment signs enabled", vim.log.levels.INFO)
    end, true)
end

function M.show_comment()
    if comment_win and vim.api.nvim_win_is_valid(comment_win) then
        vim.api.nvim_win_close(comment_win, true)
        return
    end
    if not comments_enabled then
        notify("Enable PR comments with ,Gc first")
        return
    end
    if not same_checkout(context, snapshot()) or not clean_checkout(context) then
        clear_comments()
        notify("Checkout changed; reload PR comments")
        return
    end
    local buf = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_win_get_cursor(0)[1] - 1
    for _, ns in ipairs(namespaces) do
        if #vim.diagnostic.get(buf, { namespace = ns, lnum = line }) > 0 then
            local float_buf, win = vim.diagnostic.open_float(buf, {
                namespace = ns, scope = "line", header = "PR comments", source = false,
                focus = true, border = "rounded",
            })
            if win then
                comment_win = win
                vim.api.nvim_set_current_win(win)
                vim.keymap.set("n", "<Esc>", function()
                    if vim.api.nvim_win_is_valid(win) then
                        vim.api.nvim_win_close(win, true)
                    end
                end, { buffer = float_buf, desc = "Close PR comments" })
            end
            return
        end
    end
    notify("No PR comments on this line")
end

local function dispatch_line_action(command, first, last)
    local buf = vim.api.nvim_get_current_buf()
    local name = vim.api.nvim_buf_get_name(buf)
    local virtual = require("codediff.core.virtual_file")
    local root, revision = virtual.parse_url(name)
    if root then
        if root ~= context.root or revision ~= context.pr_head then
            notify("Comment on the PR head (right side), not a historical revision")
            return
        end
    elseif context.head ~= context.pr_head then
        local path = vim.fs.relpath(context.root, name)
        local mapping = path and file_map(path)
        local mapped_first, mapped_last
        if mapping then
            mapped_first, mapped_last = mapping.to_pr(first, last)
        end
        if not mapped_first then
            notify("These lines differ from the PR head; comment on their original version in ,Gp")
            return
        end
        local uri = virtual.create_url(context.root, context.pr_head, path)
        local revision_buf = vim.fn.bufnr(uri)
        local created = revision_buf == -1
        if created then
            revision_buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_name(revision_buf, uri)
        end
        virtual.set_content(revision_buf, mapping.original_lines, path)
        local win = vim.api.nvim_get_current_win()
        local view = vim.fn.winsaveview()
        vim.api.nvim_win_set_buf(win, revision_buf)
        local task = dispatch_line_action(command, mapped_first, mapped_last)
        local function restore()
            vim.schedule(function()
                if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == revision_buf
                    and vim.api.nvim_buf_is_valid(buf) then
                    vim.api.nvim_win_set_buf(win, buf)
                    vim.api.nvim_win_call(win, function() vim.fn.winrestview(view) end)
                end
                if created and vim.api.nvim_buf_is_valid(revision_buf)
                    and #vim.fn.win_findbuf(revision_buf) == 0 then
                    vim.api.nvim_buf_delete(revision_buf, { force = true })
                end
            end)
        end
        if task then
            task:on_complete(restore)
        else
            restore()
        end
        return task
    end
    vim.api.nvim_buf_set_mark(0, "<", first, 0, {})
    vim.api.nvim_buf_set_mark(0, ">", last, 0, {})
    if command == "GHLitePRAddComment" then
        return require("ghlite.comments").comment_on_line()
    end
    return require("ghlite.comments").resolve_comment()
end

function M.add_comment()
    local visual = vim.fn.mode():match("[vV\22]") ~= nil
    local first = vim.api.nvim_win_get_cursor(0)[1]
    local last = first
    if visual then
        first = vim.fn.line("v")
        vim.cmd.normal({ vim.api.nvim_replace_termcodes("<Esc>", true, false, true), bang = true })
    end
    return run_pr(function()
        dispatch_line_action("GHLitePRAddComment", math.min(first, last), math.max(first, last))
    end, true, true)
end

function M.review_command(command)
    vim.api.nvim_buf_del_mark(0, "<")
    vim.api.nvim_buf_del_mark(0, ">")
    return run_pr(function()
        if command == "GHLitePRResolveComment" then
            local line = vim.api.nvim_win_get_cursor(0)[1]
            dispatch_line_action(command, line, line)
        else
            vim.cmd(command)
        end
    end, true, command == "GHLitePRResolveComment")
end

local function load_all_comments(pr_number, pending_review)
    local gh = require("ghlite.gh")
    local function request(command)
        local result = require("ghlite.system").run_result(command)
        if result.code ~= 0 then
            error("Could not load PR comments: " .. vim.trim(result.stderr))
        end
        return result.stdout
    end
    local repo = vim.trim(request({ "gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner" }))
    local pages = vim.json.decode(request({
        "gh", "api", "--paginate", "--slurp",
        "repos/" .. repo .. "/pulls/" .. pr_number .. "/comments?per_page=100",
    }))
    local comments = {}
    for _, page in ipairs(pages) do
        vim.list_extend(comments, page)
    end
    if pending_review then
        vim.list_extend(comments, gh.get_pending_comments(pending_review))
    end
    local groups = require("ghlite.comments_utils").group_comments(comments, {
        comment_hunk = false,
    }, gh.get_review_thread_statuses(pr_number, repo))
    for path, threads in pairs(groups) do
        groups[path] = vim.tbl_filter(function(thread)
            return not thread.outdated and type(thread.comments[1].line) == "number"
        end, threads)
    end
    return groups
end

local function render_comments(bufnr, filename)
    vim.schedule(function()
        local checkout = context
        if not vim.api.nvim_buf_is_valid(bufnr) or not checkout then
            return
        end
        local name = vim.api.nvim_buf_get_name(bufnr)
        local root, revision = require("codediff.core.virtual_file").parse_url(name)
        local is_pr_head = root == checkout.root and revision == checkout.pr_head
        if root and not is_pr_head then
            vim.diagnostic.reset(namespaces[1], bufnr)
            return
        end
        local diagnostics = {}
        local skipped = 0
        for _, thread in ipairs(require("ghlite.state").comments_list[filename] or {}) do
            local line = thread.line
            if not is_pr_head and checkout.head ~= checkout.pr_head then
                local path = vim.fs.relpath(checkout.root, filename)
                local mapping = path and file_map(path)
                local first = type(thread.start_line) == "number" and thread.start_line or line
                local _, mapped_line
                if mapping then
                    _, mapped_line = mapping.to_local(first, line)
                end
                line = mapped_line
            end
            if line and #thread.comments > 0 then
                diagnostics[#diagnostics + 1] = {
                    lnum = line - 1, col = 0, message = thread.content,
                    severity = vim.diagnostic.severity.INFO, source = "GHLite",
                }
            else
                skipped = skipped + 1
            end
        end
        if not same_checkout(context, checkout) or context.pr_head ~= checkout.pr_head
            or not vim.api.nvim_buf_is_valid(bufnr) then
            return
        end
        if skipped > 0 then
            checkout.unmapped = checkout.unmapped or {}
            if not checkout.unmapped[filename] then
                checkout.unmapped[filename] = true
                notify(skipped .. " PR thread(s) touch locally changed lines; view them in ,Gp")
            end
        end
        if is_pr_head then
            vim.diagnostic.enable(true, { bufnr = bufnr })
        end
        vim.diagnostic.set(namespaces[1], bufnr, diagnostics)
    end)
end

function M.setup()
    -- Upstream's REST loader reads one page and can display outdated line coordinates.
    require("ghlite.gh").load_comments = load_all_comments
    require("ghlite.comments").load_comments_on_buffer_by_filename = render_comments
    local utils = require("ghlite.utils")
    local get_comment = utils.get_comment
    utils.get_comment = function(name, split, prompt, content, key, send)
        local checkout = context
        return get_comment(name, split, prompt, content, key, function(input)
            if checkout and (not same_checkout(checkout, context)
                or checkout.pr ~= context.pr or checkout.pr_head ~= context.pr_head
                or not same_checkout(checkout, snapshot()) or not clean_checkout(checkout)) then
                vim.cmd.new()
                vim.bo.buftype = "nofile"
                vim.bo.bufhidden = "hide"
                vim.bo.filetype = "markdown"
                vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(input, "\n", { plain = true }))
                notify("Not sent: the checkout or PR changed. Your draft is retained in this buffer.",
                    vim.log.levels.ERROR)
                return
            end
            send(input)
        end)
    end
    for _, ns in ipairs(namespaces) do
        vim.diagnostic.config({
            virtual_text = false,
            virtual_lines = false,
            underline = false,
            signs = {
                text = { [vim.diagnostic.severity.INFO] = "C" },
                texthl = { [vim.diagnostic.severity.INFO] = "GitReviewComment" },
                priority = 30,
            },
        }, ns)
        vim.diagnostic.enable(false, { ns_id = ns })
    end
    local group = vim.api.nvim_create_augroup("GitReviewContext", { clear = true })
    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "CodeDiffVirtualFileLoaded",
        callback = function(args)
            if context and comments_enabled then
                require("ghlite.comments").load_comments_on_buffer(args.data.buf)
            end
        end,
    })
    vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "DirChanged" }, {
        group = group,
        callback = function()
            if context and not same_checkout(context, snapshot()) then
                clear_comments()
            end
        end,
    })
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
        group = group,
        callback = function()
            if context and not clean_checkout(context) then
                clear_comments()
                notify("PR comments cleared because local edits can change GitHub line coordinates")
            end
        end,
    })
end

return M
