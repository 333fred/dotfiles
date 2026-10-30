-- Run from the repository root: nvim --headless -u NONE -l config/.config/nvim/local/git-review.nvim/tests/workflow.lua
local plugin = vim.fn.getcwd() .. "/config/.config/nvim/local/git-review.nvim"
package.path = plugin .. "/lua/?.lua;" .. plugin .. "/lua/?/init.lua;" .. package.path

local cases = 0
local function fixture()
    cases = cases + 1
    package.loaded["git-review"] = nil
    package.loaded["git-review.workflow"] = nil
    local env = {
        root = vim.fn.getcwd(), branch = "feature", head = string.rep("a", 40),
        notices = {}, actions = {}, requests = {}, commands = {}, confirmations = {},
    }
    env.pr = {
        number = 1, url = "https://github.com/example/repo/pull/1",
        headRefOid = env.head, baseRefOid = string.rep("b", 40), headRefName = env.branch,
    }
    vim.cmd.tabnew()
    env.buf = vim.api.nvim_get_current_buf()
    env.file = env.root .. "/review-workflow-test-" .. cases .. ".lua"
    vim.api.nvim_buf_set_name(env.buf, env.file)
    vim.api.nvim_buf_set_lines(env.buf, 0, -1, false, { "one", "two", "three", "four", "five" })
    vim.bo.modified = false
    vim.notify = function(message) env.notices[#env.notices + 1] = message end
    vim.ui.select = function(items, opts, callback)
        if opts.format_item then
            env.picker = { items = items, opts = opts, callback = callback }
        else
            env.confirmations[#env.confirmations + 1] = { prompt = opts.prompt, callback = callback }
        end
    end
    vim.system = function(command)
        local result = { code = 0, stdout = "", stderr = "" }
        local text = table.concat(command, " ")
        if command[1] == "git" then
            if command[2] == "rev-parse" then
                result.stdout = env.root .. "\n" .. env.branch .. "\n"
            elseif command[4] == "rev-parse" then
                result.stdout = env.head .. "\n" .. env.branch .. "\n"
            elseif command[4] == "show" then
                result.stdout = "one\ntwo\nthree\nfour\nfive\n"
            elseif command[4] == "diff" then
                result.code = env.dirty and 1 or 0
            else
                error("Unexpected Git command: " .. text)
            end
        elseif command[1] == "gh" then
            env.requests[#env.requests + 1] = command
            if command[2] == "pr" then
                if env.missing_pr then
                    result.code, result.stderr = 1, "no pull requests found"
                else
                    result.stdout = vim.json.encode(env.pr)
                end
            elseif command[2] == "repo" then
                result.stdout = "https://github.com/example/repo\n"
            elseif command[3] == "graphql" then
                result.stdout = vim.json.encode({ {
                    data = { repository = { pullRequest = { latestOpinionatedReviews = { nodes = {} } } } },
                } })
            else
                error("Unexpected GitHub command: " .. text)
            end
        else
            error("Unexpected external command: " .. text)
        end
        return { wait = function() return result end }
    end
    package.loaded["async"] = {
        await = function(_, fn, ...) return fn(...):wait() end,
    }
    package.loaded["ghlite.task"] = {
        run = function(callback) return callback() end,
    }
    package.loaded["ghlite.ui"] = {
        schedule = function()
            if env.on_schedule then
                local callback = env.on_schedule
                env.on_schedule = nil
                callback()
            end
        end,
    }
    package.loaded["ghlite.system"] = {
        run_result = function(command)
            assert(command[1] == "git" and command[4] == "cat-file")
            return { code = 0 }
        end,
    }
    package.loaded["git-review.description"] = { view = function() end }
    env.load_snapshot = function(buf)
        local function finish()
            if not vim.api.nvim_buf_is_valid(buf) then
                return
            end
            vim.bo[buf].modifiable = true
            vim.bo[buf].readonly = false
            vim.api.nvim_buf_set_lines(buf, 0, -1, false,
                env.snapshot_lines or { "one", "two", "three", "four", "five" })
            vim.bo[buf].modified = false
            vim.bo[buf].modifiable = false
            vim.bo[buf].readonly = true
            vim.api.nvim_exec_autocmds("User", {
                pattern = "CodeDiffVirtualFileLoaded", data = { buf = buf },
            })
        end
        if env.hold_snapshots then
            env.finish_snapshot = finish
        else
            vim.schedule(finish)
        end
    end
    package.loaded["codediff.core.virtual_file"] = {
        parse_url = function() end,
        create_url = function(root, revision, path)
            return "codediff://" .. root .. "/" .. revision .. "/" .. path
        end,
        refresh_buffer = function(buf) env.load_snapshot(buf) end,
    }
    vim.api.nvim_create_autocmd("BufReadCmd", {
        group = vim.api.nvim_create_augroup("ReviewWorkflowTestSnapshots", { clear = true }),
        pattern = "codediff://*",
        callback = function(args)
            vim.bo[args.buf].buftype = "nowrite"
            vim.bo[args.buf].bufhidden = "wipe"
            env.load_snapshot(args.buf)
        end,
    })
    package.loaded["ghlite.config"] = { s = {} }
    package.loaded["ghlite.gh"] = {}
    local state = { comments_list = {} }
    package.loaded["ghlite.state"] = state
    package.loaded["ghlite.utils"] = {
        get_comment = function(_, _, _, _, _, send)
            vim.cmd.new()
            vim.bo.buftype = "nofile"
            env.send = send
        end,
    }
    local comments = {
        load_comments_only = function(number)
            state.comments_pr_number = number
            if env.no_comments then
                state.comments_list = {}
                return
            end
            state.comments_list = {
                [env.file] = { {
                    line = 3, content = "Review this line",
                    comments = { { user = "reviewer", body = "Review this line" } },
                } },
            }
        end,
        load_comments_on_buffer = function() end,
        load_comments_on_visible_buffers = function()
            require("ghlite.comments").load_comments_on_buffer(env.buf)
        end,
    }
    for _, action in ipairs({ "comment_on_line", "update_comment", "delete_comment", "resolve_comment", "unresolve_comment" }) do
        comments[action] = function()
            env.actions[#env.actions + 1] = action
            if action == "comment_on_line" or action == "update_comment" then
                require("ghlite.utils").get_comment(nil, nil, nil, nil, nil, function(input)
                    env.posted = input
                end)
            end
        end
    end
    package.loaded["ghlite.comments"] = comments
    for _, command in ipairs({ "GHLitePRStartReview", "GHLitePRSubmitReview", "GHLitePRApprove", "GHLitePRDiscardReview" }) do
        vim.api.nvim_create_user_command(command, function()
            env.commands[#env.commands + 1] = command
        end, { force = true })
    end
    env.workflow = require("git-review.workflow")
    env.workflow.setup()
    env.review = require("git-review")
    env.review.setup_ghlite()
    return env
end

local function check_notice(env, text)
    assert(env.notices[#env.notices] and env.notices[#env.notices]:find(text, 1, true),
        vim.inspect(env.notices))
end

local env = fixture()
env.workflow.comment("toggle")
assert(env.workflow.target().implicit and env.workflow.valid(env.workflow.target()))
vim.wait(10)
assert(#vim.diagnostic.get(env.buf) == 1, "Standalone toggle must render comments")
vim.api.nvim_win_set_cursor(0, { 3, 0 })
env.workflow.comment("open")
assert(vim.api.nvim_get_current_buf() ~= env.buf, "Standalone open must display the comment")
vim.cmd.close()
local requests = #env.requests
env.workflow.comment("toggle")
check_notice(env, "PR comments hidden")
assert(#env.requests == requests, "Hiding annotations must not require a GitHub request")

env = fixture()
vim.fn.setqflist({}, " ", { title = "Unrelated list", items = {} })
env.workflow.comment("list")
assert(#env.picker.items == 1 and env.picker.items[1].lnum == 3)
local label = env.picker.opts.format_item(env.picker.items[1])
assert(label:find("review%-workflow%-test") and label:find("Review this line", 1, true))
assert(vim.fn.getqflist({ title = 0 }).title == "Unrelated list", "Picker must not replace quickfix")
env.picker.callback(env.picker.items[1])
assert(vim.api.nvim_buf_get_name(0) == env.picker.items[1].filename)
assert(vim.api.nvim_win_get_cursor(0)[1] == 1, "Cursor must wait for the asynchronous snapshot loader")
assert(vim.wait(1000, function() return vim.api.nvim_win_get_cursor(0)[1] == 3 end))
assert(vim.bo.readonly and not vim.bo.modifiable)
vim.api.nvim_set_current_buf(env.buf)
env.workflow.comment("list_window")
assert(vim.fn.getqflist({ title = 0 }).title == "PR review comments")
assert(#vim.fn.getqflist() == 1 and vim.fn.getqflist()[1].lnum == 3)
local list_win = vim.fn.getqflist({ winid = 0 }).winid
vim.cmd.wincmd("p")
assert(vim.api.nvim_win_is_valid(list_win), "Persistent list must stay open when focus leaves it")
vim.cmd.cclose()
env.workflow.comment("yank")
assert(vim.fn.getreg("+"):find("Review this line", 1, true))
vim.api.nvim_win_set_cursor(0, { 1, 0 })
env.workflow.comment("next")
assert(vim.api.nvim_win_get_cursor(0)[1] == 3)
vim.api.nvim_win_set_cursor(0, { 5, 0 })
env.workflow.comment("prev")
assert(vim.api.nvim_win_get_cursor(0)[1] == 3)

env = fixture()
env.hold_snapshots = true
env.workflow.comment("list")
env.picker.callback(env.picker.items[1])
assert(vim.api.nvim_buf_line_count(0) == 1)
vim.api.nvim_exec_autocmds("User", {
    pattern = "CodeDiffVirtualFileLoaded", data = { buf = env.buf },
})
assert(vim.api.nvim_win_get_cursor(0)[1] == 1)
env.finish_snapshot()
assert(vim.api.nvim_win_get_cursor(0)[1] == 3)
assert(#vim.api.nvim_get_autocmds({ group = "GitReviewCommentJump" }) == 0)
vim.api.nvim_win_set_cursor(0, { 1, 0 })
env.workflow.comment("list")
env.picker.callback(env.picker.items[1])
assert(vim.api.nvim_win_get_cursor(0)[1] == 1)
env.finish_snapshot()
assert(vim.api.nvim_win_get_cursor(0)[1] == 3, "Already-loaded snapshots must still jump correctly")

env = fixture()
env.hold_snapshots = true
env.workflow.comment("list")
env.picker.callback(env.picker.items[1])
vim.api.nvim_set_current_buf(env.buf)
env.finish_snapshot()
assert(vim.api.nvim_get_current_buf() == env.buf and vim.api.nvim_win_get_cursor(0)[1] == 1)
assert(#vim.api.nvim_get_autocmds({ group = "GitReviewCommentJump" }) == 0)

env = fixture()
env.hold_snapshots = true
env.workflow.comment("list")
env.picker.callback(env.picker.items[1])
env.branch = "another-branch"
env.finish_snapshot()
assert(vim.api.nvim_win_get_cursor(0)[1] == 1)
check_notice(env, "Checkout or PR changed; reopen the comment picker")

env = fixture()
env.snapshot_lines = { "" }
env.workflow.comment("list")
env.picker.callback(env.picker.items[1])
assert(vim.wait(1000, function() return #env.notices > 0 end))
check_notice(env, "PR snapshot has no line 3")
assert(#vim.api.nvim_get_autocmds({ group = "GitReviewCommentJump" }) == 0)

env = fixture()
env.workflow.comment("list")
env.branch = "another-branch"
env.picker.callback(env.picker.items[1])
assert(vim.api.nvim_get_current_buf() == env.buf)
check_notice(env, "Checkout or PR changed; reopen the comment picker")

env = fixture()
env.workflow.comment("list")
env.picker.callback(nil)
assert(vim.api.nvim_get_current_buf() == env.buf)

env = fixture()
env.no_comments = true
env.workflow.comment("list")
assert(not env.picker)
check_notice(env, "No PR comments")
env.workflow.comment("list_window")
check_notice(env, "No PR comments")

for _, action in ipairs({ "add", "edit" }) do
    env = fixture()
    env.workflow.comment(action)
    assert(env.send and env.workflow.valid(env.workflow.target()))
    env.send("Draft without an open review")
    assert(env.posted == "Draft without an open review", "Standalone drafts must have a valid PR target")
    env.branch = "another-branch"
    env.send("Retain this draft")
    assert(env.posted == "Draft without an open review")
    check_notice(env, "Not sent")
    assert(vim.api.nvim_get_current_line() == "Retain this draft")
end

for _, action in ipairs({ "delete", "resolve", "unresolve" }) do
    env = fixture()
    env.workflow.comment(action)
    if action == "delete" then
        assert(#env.actions == 0 and #env.confirmations == 1)
        env.confirmations[1].callback("Confirm")
    end
    assert(#env.actions == 1)
end

for _, action in ipairs({ "start", "submit", "approve", "discard" }) do
    env = fixture()
    env.workflow.review(action)
    if action == "discard" then
        assert(#env.commands == 0 and #env.confirmations == 1)
        env.confirmations[1].callback("Confirm")
    end
    assert(#env.commands == 1 and env.workflow.valid(env.workflow.target()))
end

env = fixture()
env.workflow.comment("delete")
env.branch = "another-branch"
env.confirmations[1].callback("Confirm")
assert(#env.actions == 0)
check_notice(env, "Review or active pane changed")

env = fixture()
env.workflow.comment("delete")
env.dirty = true
env.confirmations[1].callback("Confirm")
assert(#env.actions == 0)
check_notice(env, "PR comments require no tracked changes")

env = fixture()
env.workflow.review("discard")
env.head = string.rep("c", 40)
env.confirmations[1].callback("Confirm")
assert(#env.commands == 0)
check_notice(env, "Checkout or PR changed")

env = fixture()
env.workflow.comment("delete")
env.confirmations[1].callback("Cancel")
assert(#env.actions == 0)

env = fixture()
env.workflow.set_target("pr", env.root, env.pr.url)
env.workflow.comment("toggle")
assert(not env.workflow.target().implicit)
assert(env.requests[1][4] == env.pr.url, "Explicit PR selections must be preserved")

env = fixture()
env.workflow.comment("toggle")
env.branch, env.pr.headRefName = "another-branch", "another-branch"
env.pr.number, env.pr.url = 2, "https://github.com/example/repo/pull/2"
env.workflow.comment("toggle")
assert(env.workflow.target().url == env.pr.url and env.workflow.target().branch == env.branch)
check_notice(env, "PR comments enabled")
assert(env.requests[4][4] == "--json", "Implicit targets must rediscover the checked-out branch's PR")

env = fixture()
env.missing_pr = true
env.workflow.comment("toggle")
assert(not env.workflow.target())
check_notice(env, "Could not resolve the current branch's PR")

env = fixture()
env.dirty = true
env.workflow.comment("add")
assert(not env.send)
check_notice(env, "PR comments require no tracked changes")
env.workflow.comment("toggle")
assert(env.workflow.target(), "Read-only comment actions must still work with local changes")

env = fixture()
env.on_schedule = function() env.branch = "another-branch" end
env.workflow.comment("toggle")
assert(not env.workflow.target())
check_notice(env, "active pane or checkout changed")

env = fixture()
env.on_schedule = function() env.workflow.set_target("local", env.root) end
env.workflow.comment("toggle")
assert(env.workflow.target().kind == "local")
check_notice(env, "Review target changed")

env = fixture()
package.loaded["lazy"] = { load = function() end }
local renders = 0
package.loaded["review.marks"] = {
    clear_all = function() end, refresh = function() end,
    render_plain_buffer = function() renders = renders + 1 end,
}
package.loaded["review.store"] = {
    reset = function() end, load = function() end, get_all = function() return {} end,
}
package.loaded["review.reviewed"] = { reset = function() end }
package.loaded["review.comments"] = {}
package.loaded["codediff.ui.lifecycle"] = { get_session = function() end }
env.workflow.set_target("local", env.root)
env.workflow.comment("list")
assert(#env.requests == 0)
check_notice(env, "No local comments")
env.workflow.comment("toggle")
env.workflow.comment("toggle")
assert(renders == 1 and #env.requests == 0)
env.workflow.review("start")
check_notice(env, "Local feedback round ready")
assert(#env.requests == 0)
local local_comments = {
    { file = vim.fs.relpath(env.root, env.file), line = 3, side = "old", text = "Local line comment" },
    { file = vim.fs.relpath(env.root, env.file), line = 0, text = "File comment" },
}
package.loaded["review.store"].get_all = function() return local_comments end
env.workflow.comment("list")
assert(#env.picker.items == 2 and env.picker.opts.format_item(local_comments[1]):find("Pending", 1, true))
env.picker.callback(local_comments[1])
assert(vim.api.nvim_get_current_line():find("[Pending]", 1, true))
vim.cmd.close()
env.workflow.comment("list_window")
local local_list = vim.fn.getqflist()
assert(vim.fn.getqflist({ title = 0 }).title == "Local review comments")
assert(#local_list == 2 and local_list[1].lnum == 1 and local_list[2].lnum == 3)
assert(local_list[2].text:find("~3", 1, true) and local_list[2].text:find("Local line comment", 1, true))
assert(vim.api.nvim_buf_get_name(local_list[2].bufnr) == env.file)
vim.cmd.cclose()
assert(#env.requests == 0)
env.branch = "another-branch"
env.workflow.comment("toggle")
assert(#env.requests == 0)
check_notice(env, "Repository or branch changed")

print("Passed " .. cases .. " standalone PR workflow scenarios")
