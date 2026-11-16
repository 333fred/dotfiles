-- Run with: nvim --headless -u NONE -l <path-to-this-file>
local plugin = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = plugin .. "/lua/?.lua;" .. plugin .. "/lua/?/init.lua;" .. package.path
local hotlist = require("git-review.hotlist")

local notifications_endpoint = "repos/{owner}/{repo}/notifications?all=false&per_page=100"
local base = "repos/example/repo"

local function connection(nodes, more)
    return { pageInfo = { hasNextPage = more or false }, nodes = nodes or {} }
end

local function fixture()
    local env = {
        responses = {}, requests = {}, graphql = {}, items = {}, errors = {}, refreshed = {},
        prs = {}, team = connection({ { login = "333fred" }, { login = "teammate" } }), pending = 0,
    }
    env.ctx = {
        git_root = function() return "/checkout" end,
        async = { schedule = function(_, fn) return fn() end },
    }
    env.responses[notifications_endpoint] = { {} }
    package.loaded["snacks.util.spawn"] = {
        new = function(opts)
            assert(opts.cmd == "gh" and opts.cwd == "/checkout")
            local args, data = opts.args, nil
            env.pending = env.pending + 1
            if args[2] == "graphql" then
                local query = args[4]:sub(#"query=" + 1)
                assert(args[6] == "owner=example" and args[8] == "name=repo")
                env.graphql[#env.graphql + 1] = { query = query, concurrent = env.pending }
                data = { data = { repository = {} } }
                for number in query:gmatch("pullRequest%(number: (%d+)%)") do
                    data.data.repository["pr" .. number] = env.prs[tonumber(number)] or vim.NIL
                end
                if query:find("roslyn-compiler", 1, true) then
                    data.data.organization = { team = { members = env.team } }
                end
                data = not env.graphql_failure and data
            else
                local endpoint = args[2]
                env.requests[#env.requests + 1] = endpoint
                assert(args[3] == "--paginate" and args[4] == "--slurp")
                data = env.responses[endpoint]
                assert(data ~= nil, "Unexpected request: " .. endpoint)
            end
            local proc = {}
            function proc:wait() env.pending = env.pending - 1 return self end
            function proc:failed() return data == false end
            function proc:json() return vim.deepcopy(data) end
            function proc:debug(o) env.errors[#env.errors + 1] = o end
            return proc
        end,
    }
    package.loaded["snacks.gh.item"] = {
        new = function(pr, opts)
            assert(opts.repo == "example/repo" and opts.type == "pr")
            return pr
        end,
    }
    package.loaded["snacks.gh.api"] = {
        refresh = function(item) env.refreshed[#env.refreshed + 1] = item end,
    }
    function env:add(number, time, state)
        local pages = self.responses[notifications_endpoint]
        pages[#pages + 1] = { {
            unread = true, updated_at = time, repository = { full_name = "example/repo" },
            subject = { type = "PullRequest", url = "https://api.github.com/" .. base .. "/pulls/" .. number },
        } }
        self.prs[number] = {
            number = number, state = state or "OPEN", title = "PR " .. number, isDraft = false,
            author = { login = "author" }, url = "https://github.com/example/repo/pull/" .. number,
            labels = connection({ { name = "Area-Compilers" } }),
            latestOpinionatedReviews = connection(), reviews = connection(), comments = connection(),
        }
        return self.prs[number]
    end
    function env:run(filtered)
        hotlist.finder({}, self.ctx, filtered)(function(item) self.items[#self.items + 1] = item end)
        local numbers = {}
        for _, item in ipairs(self.items) do
            numbers[#numbers + 1] = item.number
        end
        return numbers
    end
    return env
end

local function review(user, state)
    return { author = user and { login = user } or vim.NIL, state = state }
end
local function comment(user)
    return { author = { login = user } }
end

local env = fixture()
env:add(1, "2026-01-03T00:00:00Z")
env:add(2, "2026-01-01T00:00:00Z")
env:add(3, "2026-01-02T00:00:00Z", "CLOSED")
env:add(4, "2026-01-01T00:00:00Z")
env:add(2, "2026-01-04T00:00:00Z")
env.responses[notifications_endpoint][1] = {
    { unread = true, updated_at = "2026-01-01T00:00:00Z", subject = { type = "Issue" } },
    { unread = false, updated_at = "2026-01-01T00:00:00Z", subject = { type = "PullRequest" } },
}
assert(vim.deep_equal(env:run(false), { 2, 4, 1 }), "Unread open PRs must be deduplicated and sorted by notification time")
assert(#env.errors == 0 and #env.refreshed == 3 and #env.graphql == 1)
assert(env.items[1].notification_time == "2026-01-01T00:00:00Z")
assert(env.items[1].author.login == "author" and env.items[1].url == "https://github.com/example/repo/pull/2")
assert(env.items[1].labels[1].name == "Area-Compilers" and not env.items[1].isDraft)
assert(not env.graphql[1].query:find("reviews", 1, true) and not env.graphql[1].query:find("roslyn-compiler", 1, true),
    "Unfiltered notifications must not fetch team activity")

env = fixture()
for number = 1, 14 do
    env:add(number, string.format("2026-01-%02dT00:00:00Z", number))
end
env.prs[1].latestOpinionatedReviews = connection({ review("outsider", "APPROVED") })
env.prs[1].comments = connection({ comment("outsider") })
env.prs[2].latestOpinionatedReviews = connection({ review("333Fred", "APPROVED") })
env.prs[2].reviews = connection({ review("333fred", "APPROVED"), review("teammate", "COMMENTED") })
env.prs[3].latestOpinionatedReviews = connection({ review("333fred", "APPROVED"), review("teammate", "APPROVED") })
env.prs[4].reviews = connection({ review("333fred", "COMMENTED") })
env.prs[5].latestOpinionatedReviews = connection({ review("333fred", "CHANGES_REQUESTED") })
env.prs[6].reviews = connection({ review("333fred", "DISMISSED") })
env.prs[7].latestOpinionatedReviews = connection({ review("333fred", "APPROVED"), review("teammate", "CHANGES_REQUESTED") })
env.prs[8].reviews = connection({ review("333fred", "PENDING"), review(nil, "COMMENTED") })
env.prs[9].comments = connection({ comment("Teammate") })
env.prs[10].latestOpinionatedReviews = connection({ review("333fred", "APPROVED") }, true)
env.responses[base .. "/pulls/10/reviews?per_page=100"] = { {
    { user = { login = "333fred" }, state = "APPROVED" }, { user = { login = "teammate" }, state = "APPROVED" },
} }
env.responses[base .. "/issues/10/comments?per_page=100"] = { {} }
env.responses[base .. "/pulls/10/comments?per_page=100"] = { {} }
env.prs[11].reviews = connection({ review("outsider", "COMMENTED") }, true)
env.responses[base .. "/pulls/11/reviews?per_page=100"] = { {}, { { user = { login = "teammate" }, state = "COMMENTED" } } }
env.responses[base .. "/issues/11/comments?per_page=100"] = { {} }
env.responses[base .. "/pulls/11/comments?per_page=100"] = { {} }
env.prs[12].comments = connection({ comment("outsider") }, true)
env.responses[base .. "/pulls/12/reviews?per_page=100"] = { {} }
env.responses[base .. "/issues/12/comments?per_page=100"] = { {} }
env.responses[base .. "/pulls/12/comments?per_page=100"] = { {}, { { user = { login = "outsider" } } } }
env.prs[13].reviews = connection({ review("teammate", "COMMENTED") }, true)
env.prs[14].latestOpinionatedReviews = connection({ review("teammate", "APPROVED") })
env.prs[14].reviews = connection({}, true)
assert(vim.deep_equal(env:run(true), { 1, 2, 7, 8, 12, 14 }),
    "Include only no team activity or exactly one current team approver")
assert(#env.errors == 0)
for _, request in ipairs(env.requests) do
    assert(request == notifications_endpoint or request:find("/1[012]/"),
        "Only undecided PRs with truncated activity may use REST: " .. request)
end

env = fixture()
for number = 1, 26 do
    env:add(number, string.format("2026-01-01T00:00:%02dZ", number))
end
assert(#env:run(true) == 26 and #env.graphql == 2 and env.graphql[2].concurrent == 2,
    "PRs must be fetched in concurrent batches")
assert(env.graphql[1].query:find("roslyn-compiler", 1, true) and not env.graphql[2].query:find("roslyn-compiler", 1, true))

env = fixture()
env:add(1, "2026-01-01T00:00:00Z").comments = connection({ comment("member") })
env.team = connection({ { login = "333fred" } }, true)
env.responses["orgs/dotnet/teams/roslyn-compiler/members?per_page=100"] = { { { login = "333fred" } }, { { login = "member" } } }
assert(#env:run(true) == 0 and #env.errors == 0, "Large teams must be fully paginated")

for _, failure in ipairs({ notifications_endpoint, "graphql", base .. "/pulls/1/reviews?per_page=100" }) do
    env = fixture()
    env:add(1, "2026-01-01T00:00:00Z").reviews = connection({}, true)
    env.responses[base .. "/pulls/1/reviews?per_page=100"] = { {} }
    env.responses[base .. "/issues/1/comments?per_page=100"] = { {} }
    env.responses[base .. "/pulls/1/comments?per_page=100"] = { {} }
    if failure == "graphql" then
        env.graphql_failure = true
    else
        env.responses[failure] = false
    end
    assert(#env:run(true) == 0 and #env.errors == 1, "Failed requests must report errors: " .. failure)
end

env = fixture()
assert(#env:run(true) == 0 and #env.errors == 0 and #env.graphql == 0, "An empty inbox needs no PR lookup")

env = fixture()
env.ctx.git_root = function() end
local notify = vim.notify
vim.notify = function(message, level)
    assert(message:find("Git repository", 1, true) and level == vim.log.levels.ERROR)
    env.errors[#env.errors + 1] = message
end
assert(#env:run(true) == 0 and #env.requests == 0 and #env.errors == 1)
vim.notify = notify

local opts
Snacks = { picker = { gh_pr = function(value) opts = value end } }
for _, filtered in ipairs({ true, false }) do
    env = fixture()
    env:add(1, "2026-01-01T00:00:00Z").reviews = connection({ review("333fred", "COMMENTED") })
    hotlist.open(filtered)
    assert(not opts.live and opts.matcher.sort_empty)
    assert(vim.deep_equal(opts.sort.fields, { "notification_time", "number" }))
    opts.finder(opts, env.ctx)(function(item) env.items[#env.items + 1] = item end)
    assert(#env.items == (filtered and 0 or 1), "Picker must use the requested filter")
end

print("Hotlist tests passed")
