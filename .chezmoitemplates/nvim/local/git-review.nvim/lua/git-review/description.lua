local M = {}
local views = {}
local namespace = vim.api.nvim_create_namespace("git-review.summary")
local styles = {
    good = { "✓", "DiagnosticOk" },
    bad = { "✗", "DiagnosticError" },
    pending = { "◷", "DiagnosticWarn" },
    info = { "●", "DiagnosticInfo" },
    muted = { "○", "Comment" },
    unknown = { "?", "DiagnosticWarn" },
}
local states = {
    APPROVED = { "Approved", "good" },
    CHANGES_REQUESTED = { "Changes requested", "bad" },
    REVIEW_REQUIRED = { "Review required", "pending" },
    COMMENTED = { "Commented", "info" },
    DISMISSED = { "Dismissed", "muted" },
    PENDING = { "Pending", "pending" },
    OPEN = { "Open", "good" },
    CLOSED = { "Closed", "bad" },
    MERGED = { "Merged", "info" },
    DRAFT = { "Draft", "muted" },
    MERGEABLE = { "No conflicts", "good" },
    CONFLICTING = { "Conflicts present", "bad" },
    CLEAN = { "Ready to merge", "good" },
    BLOCKED = { "Blocked", "pending" },
    BEHIND = { "Branch behind base", "pending" },
    DIRTY = { "Conflicts present", "bad" },
    UNSTABLE = { "Checks not passing", "pending" },
    HAS_HOOKS = { "Merge hooks pending", "pending" },
}

local function append(lines, highlights, prefix, text, style)
    if style then
        local badge = styles[style]
        text = badge[1] .. " " .. text
        highlights[#highlights + 1] = {
            row = #lines, col = #prefix, end_col = #prefix + #text, group = badge[2],
        }
    end
    lines[#lines + 1] = prefix .. text
end

function M.view(tab)
    return views[tab or vim.api.nvim_get_current_tabpage()]
end

function M.foldexpr(lnum)
    local range = vim.b.git_review_checks_fold
    return range and lnum >= range[1] and lnum <= range[2] and 1 or 0
end

local function reported(value, fallback)
    return type(value) == "string" and value ~= "" and value or (fallback or "Unknown")
end

local function local_time(value)
    return type(value) == "number" and os.date("%b %d, %Y at %I:%M %p %Z", value) or "Unknown"
end

local function names(items, prefix)
    if type(items) ~= "table" then
        return "Unknown"
    end
    local result = {}
    for _, item in ipairs(items) do
        result[#result + 1] = (prefix or "") .. (item.login or item.slug or item.name or "unknown")
    end
    if #result == 0 then
        return "None"
    end
    local text = table.concat(result, ", ")
    return #result == 100 and text .. " (first 100; more may exist)" or text
end

local check_buckets = {
    SUCCESS = "passing",
    FAILURE = "failing", ERROR = "failing", ACTION_REQUIRED = "failing",
    TIMED_OUT = "failing", STARTUP_FAILURE = "failing",
    EXPECTED = "pending", PENDING = "pending", QUEUED = "pending",
    IN_PROGRESS = "pending", REQUESTED = "pending", WAITING = "pending",
    NEUTRAL = "neutral", SKIPPED = "skipped", CANCELLED = "cancelled",
}

local function check_state(check)
    if check.__typename == "CheckRun" then
        if check.status == "COMPLETED" then
            return reported(check.conclusion)
        end
        return reported(check.status)
    end
    return reported(check.state)
end

local function status_lines(pr, lines, highlights)
    local function add(prefix, text, style)
        append(lines, highlights, prefix, text, style)
    end
    local function status(prefix, value, fallback)
        local state = states[value or ""]
        add(prefix, state and state[1] or reported(value, fallback), state and state[2] or "unknown")
    end
    local counts = { passing = 0, failing = 0, pending = 0, neutral = 0, skipped = 0, cancelled = 0, unknown = 0 }
    local check_styles = {
        passing = "good", failing = "bad", pending = "pending",
        neutral = "muted", skipped = "muted", cancelled = "muted", unknown = "unknown",
    }
    local checks = {}
    for _, check in ipairs(type(pr.statusCheckRollup) == "table" and pr.statusCheckRollup or {}) do
        local state = check_state(check)
        local bucket = check_buckets[state] or "unknown"
        counts[bucket] = counts[bucket] + 1
        local name = reported(check.name or check.context, "Unnamed check")
        if type(check.workflowName) == "string" and check.workflowName ~= "" then
            name = check.workflowName .. " / " .. name
        end
        checks[#checks + 1] = { name .. ": " .. state:gsub("_", " "):lower(), check_styles[bucket] }
    end
    local summary = type(pr.statusCheckRollup) ~= "table" and "Unavailable" or "None reported"
    local parts = {}
    if #checks > 0 then
        local texts = {}
        for _, bucket in ipairs({ "passing", "failing", "pending", "neutral", "skipped", "cancelled", "unknown" }) do
            if counts[bucket] > 0 then
                local style = styles[check_styles[bucket]]
                local text = style[1] .. " " .. counts[bucket] .. " " .. bucket
                texts[#texts + 1] = text
                parts[#parts + 1] = { text, style[2] }
            end
        end
        summary = table.concat(texts, ", ")
    end
    local auto_merge = pr.autoMergeRequest == vim.NIL and "Disabled" or "Unknown"
    if type(pr.autoMergeRequest) == "table" then
        auto_merge = "Enabled (" .. reported(pr.autoMergeRequest.mergeMethod) .. ")"
    end
    add("", "## PR status")
    add("", "")
    status("Review/signoff: ", pr.reviewDecision, "No decision reported")
    local approved, changes_requested = {}, {}
    if type(pr.currentReviews) == "table" then
        for _, review in ipairs(pr.currentReviews) do
            local author = type(review.author) == "table" and review.author or { login = "unknown" }
            if review.state == "APPROVED" then
                approved[#approved + 1] = author
            elseif review.state == "CHANGES_REQUESTED" then
                changes_requested[#changes_requested + 1] = author
            end
        end
    end
    -- This connection is fully paginated, unlike gh pr view's capped metadata lists.
    local function reviewers(items)
        table.sort(items, function(a, b) return (a.login or ""):lower() < (b.login or ""):lower() end)
        return table.concat(vim.tbl_map(function(author) return "@" .. (author.login or "unknown") end, items), ", ")
    end
    add("Approved by: ", type(pr.currentReviews) ~= "table" and "Unavailable"
        or (#approved > 0 and reviewers(approved) or "None"),
        type(pr.currentReviews) ~= "table" and "unknown" or (#approved > 0 and "good" or "muted"))
    if #changes_requested > 0 then
        add("Changes requested by: ", reviewers(changes_requested), "bad")
    end
    add("Checks: ", summary, type(pr.statusCheckRollup) ~= "table" and "unknown"
        or (#checks == 0 and "muted" or nil))
    local col = #"Checks: "
    for _, part in ipairs(parts) do
        highlights[#highlights + 1] = {
            row = #lines - 1, col = col, end_col = col + #part[1], group = part[2],
        }
        col = col + #part[1] + #", "
    end
    status("Merge conflicts: ", pr.mergeable)
    status("Merge readiness: ", pr.mergeStateStatus)
    add("Auto-merge: ", auto_merge, type(pr.autoMergeRequest) == "table" and "good"
        or (pr.autoMergeRequest == vim.NIL and "muted" or "unknown"))
    local changes_prefix = ("Changes: %s files ("):format(pr.changedFiles or "Unknown")
    local additions, deletions = "+" .. (pr.additions or "Unknown"), "-" .. (pr.deletions or "Unknown")
    add("", changes_prefix .. additions .. " / " .. deletions .. ")")
    highlights[#highlights + 1] = {
        row = #lines - 1, col = #changes_prefix, end_col = #changes_prefix + #additions, group = "GitSignsAdd",
    }
    highlights[#highlights + 1] = {
        row = #lines - 1, col = #changes_prefix + #additions + 3,
        end_col = #changes_prefix + #additions + 3 + #deletions, group = "GitSignsDelete",
    }
    add("Awaiting review: ", names(pr.reviewRequests, "@"),
        type(pr.reviewRequests) ~= "table" and "unknown" or (#pr.reviewRequests > 0 and "pending" or "muted"))
    add("Assignees: ", names(pr.assignees, "@"))
    add("Labels: ", names(pr.labels))
    add("Created: ", local_time(pr.createdAtEpoch))
    add("Updated: ", local_time(pr.updatedAtEpoch))
    add("", "")
    add("", "### Latest reviews")
    add("", "")
    if type(pr.latestReviews) ~= "table" then
        add("", "Unavailable", "unknown")
    elseif #pr.latestReviews == 0 then
        add("", "None submitted", "muted")
    else
        for _, review in ipairs(pr.latestReviews) do
            local author = type(review.author) == "table" and reported(review.author.login, "unknown") or "unknown"
            status("- @" .. author .. ": ", review.state)
        end
        if #pr.latestReviews == 100 then
            add("", "First 100 reviewers shown; more may exist.", "pending")
        end
    end
    if #checks > 0 then
        add("", "")
        local first = #lines + 1
        local style = counts.failing > 0 and "bad"
            or (counts.pending > 0 or counts.cancelled > 0) and "pending"
            or counts.unknown > 0 and "unknown"
            or counts.passing == #checks and "good" or "muted"
        add("### Checks: ", ("%d/%d passed (Space to toggle)"):format(counts.passing, #checks), style)
        add("", "")
        for _, check in ipairs(checks) do
            add("- ", check[1], check[2])
        end
        return { first, #lines }
    end
end

local function buffer(pr, root)
    local name = pr.url:gsub("^https://", "git-review://") .. "?root=" .. vim.uri_encode(root)
    local buf = vim.fn.bufnr(name)
    if buf == -1 then
        buf = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_buf_set_name(buf, name)
    end
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.b[buf].git_review_root = root
    vim.b[buf].git_review_pr_url = pr.url
    local author = type(pr.author) == "table" and pr.author.login or "unknown"
    local reference = pr.url:match("^https://[^/]+/(.-)/pull/%d+$") .. "#" .. pr.number
    local state = states[pr.isDraft and pr.state == "OPEN" and "DRAFT" or pr.state]
    local style = styles[state and state[2] or "unknown"]
    local label = style[1] .. " " .. pr.state .. (pr.isDraft and " (draft)" or "")
    local highlights = {}
    local lines = {
        "# " .. pr.title,
        "",
        reference .. " | " .. label .. " | @" .. author,
        pr.headRefName .. " -> " .. pr.baseRefName,
        "",
        pr.url,
        "",
        "Actions: \\pc checkout | \\rp all PR changes | \\rP since last review | \\pv description | gx browser",
        "",
    }
    highlights[#highlights + 1] = {
        row = 2, col = #reference + 3, end_col = #reference + 3 + #label, group = style[2],
    }
    vim.b[buf].git_review_checks_fold = status_lines(pr, lines, highlights)
    vim.list_extend(lines, { "", "## Description", "" })
    vim.list_extend(lines, vim.split((pr.body or ""):gsub("\r\n", "\n"), "\n", { plain = true }))
    vim.bo[buf].modifiable = true
    vim.bo[buf].readonly = false
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    for _, highlight in ipairs(highlights) do
        vim.api.nvim_buf_set_extmark(buf, namespace, highlight.row, highlight.col, {
            end_col = highlight.end_col, hl_group = highlight.group, priority = 200,
        })
    end
    vim.bo[buf].modified = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    vim.bo[buf].filetype = "markdown"
    vim.keymap.set("n", "<Space>", "za", { buffer = buf, desc = "Toggle check details" })
    vim.keymap.set("n", "gx", function() vim.ui.open(pr.url) end, { buffer = buf, desc = "Open PR on GitHub" })
    vim.keymap.set("n", "q", function()
        local lifecycle = require("codediff.ui.lifecycle")
        if lifecycle.get_session(vim.api.nvim_get_current_tabpage()) then
            lifecycle.close()
        else
            Snacks.bufdelete(buf)
        end
    end, { buffer = buf, desc = "Close PR view" })
    for key, action in pairs({ j = "next_hunk", k = "prev_hunk", J = "next_file", K = "prev_file" }) do
        vim.keymap.set("n", "<localleader>" .. key, function()
            local _, win = require("codediff.ui.lifecycle").get_windows(vim.api.nvim_get_current_tabpage())
            if not win or not vim.api.nvim_win_is_valid(win) then
                vim.notify("Open PR changes with \\rp first", vim.log.levels.WARN)
                return
            end
            vim.api.nvim_set_current_win(win)
            require("codediff")[action]()
        end, { buffer = buf, desc = action:gsub("_", " ") })
    end
    return buf
end

local function configure_folds(win)
    vim.wo[win].foldexpr = "v:lua.require'git-review.description'.foldexpr(v:lnum)"
    vim.wo[win].foldmethod = "expr"
    vim.wo[win].foldtext = ""
    vim.wo[win].foldminlines = 0
    vim.wo[win].foldlevel = 0
    vim.wo[win].foldenable = true
end

local function configure_window(win)
    for option, value in pairs({
        diff = false, scrollbind = false, cursorbind = false,
        number = false, relativenumber = false, wrap = true,
        winfixheight = true,
    }) do
        vim.wo[win][option] = value
    end
    configure_folds(win)
    vim.w[win].codediff_restore = nil
end

function M.open(pr, root)
    local win = vim.api.nvim_get_current_win()
    -- Never replace a CodeDiff-owned pane with the overview.
    if require("codediff.ui.lifecycle").get_session(vim.api.nvim_get_current_tabpage()) then
        vim.cmd.tabnew()
        win = vim.api.nvim_get_current_win()
    end
    vim.api.nvim_win_set_buf(win, buffer(pr, root))
    configure_folds(win)
    require("git-review.workflow").set_target("pr", root, pr.url)
end

function M.attach(tab, pr, root)
    local lifecycle = require("codediff.ui.lifecycle")
    local panel = lifecycle.get_panel_view(tab)
    local view = views[tab] or {}
    view.pr, view.root = pr, root
    views[tab] = view
    local buf = buffer(pr, root)
    if view.win and vim.api.nvim_win_is_valid(view.win) and vim.api.nvim_win_get_buf(view.win) == view.buf then
        vim.api.nvim_win_set_buf(view.win, buf)
        configure_folds(view.win)
        view.buf = buf
        return
    end
    local anchor = panel and panel.winid
    if not anchor or not vim.api.nvim_win_is_valid(anchor) then
        local _, modified = lifecycle.get_windows(tab)
        anchor = modified
    end
    if not anchor or not vim.api.nvim_win_is_valid(anchor) then
        error("Could not find a pane for the PR description")
    end
    local height = math.max(4, math.min(16, math.floor(vim.api.nvim_win_get_height(anchor) / 2)))
    vim.api.nvim_win_call(anchor, function()
        vim.cmd("rightbelow " .. height .. "split")
        view.win = vim.api.nvim_get_current_win()
        view.buf = buf
        vim.api.nvim_win_set_buf(view.win, buf)
        configure_window(view.win)
    end)
end

function M.hide(tab)
    local view = M.view(tab)
    if view and view.win and vim.api.nvim_win_is_valid(view.win) and vim.api.nvim_win_get_buf(view.win) == view.buf then
        vim.api.nvim_win_close(view.win, true)
        view.win = nil
        return true
    end
    if view then
        view.win = nil
    end
    return false
end

function M.setup(group)
    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "CodeDiffClose",
        callback = function(args)
            local tab = args.data.tabpage
            M.hide(tab)
            views[tab] = nil
        end,
    })
    vim.api.nvim_create_autocmd("TabClosed", {
        group = group,
        callback = function()
            for tab in pairs(views) do
                if not vim.api.nvim_tabpage_is_valid(tab) then
                    views[tab] = nil
                end
            end
        end,
    })
end

return M
