local M = {}
local context
local comments_enabled = false
local comment_win
local namespaces = {
    vim.api.nvim_create_namespace("GHLiteNamespace"),
    vim.api.nvim_create_namespace("GHLiteDiffNamespace"),
}
local file_maps = {}
local comment_updates = {}
local selection
local pending_diff
local request_id = 0
local checkout_in_progress = false
local pr_fields = table.concat({
    "number", "url", "title", "body", "author", "state", "isDraft",
    "headRefName", "headRefOid", "baseRefName", "baseRefOid", "reviewDecision",
    "statusCheckRollup", "latestReviews", "reviewRequests", "mergeable", "mergeStateStatus",
    "autoMergeRequest", "labels", "assignees", "additions", "deletions", "changedFiles",
    "createdAt", "updatedAt",
}, ",")

local function notify(message, level)
    vim.notify(message, level or vim.log.levels.WARN, { title = "Git review" })
end

local function snapshot(root)
    local name = vim.api.nvim_buf_get_name(0)
    local path = name:sub(1, 1) == "/" and name or vim.fn.getcwd()
    local view = require("git-review.description").view()
    root = root or vim.b.git_review_root or (view and view.root) or vim.fs.root(path, ".git")
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
    pending_diff = nil
    file_maps = {}
    comments_enabled = false
    for _, ns in ipairs(namespaces) do
        vim.diagnostic.reset(ns)
        vim.diagnostic.enable(false, { ns_id = ns })
    end
end

local function file_map(path, buf)
    local checkout, cache = context, file_maps
    if not checkout or not vim.api.nvim_buf_is_loaded(buf) then
        return nil
    end
    local entry = cache[path]
    if entry == false then
        return nil
    end
    if not entry then
        local result = vim.system({
            "git", "-C", checkout.root, "show", checkout.pr_head .. ":" .. path,
        }, { text = true }):wait()
        if result.code ~= 0 or result.stdout:find("\0", 1, true) then
            cache[path] = false
            return nil
        end
        local raw = result.stdout:gsub("\r\n", "\n")
        local original_lines = raw == "" and {} or vim.split(raw, "\n", { plain = true })
        if original_lines[#original_lines] == "" then
            table.remove(original_lines)
        end
        local normalized = require("git-review.content").normalize_bom(original_lines)
        entry = {
            original = #normalized > 0 and table.concat(normalized, "\n") .. "\n" or "",
            original_lines = original_lines,
        }
        cache[path] = entry
    end
    if not same_checkout(context, checkout) or context.pr_head ~= checkout.pr_head then
        notify("Checkout changed while mapping PR lines; retry")
        return nil
    end
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    if entry.buf ~= buf or entry.tick ~= tick then
        local current = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"
        entry.mapping = require("git-review.lines").new(entry.original, current)
        -- Revision dispatch still needs raw PR content, including its original BOM.
        entry.mapping.original_lines = entry.original_lines
        entry.buf, entry.tick = buf, tick
    end
    return entry.mapping
end

local function ensure_commit(pr, root, revision)
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

local function ensure_pr_commits(pr, root)
    for _, revision in ipairs({ pr.headRefOid, pr.baseRefOid }) do
        ensure_commit(pr, root, revision)
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

local function run_pr(action, require_clean, with_comments, target, metadata_only)
    if checkout_in_progress then
        notify("PR checkout is still in progress")
        return
    end
    local checkout = snapshot()
    if not checkout then
        notify("Open a file in a Git checkout first")
        return
    end
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()
    local view = require("git-review.description").view()
    target = target or vim.b.git_review_pr_url
        or (view and view.root == checkout.root and view.pr.url)
        or (selection and selection.root == checkout.root and selection.branch == checkout.branch and selection.url)
    request_id = request_id + 1
    local id = request_id
    return require("ghlite.task").run(function()
        local command = { "gh", "pr", "view" }
        if target then
            command[#command + 1] = target
        end
        vim.list_extend(command, { "--json", pr_fields })
        local result = require("async").await(3, vim.system, command, { cwd = checkout.root, text = true })
        require("ghlite.ui").schedule()
        if id ~= request_id or not vim.api.nvim_win_is_valid(win) or vim.api.nvim_get_current_win() ~= win
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
        local repository = assert(pr.url:match("^(https://[^/]+/[^/]+/[^/]+)/pull/%d+$"),
            "Could not determine the PR repository")
        local repo_result = require("async").await(3, vim.system, {
            "gh", "repo", "view", "--json", "url", "-q", ".url",
        }, { cwd = checkout.root, text = true })
        if repo_result.code ~= 0 then
            error("Could not verify the checkout's GitHub repository: " .. vim.trim(repo_result.stderr))
        end
        if vim.trim(repo_result.stdout):lower() ~= repository:lower() then
            require("ghlite.ui").schedule()
            notify("Open this PR's repository first, or set gh repo set-default to " .. repository)
            return
        end
        if not metadata_only then
            ensure_pr_commits(pr, checkout.root)
        end
        require("ghlite.ui").schedule()
        if id ~= request_id or vim.api.nvim_get_current_win() ~= win or vim.api.nvim_get_current_buf() ~= buf
            or not same_checkout(checkout, snapshot()) then
            notify("The active pane or checkout changed; retry the PR command")
            return
        end
        if require_clean and not clean_checkout(checkout) then
            return
        end
        if not same_checkout(context, checkout) or context.pr_url ~= pr.url or context.pr_head ~= pr.headRefOid then
            clear_comments()
        end
        context = checkout
        context.pr = pr.number
        context.pr_url = pr.url
        context.pr_head = pr.headRefOid
        context.pr_branch = pr.headRefName
        context.on_pr_branch = checkout.head == pr.headRefOid or checkout.branch == pr.headRefName
        selection = { root = checkout.root, branch = checkout.branch, url = pr.url }
        require("ghlite.state").selected_PR = pr
        -- GHLite's Git/GitHub commands resolve their repository from the window cwd.
        vim.cmd.lcd(checkout.root)
        if with_comments and require("ghlite.state").comments_pr_number ~= pr.number then
            require("ghlite.comments").load_comments_only(pr.number)
            require("ghlite.ui").schedule()
            if id ~= request_id or vim.api.nvim_get_current_win() ~= win or vim.api.nvim_get_current_buf() ~= buf
                or not same_checkout(context, checkout) or not same_checkout(checkout, snapshot()) then
                clear_comments()
                notify("The active pane or checkout changed while loading comments; retry")
                return
            end
            if require_clean and not clean_checkout(checkout) then
                return
            end
        end
        action(pr)
    end)
end

function M.select_pr(url)
    return run_pr(function(pr)
        require("git-review.description").open(pr, context.root)
    end, false, false, url, true)
end

function M.description()
    local tab = vim.api.nvim_get_current_tabpage()
    if require("git-review.description").hide(tab) then
        return
    end
    return run_pr(function(pr)
        if require("codediff.ui.lifecycle").get_session(tab) then
            require("git-review.description").attach(tab, pr, context.root)
        else
            require("git-review.description").open(pr, context.root)
        end
    end, false, false, nil, true)
end

local function checkout_is_clean(checkout)
    if not clean_checkout(checkout) then
        return false
    end
    local status = vim.system({ "git", "-C", checkout.root, "status", "--porcelain" }, { text = true }):wait()
    if status.code ~= 0 then
        notify("Could not check checkout status: " .. vim.trim(status.stderr), vim.log.levels.ERROR)
        return false
    end
    if vim.trim(status.stdout) ~= "" then
        notify("Save, commit, or remove tracked/untracked changes before checking out a PR")
        return false
    end
    return true
end

function M.checkout_pr()
    return run_pr(function(pr)
        local checkout = context
        local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
        if not checkout_is_clean(checkout) then
            return
        end
        vim.ui.select({ "Checkout PR", "Cancel" }, {
            prompt = "Checkout " .. pr.url .. " in " .. checkout.root .. "?",
        }, function(choice)
            if choice ~= "Checkout PR" then
                return
            end
            if checkout_in_progress or not vim.api.nvim_win_is_valid(win)
                or vim.api.nvim_get_current_win() ~= win or vim.api.nvim_get_current_buf() ~= buf
                or not same_checkout(checkout, snapshot()) or not same_checkout(context, checkout)
                or context.pr_url ~= pr.url or not checkout_is_clean(checkout) then
                notify("The active pane, selection, or checkout changed; retry checkout")
                return
            end
            checkout_in_progress = true
            vim.system({ "gh", "pr", "checkout", pr.url }, { cwd = checkout.root, text = true }, function(result)
                vim.schedule(function()
                    checkout_in_progress = false
                    clear_comments()
                    if result.code ~= 0 then
                        notify("PR checkout failed: " .. vim.trim(result.stderr), vim.log.levels.ERROR)
                        return
                    end
                    local updated = snapshot(checkout.root)
                    if not updated then
                        notify("PR checkout completed, but its Git state could not be read", vim.log.levels.ERROR)
                        return
                    end
                    selection = { root = updated.root, branch = updated.branch, url = pr.url }
                    vim.cmd.checktime()
                    vim.api.nvim_exec_autocmds("User", { pattern = "ReviewCheckout", data = { root = updated.root } })
                    notify("Checked out " .. pr.url .. "; use \\p to review", vim.log.levels.INFO)
                end)
            end)
        end)
    end, false, false, nil, true)
end

local function open_pr_diff(left, right, pr)
    pending_diff = { root = context.root, left = left, right = right or "WORKING", pr = pr }
    vim.cmd("CodeDiff " .. left .. (right and " " .. right or ""))
end

function M.local_diff()
    pending_diff = nil
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
            or not same_checkout(checkout, snapshot()) then
            notify("The active pane or checkout changed while preparing the PR diff; retry")
            return
        end
        if context.head == pr.headRefOid then
            open_pr_diff(vim.trim(result.stdout), nil, pr)
        else
            open_pr_diff(vim.trim(result.stdout), pr.headRefOid, pr)
        end
    end, false, true)
end

function M.since_review()
    return run_pr(function(pr)
        local checkout = context
        local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
        local host, repo = pr.url:match("^https://([^/]+)/([^/]+/[^/]+)/pull/%d+$")
        assert(host and repo, "Could not determine the PR repository")
        local function api(endpoint, paginate)
            local command = { "gh", "api", "--hostname", host }
            if paginate then
                vim.list_extend(command, { "--paginate", "--slurp" })
            end
            command[#command + 1] = endpoint
            local result = require("async").await(3, vim.system, command, {
                cwd = checkout.root, text = true,
            })
            if result.code ~= 0 then
                error("Could not load review history: " .. vim.trim(result.stderr))
            end
            return vim.json.decode(result.stdout)
        end
        local user = api("user")
        assert(type(user.login) == "string", "Could not determine the signed-in GitHub user")
        local pages = api("repos/" .. repo .. "/pulls/" .. pr.number .. "/reviews?per_page=100", true)
        local latest
        for _, page in ipairs(pages) do
            for _, review in ipairs(page) do
                if type(review.user) == "table" and review.user.login == user.login
                    and review.state ~= "PENDING" and type(review.submitted_at) == "string"
                    and (not latest or review.submitted_at > latest.submitted_at
                        or (review.submitted_at == latest.submitted_at and review.id > latest.id)) then
                    latest = review
                end
            end
        end
        require("ghlite.ui").schedule()
        if not latest then
            notify("No submitted review was found for " .. user.login)
            return
        end
        local left = latest.commit_id
        if type(left) ~= "string" or not left:match("^[a-fA-F0-9]+$")
            or (#left ~= 40 and #left ~= 64) then
            error("Your latest submitted review has no valid commit")
        end
        if left ~= pr.headRefOid then
            ensure_commit(pr, checkout.root, left)
        end
        local remote = api("repos/" .. repo .. "/pulls/" .. pr.number)
        if type(remote.head) ~= "table" or type(remote.head.sha) ~= "string" then
            error("Could not verify the current PR head")
        end
        if remote.head.sha ~= pr.headRefOid then
            require("ghlite.ui").schedule()
            clear_comments()
            notify("The PR head changed while loading review history; retry")
            return
        end
        local diff = require("ghlite.system").run_result({
            "git", "-C", checkout.root, "diff", "--quiet", "--no-ext-diff", "--no-textconv",
            left, pr.headRefOid, "--",
        })
        if diff.code ~= 0 and diff.code ~= 1 then
            error("Could not compare reviewed snapshots: " .. vim.trim(diff.stderr))
        end
        require("ghlite.ui").schedule()
        if vim.api.nvim_get_current_win() ~= win or vim.api.nvim_get_current_buf() ~= buf
            or not same_checkout(context, checkout) or context.pr_head ~= pr.headRefOid
            or not same_checkout(checkout, snapshot()) or not clean_checkout(checkout) then
            notify("The active pane or checkout changed while loading review history; retry")
            return
        end
        if diff.code == 0 then
            notify("No file changes since your last review", vim.log.levels.INFO)
            return
        end
        open_pr_diff(left, pr.headRefOid, pr)
        notify("Changes since your review submitted " .. latest.submitted_at, vim.log.levels.INFO)
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
        notify("PR comments hidden", vim.log.levels.INFO)
        return
    end
    return run_pr(function(pr)
        local checkout = context
        require("ghlite.comments").load_comments_only(pr.number)
        require("ghlite.ui").schedule()
        if not same_checkout(context, checkout) or not same_checkout(checkout, snapshot()) then
            clear_comments()
            notify("Checkout changed while loading comments; retry")
            return
        end
        comments_enabled = true
        for _, ns in ipairs(namespaces) do
            vim.diagnostic.enable(true, { ns_id = ns })
        end
        require("ghlite.comments").load_comments_on_visible_buffers()
        notify("PR comments enabled", vim.log.levels.INFO)
    end, false)
end

function M.show_comment()
    if comment_win and vim.api.nvim_win_is_valid(comment_win) then
        vim.api.nvim_win_close(comment_win, true)
        return
    end
    if not comments_enabled then
        notify("Enable PR comments with \\c first")
        return
    end
    if not same_checkout(context, snapshot()) then
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
    elseif not context.on_pr_branch then
        notify("Check out this PR with \\C before commenting in local files, or use its right-hand snapshot in \\p")
        return
    elseif context.head ~= context.pr_head or context.branch ~= context.pr_branch then
        local path = vim.fs.relpath(context.root, name)
        local mapping = path and file_map(path, buf)
        local mapped_first, mapped_last
        if mapping then
            mapped_first, mapped_last = mapping.to_pr(first, last)
        end
        if not mapped_first then
            notify("These lines differ from the PR head; comment on their original version in \\p")
            return
        end
        for _, thread in ipairs(require("ghlite.state").comments_list[name] or {}) do
            local start = type(thread.start_line) == "number" and thread.start_line or thread.line
            local anchor, approximate = mapping.anchor_local(start, thread.line)
            if approximate and anchor >= first and anchor <= last then
                notify("This is an approximate local comment anchor; reply or resolve on its original PR version in \\p")
                return
            end
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
        if (root and not is_pr_head)
            or (not root and (not checkout.on_pr_branch or vim.bo[bufnr].buftype ~= "")) then
            vim.diagnostic.reset(namespaces[1], bufnr)
            return
        end
        local diagnostics = {}
        local skipped = 0
        local threads = require("ghlite.state").comments_list[filename] or {}
        local path = not is_pr_head and vim.fs.relpath(checkout.root, filename)
        local mapping = path and #threads > 0 and file_map(path, bufnr)
        for _, thread in ipairs(threads) do
            local line = thread.line
            local approximate, reason
            if not is_pr_head then
                local first = type(thread.start_line) == "number" and thread.start_line or line
                if mapping then
                    line, approximate, reason = mapping.anchor_local(first, line)
                else
                    line = nil
                end
            end
            if line and #thread.comments > 0 then
                local comment = thread.comments[1]
                local preview = (thread.resolved and "[resolved] " or "") .. "@" .. (comment.user or "unknown")
                    .. ": " .. vim.trim((comment.body or ""):gsub("%s+", " "))
                local message = thread.content
                if approximate then
                    local label = reason == "deleted" and "local deletion" or "local edit"
                    preview = "[" .. label .. "] " .. preview
                    message = "Approximate display anchor (" .. label .. ") for PR line " .. thread.line
                        .. ".\n\n" .. message
                end
                diagnostics[#diagnostics + 1] = {
                    lnum = line - 1, col = 0, message = message,
                    severity = vim.diagnostic.severity.INFO, source = "GHLite",
                    user_data = { preview = preview, pr_line = thread.line, approximate = approximate or false },
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
                notify(skipped .. " PR thread(s) could not be anchored in this buffer; view them in \\p")
            end
        end
        if is_pr_head then
            vim.diagnostic.enable(true, { bufnr = bufnr })
        end
        vim.diagnostic.set(namespaces[1], bufnr, diagnostics)
    end)
end

function M.setup_ghlite()
    require("ghlite.config").s.pr_commands = {}
    -- Upstream's REST loader reads one page and can display outdated line coordinates.
    require("ghlite.gh").load_comments = load_all_comments
    local comments = require("ghlite.comments")
    comments.load_comments_on_buffer_by_filename = render_comments
    local load_buffer_comments = comments.load_comments_on_buffer
    comments.load_comments_on_buffer = function(buf)
        if context and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
            render_comments(buf, vim.api.nvim_buf_get_name(buf))
        else
            return load_buffer_comments(buf)
        end
    end
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
            virtual_text = {
                prefix = "C",
                source = false,
                severity = vim.diagnostic.severity.INFO,
                format = function(diagnostic)
                    return diagnostic.user_data and diagnostic.user_data.preview or diagnostic.message
                end,
            },
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
end

function M.setup()
    vim.api.nvim_set_hl(0, "GitReviewComment", { link = "DiagnosticInfo", default = true })
    vim.api.nvim_create_user_command("GitReviewDescription", M.description, { desc = "View selected PR description" })
    vim.api.nvim_create_user_command("GitReviewCheckout", M.checkout_pr, { desc = "Check out selected PR with confirmation" })
    vim.api.nvim_create_user_command("GitReviewSince", M.since_review, {
        desc = "PR changes since your latest submitted review",
    })
    local group = vim.api.nvim_create_augroup("GitReviewContext", { clear = true })
    require("git-review.description").setup(group)
    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "CodeDiffOpen",
        callback = function(args)
            local tab = args.data.tabpage
            local pending = pending_diff
            local git = require("codediff.ui.lifecycle").get_git_context(tab)
            if pending and git and git.git_root == pending.root and git.original_revision == pending.left
                and (git.modified_revision or "WORKING") == pending.right then
                pending_diff = nil
                vim.schedule(function()
                    if vim.api.nvim_tabpage_is_valid(tab) and require("codediff.ui.lifecycle").get_session(tab) then
                        require("git-review.description").attach(tab, pending.pr, pending.root)
                    end
                end)
            end
        end,
    })
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
        callback = function(args)
            if context and not same_checkout(context, snapshot()) then
                clear_comments()
            elseif context and comments_enabled then
                require("ghlite.comments").load_comments_on_buffer(args.buf)
            end
        end,
    })
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
        group = group,
        callback = function(args)
            local buf = args.buf
            if context and comments_enabled and not comment_updates[buf] then
                comment_updates[buf] = true
                vim.defer_fn(function()
                    comment_updates[buf] = nil
                    if context and comments_enabled and vim.api.nvim_buf_is_loaded(buf) then
                        require("ghlite.comments").load_comments_on_buffer(buf)
                    end
                end, 100)
            end
        end,
    })
end

return M
