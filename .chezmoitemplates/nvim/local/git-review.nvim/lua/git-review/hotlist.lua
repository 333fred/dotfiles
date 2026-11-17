local M = {}
local fields = { "number", "title", "author", "url", "state", "isDraft", "labels" }
-- Keeps each GraphQL request well under GitHub's node and timeout limits.
local batch_size = 25
local team_query = [[
  organization(login: "dotnet") {
    team(slug: "roslyn-compiler") {
      members(first: 100) { pageInfo { hasNextPage } nodes { login } }
    }
  }]]
local pr_fields = [[
    number title url state isDraft
    author { login }
    labels(first: 20) { nodes { name color } }]]
-- Inline review comments always belong to a review, so reviews cover them.
-- latestOpinionatedReviews holds each reviewer's current approval state, so
-- long review histories rarely need paging.
local activity_fields = [[
    viewerReviews: reviews(author: $viewer, first: 1) {
      totalCount
    }
    latestOpinionatedReviews(first: 100) { pageInfo { hasNextPage } nodes { author { login } state } }
    reviews(first: 100) { pageInfo { hasNextPage } nodes { author { login } state } }
    comments(first: 100) { pageInfo { hasNextPage } nodes { author { login } } }
    timelineItems(last: 10, itemTypes: [
      ISSUE_COMMENT, PULL_REQUEST_REVIEW, PULL_REQUEST_COMMIT,
      HEAD_REF_FORCE_PUSHED_EVENT, READY_FOR_REVIEW_EVENT, REOPENED_EVENT
    ]) {
      nodes {
        ... on IssueComment { author { __typename login } createdAt }
        ... on PullRequestReview { author { __typename login } state createdAt submittedAt }
        ... on PullRequestCommit { commit { committedDate author { user { login } } } }
        ... on HeadRefForcePushedEvent { actor { __typename login } createdAt }
        ... on ReadyForReviewEvent { actor { __typename login } createdAt }
        ... on ReopenedEvent { actor { __typename login } createdAt }
      }
    }]]

function M.open(filtered)
    Snacks.picker.gh_pr({
        title = filtered and "PR notification hotlist" or "PR notifications",
        finder = function(opts, ctx)
            return M.finder(opts, ctx, filtered)
        end,
        live = false,
        sort = { fields = { "notification_time", "number" } },
        matcher = { sort_empty = true },
    })
end

local function login(user)
    return user and user ~= vim.NIL and user.login:lower() or nil
end

-- Bot activity and unsubmitted reviews do not need a response from the viewer.
local function last_actor(nodes)
    local latest, actor
    for _, node in ipairs(nodes) do
        local who, time = node.author or node.actor, node.submittedAt or node.createdAt
        if node.commit then
            local author = node.commit.author
            who = author ~= vim.NIL and author.user ~= vim.NIL and author.user or { login = "" }
            time = node.commit.committedDate
        end
        if node.state ~= "PENDING" and who and who ~= vim.NIL and who.__typename ~= "Bot"
            and (not latest or time >= latest) then
            latest, actor = time, who.login:lower()
        end
    end
    return actor
end

local function viewer_active(viewer, reviews, comments)
    for _, review in ipairs(reviews) do
        if review.login == viewer then
            return true
        end
    end
    return vim.tbl_contains(comments, viewer)
end

-- reviews: chronological { login, state }; comments: commenter logins.
function M.eligible(team, viewer, reviews, comments)
    if viewer_active(viewer, reviews, comments) then
        return true
    end
    local activity, decisions = false, {}
    for _, review in ipairs(reviews) do
        if review.state ~= "PENDING" and review.login and team[review.login] then
            activity = true
            -- Comment-only reviews do not revoke an existing approval.
            if review.state ~= "COMMENTED" then
                decisions[review.login] = review.state
            end
        end
    end
    local approvals = 0
    for _, state in pairs(decisions) do
        if state == "APPROVED" then
            approvals = approvals + 1
        end
    end
    if approvals > 0 then
        return approvals == 1
    elseif activity then
        return false
    end
    for _, commenter in ipairs(comments) do
        if commenter and team[commenter] then
            return false
        end
    end
    return true
end

function M.finder(_, ctx, filtered)
    local root = ctx:git_root()
    return function(cb)
        if not root then
            ctx.async:schedule(function()
                vim.notify("PR notifications require a Git repository", vim.log.levels.ERROR)
            end)
            return
        end

        local function start(args)
            return require("snacks.util.spawn").new({
                cmd = "gh", args = args, cwd = root, timeout = 60000,
            })
        end
        local function finish(proc)
            proc:wait()
            if proc:failed() then
                ctx.async:schedule(function()
                    proc:debug({ header = "PR notification hotlist", level = "error" })
                end)
                return nil
            end
            local data = proc:json()
            if type(data) == "table" and data.data then
                return data.data
            end
            return data
        end
        local function get(endpoint)
            endpoint = endpoint .. (endpoint:find("?", 1, true) and "&" or "?") .. "per_page=100"
            local pages = finish(start({ "api", endpoint, "--paginate", "--slurp" }))
            if not pages then
                return nil
            end
            local items = {}
            for _, page in ipairs(pages) do
                vim.list_extend(items, page)
            end
            return items
        end

        local user = filtered and start({ "api", "user" })
        local notifications = get("repos/{owner}/{repo}/notifications?all=true")
        if not notifications then
            return
        end
        local candidates, threads, seen, repo = {}, {}, {}, nil
        for _, thread in ipairs(notifications) do
            if thread.subject.type == "PullRequest" then
                repo = thread.repository.full_name
                candidates[#candidates + 1] = {
                    number = assert(tonumber(thread.subject.url:match("/pulls/(%d+)$"))),
                    time = thread.updated_at,
                    unread = thread.unread,
                }
            end
        end
        table.sort(candidates, function(a, b)
            return a.time == b.time and a.number < b.number or a.time < b.time
        end)
        for _, thread in ipairs(candidates) do
            local first = seen[thread.number]
            if first then
                first.unread = first.unread or thread.unread
            else
                seen[thread.number] = thread
                threads[#threads + 1] = thread
            end
        end
        if #threads == 0 then
            return
        end
        local owner, name = repo:match("^([^/]+)/(.+)$")
        local viewer
        if filtered then
            user = finish(user)
            if not user then
                return
            end
            viewer = user.login:lower()
        end

        local procs = {}
        for first = 1, #threads, batch_size do
            local parts = {
                filtered and "query($owner: String!, $name: String!, $viewer: String!) {"
                    or "query($owner: String!, $name: String!) {",
                "repository(owner: $owner, name: $name) {",
            }
            for i = first, math.min(first + batch_size - 1, #threads) do
                parts[#parts + 1] = ("pr%d: pullRequest(number: %d) { %s %s }"):format(
                    threads[i].number, threads[i].number, pr_fields, filtered and activity_fields or "")
            end
            parts[#parts + 1] = "}"
            if filtered and first == 1 then
                parts[#parts + 1] = team_query
            end
            parts[#parts + 1] = "}"
            local args = {
                "api", "graphql", "-f", "query=" .. table.concat(parts, "\n"),
                "-f", "owner=" .. owner, "-f", "name=" .. name,
            }
            if filtered then
                vim.list_extend(args, { "-f", "viewer=" .. viewer })
            end
            procs[#procs + 1] = start(args)
        end
        local prs, team_data = {}, nil
        for _, proc in ipairs(procs) do
            local data = finish(proc)
            if not data then
                return
            end
            team_data = team_data or data.organization
            for key, pr in pairs(data.repository) do
                prs[tonumber(key:sub(3))] = pr
            end
        end

        local team
        if filtered then
            local members = team_data and team_data ~= vim.NIL and team_data.team ~= vim.NIL
                and team_data.team.members
            if not members then
                ctx.async:schedule(function()
                    vim.notify("Could not read dotnet/roslyn-compiler members", vim.log.levels.ERROR)
                end)
                return
            end
            local nodes = members.nodes
            if members.pageInfo.hasNextPage then
                nodes = get("orgs/dotnet/teams/roslyn-compiler/members")
                if not nodes then
                    return
                end
            end
            team = {}
            for _, member in ipairs(nodes) do
                team[member.login:lower()] = true
            end
        end

        local function rest_eligible(number)
            local base = "repos/" .. repo
            local raw_reviews = get(base .. "/pulls/" .. number .. "/reviews")
            local issue_comments = raw_reviews and get(base .. "/issues/" .. number .. "/comments")
            local review_comments = issue_comments and get(base .. "/pulls/" .. number .. "/comments")
            if not review_comments then
                return nil
            end
            local reviews, comments = {}, {}
            for _, review in ipairs(raw_reviews) do
                reviews[#reviews + 1] = { login = login(review.user), state = review.state }
            end
            for _, comment in ipairs(vim.list_extend(issue_comments, review_comments)) do
                comments[#comments + 1] = login(comment.user)
            end
            return M.eligible(team, viewer, reviews, comments)
        end

        local function graph_eligible(pr)
            local comments = {}
            for _, comment in ipairs(pr.comments.nodes) do
                comments[#comments + 1] = login(comment.author)
            end
            if pr.viewerReviews.totalCount > 0 or vim.tbl_contains(comments, viewer) then
                return true
            elseif pr.comments.pageInfo.hasNextPage or pr.latestOpinionatedReviews.pageInfo.hasNextPage then
                return rest_eligible(pr.number)
            end
            local approvals, activity = 0, false
            for _, review in ipairs(pr.latestOpinionatedReviews.nodes) do
                if team[login(review.author) or ""] then
                    activity = true
                    if review.state == "APPROVED" then
                        approvals = approvals + 1
                    end
                end
            end
            if approvals > 0 then
                return approvals == 1
            end
            for _, review in ipairs(pr.reviews.nodes) do
                activity = activity or review.state ~= "PENDING" and team[login(review.author) or ""] or false
            end
            for _, commenter in ipairs(comments) do
                activity = activity or team[commenter or ""] or false
            end
            if activity then
                return false
            elseif pr.reviews.pageInfo.hasNextPage then
                return rest_eligible(pr.number)
            end
            return true
        end

        for _, thread in ipairs(threads) do
            local pr = prs[thread.number]
            if pr and pr ~= vim.NIL and pr.state == "OPEN" then
                local include = true
                if filtered then
                    include = (thread.unread or last_actor(pr.timelineItems.nodes) ~= viewer)
                        and graph_eligible(pr)
                end
                if include == nil then
                    return
                elseif include then
                    ctx.async:schedule(function()
                        local item = require("snacks.gh.item").new({
                            number = pr.number, title = pr.title, author = pr.author,
                            url = pr.url, state = pr.state, isDraft = pr.isDraft, labels = pr.labels.nodes,
                        }, { type = "pr", repo = repo, fields = fields, text = { "number", "title", "author", "labels" } })
                        item.notification_time = thread.time
                        require("snacks.gh.api").refresh(item)
                        cb(item)
                    end)
                end
            end
        end
    end
end

return M
