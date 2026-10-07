local M = {}
local views = {}

function M.view(tab)
    return views[tab or vim.api.nvim_get_current_tabpage()]
end

local function reported(value, fallback)
    return type(value) == "string" and value ~= "" and value or (fallback or "Unknown")
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

local function status_lines(pr)
    local counts = { passing = 0, failing = 0, pending = 0, neutral = 0, skipped = 0, cancelled = 0, unknown = 0 }
    local checks = {}
    for _, check in ipairs(type(pr.statusCheckRollup) == "table" and pr.statusCheckRollup or {}) do
        local state = check_state(check)
        local bucket = check_buckets[state] or "unknown"
        counts[bucket] = counts[bucket] + 1
        local name = reported(check.name or check.context, "Unnamed check")
        if type(check.workflowName) == "string" and check.workflowName ~= "" then
            name = check.workflowName .. " / " .. name
        end
        checks[#checks + 1] = "- " .. name .. ": " .. state
    end
    local summary = pr.statusCheckRollup == nil and "Unavailable" or "None reported"
    if #checks > 0 then
        local parts = {}
        for _, bucket in ipairs({ "passing", "failing", "pending", "neutral", "skipped", "cancelled", "unknown" }) do
            if counts[bucket] > 0 then
                parts[#parts + 1] = counts[bucket] .. " " .. bucket
            end
        end
        summary = table.concat(parts, ", ")
    end
    local auto_merge = pr.autoMergeRequest == vim.NIL and "Disabled" or "Unknown"
    if type(pr.autoMergeRequest) == "table" then
        auto_merge = "Enabled (" .. reported(pr.autoMergeRequest.mergeMethod) .. ")"
    end
    local lines = {
        "## PR status",
        "",
        "Review/signoff: " .. reported(pr.reviewDecision, "No decision reported"),
        "Checks: " .. summary,
        "Merge conflicts: " .. (({ MERGEABLE = "None", CONFLICTING = "Present" })[pr.mergeable or ""] or "Unknown"),
        "Merge readiness: " .. reported(pr.mergeStateStatus),
        "Auto-merge: " .. auto_merge,
        ("Changes: %s files (+%s / -%s)"):format(
            pr.changedFiles or "Unknown", pr.additions or "Unknown", pr.deletions or "Unknown"),
        "Awaiting review: " .. names(pr.reviewRequests, "@"),
        "Assignees: " .. names(pr.assignees, "@"),
        "Labels: " .. names(pr.labels),
        "Created: " .. reported(pr.createdAt),
        "Updated: " .. reported(pr.updatedAt),
        "",
        "### Latest reviews",
        "",
    }
    if type(pr.latestReviews) ~= "table" then
        lines[#lines + 1] = "Unavailable"
    elseif #pr.latestReviews == 0 then
        lines[#lines + 1] = "None submitted"
    else
        for _, review in ipairs(pr.latestReviews) do
            local author = type(review.author) == "table" and reported(review.author.login, "unknown") or "unknown"
            lines[#lines + 1] = "- @" .. author .. ": " .. reported(review.state)
        end
        if #pr.latestReviews == 100 then
            lines[#lines + 1] = "First 100 reviewers shown; more may exist."
        end
    end
    if #checks > 0 then
        vim.list_extend(lines, { "", "### Checks", "" })
        vim.list_extend(lines, checks)
    end
    return lines
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
    local lines = {
        "# " .. pr.title,
        "",
        pr.url:match("^https://[^/]+/(.-)/pull/%d+$") .. "#" .. pr.number
            .. " | " .. pr.state .. (pr.isDraft and " (draft)" or "") .. " | @" .. author,
        pr.headRefName .. " -> " .. pr.baseRefName,
        "",
        pr.url,
        "",
        "Actions: \\C checkout | \\p PR changes | \\S since last review | \\v description | gx browser",
        "",
    }
    vim.list_extend(lines, status_lines(pr))
    vim.list_extend(lines, { "", "## Description", "" })
    vim.list_extend(lines, vim.split((pr.body or ""):gsub("\r\n", "\n"), "\n", { plain = true }))
    vim.bo[buf].modifiable = true
    vim.bo[buf].readonly = false
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modified = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    vim.bo[buf].filetype = "markdown"
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
                vim.notify("Open PR changes with \\p first", vim.log.levels.WARN)
                return
            end
            vim.api.nvim_set_current_win(win)
            require("codediff")[action]()
        end, { buffer = buf, desc = action:gsub("_", " ") })
    end
    return buf
end

local function configure_window(win)
    for option, value in pairs({
        diff = false, scrollbind = false, cursorbind = false,
        number = false, relativenumber = false, wrap = true,
        foldenable = false, winfixheight = true,
    }) do
        vim.wo[win][option] = value
    end
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
