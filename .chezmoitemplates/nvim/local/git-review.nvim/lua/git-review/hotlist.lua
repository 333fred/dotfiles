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
    latestOpinionatedReviews(first: 100) { pageInfo { hasNextPage } nodes { author { login } state } }
    reviews(first: 100) { pageInfo { hasNextPage } nodes { author { login } state } }
    comments(first: 100) { pageInfo { hasNextPage } nodes { author { login } } }]]

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

-- reviews: chronological { login, state }; comments: commenter logins.
function M.eligible(team, reviews, comments)
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

        local notifications = get("repos/{owner}/{repo}/notifications?all=false")
        if not notifications then
            return
        end
        local candidates, threads, seen, repo = {}, {}, {}, nil
        for _, thread in ipairs(notifications) do
            if thread.unread and thread.subject.type == "PullRequest" then
                repo = thread.repository.full_name
                candidates[#candidates + 1] = {
                    number = assert(tonumber(thread.subject.url:match("/pulls/(%d+)$"))),
                    time = thread.updated_at,
                }
            end
        end
        table.sort(candidates, function(a, b)
            return a.time == b.time and a.number < b.number or a.time < b.time
        end)
        for _, thread in ipairs(candidates) do
            if not seen[thread.number] then
                seen[thread.number] = true
                threads[#threads + 1] = thread
            end
        end
        if #threads == 0 then
            return
        end
        local owner, name = repo:match("^([^/]+)/(.+)$")

        local procs = {}
        for first = 1, #threads, batch_size do
            local parts = { "query($owner: String!, $name: String!) {", "repository(owner: $owner, name: $name) {" }
            for i = first, math.min(first + batch_size - 1, #threads) do
                parts[#parts + 1] = ("pr%d: pullRequest(number: %d) { %s %s }"):format(
                    threads[i].number, threads[i].number, pr_fields, filtered and activity_fields or "")
            end
            parts[#parts + 1] = "}"
            if filtered and first == 1 then
                parts[#parts + 1] = team_query
            end
            parts[#parts + 1] = "}"
            procs[#procs + 1] = start({
                "api", "graphql", "-f", "query=" .. table.concat(parts, "\n"),
                "-f", "owner=" .. owner, "-f", "name=" .. name,
            })
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
            return M.eligible(team, reviews, comments)
        end

        local function graph_eligible(pr)
            local opinions = pr.latestOpinionatedReviews
            if opinions.pageInfo.hasNextPage then
                return rest_eligible(pr.number)
            end
            local approvals, activity = 0, false
            for _, review in ipairs(opinions.nodes) do
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
            for _, comment in ipairs(pr.comments.nodes) do
                activity = activity or team[login(comment.author) or ""] or false
            end
            if activity then
                return false
            elseif pr.reviews.pageInfo.hasNextPage or pr.comments.pageInfo.hasNextPage then
                return rest_eligible(pr.number)
            end
            return true
        end

        for _, thread in ipairs(threads) do
            local pr = prs[thread.number]
            if pr and pr ~= vim.NIL and pr.state == "OPEN" then
                local include = true
                if filtered then
                    include = graph_eligible(pr)
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
