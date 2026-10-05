local M = {}

local function in_since_range(review)
    local range = review and review.since_review
    return range and review.layout
        and review.layout.left.commit == range.left
        and review.layout.right.commit == range.right
end

local function fail(message)
    vim.notify("Review since: " .. message, vim.log.levels.ERROR)
end

local function git(root, args)
    local command = { "git", "-C", root }
    vim.list_extend(command, args)
    local result = vim.system(command, { text = true }):wait()
    if result.code ~= 0 then
        fail(vim.trim(result.stderr))
        return
    end
    return result.stdout
end

local function read_file(root, commit, path)
    local output = git(root, { "show", commit .. ":" .. path })
    if not output then
        return
    end
    return vim.split(output:gsub("\n$", ""), "\n", { plain = true })
end

local function checkout_matches(root, head)
    if not require("plugins.octo.review").checkout_is_clean(root) then
        return false
    end
    local current_head = git(root, { "rev-parse", "HEAD" })
    if not current_head then
        return false
    end
    if vim.trim(current_head) ~= head then
        fail("Checkout changed while loading the diff; run the command again")
        return false
    end
    return true
end

local function changed_files(root, pr, left, right)
    local output = git(root, {
        "diff", "--no-ext-diff", "--no-textconv", "--name-status", "-z", "-M", left, right, "--",
    })
    if not output then
        return
    end
    local fields = vim.split(output, "\0", { plain = true, trimempty = true })
    local files = {}
    local i = 1
    while i <= #fields do
        local status, path = fields[i]:sub(1, 1), fields[i + 1]
        local previous_path
        i = i + 2
        if status == "R" or status == "C" then
            previous_path, path = path, fields[i]
            i = i + 1
        end
        local args = {
            "diff", "--no-ext-diff", "--no-textconv", "--no-color", "-M", "--unified=3", left, right,
            "--", ":(literal)" .. path,
        }
        if previous_path then
            args[#args + 1] = ":(literal)" .. previous_path
        end
        local diff = git(root, args)
        if not diff then
            return
        end
        local patch = diff:match("\n(@@ .*)")
        local additions, deletions = 0, 0
        for line in (patch or ""):gmatch("[^\n]+") do
            if line:sub(1, 1) == "+" then
                additions = additions + 1
            elseif line:sub(1, 1) == "-" then
                deletions = deletions + 1
            end
        end
        local binary = diff:find("\nBinary files ", 1, true) ~= nil
        local file = require("octo.reviews.file-entry").FileEntry:new({
            path = path,
            previous_path = previous_path,
            pull_request = pr,
            status = status,
            patch = patch,
            stats = { additions = additions, deletions = deletions, changes = additions + deletions },
            left_binary = binary,
            right_binary = binary,
        })
        file.left_lines = (binary or status == "A") and {} or read_file(root, left, previous_path or path)
        file.right_lines = (binary or status == "D") and {} or read_file(root, right, path)
        if not file.left_lines or not file.right_lines then
            return
        end
        file.left_fetched, file.right_fetched = true, true
        -- Both snapshots are already loaded, including absent sides of added/deleted files.
        file.fetch = function() end
        files[#files + 1] = file
    end
    return files
end

local function api(endpoint, options, callback)
    local gh = require("octo.gh")
    gh.api.get(vim.tbl_extend("force", { endpoint }, options, {
        opts = { cb = gh.create_callback({
            success = function(output)
                callback(vim.json.decode(output))
            end,
            failure = fail,
        }) },
    }))
end

local function show_range(root, pr, review, left, right, files)
    local Rev = require("octo.reviews.rev").Rev
    local Layout = require("octo.reviews.layout").Layout
    pr.right = Rev:new(right)
    review = review or require("octo.reviews").Review:new(pr)
    if not review.since_review then
        local get_level = review.get_level
        review.get_level = function(self)
            return in_since_range(self) and "PR" or get_level(self)
        end
        local add_comment = review.add_comment
        review.add_comment = function(self, suggestion)
            local split = require("octo.utils").get_split_and_path(vim.api.nvim_get_current_buf())
            if in_since_range(self) and split == "LEFT" then
                fail("The historical side is read-only; comment on the current head on the right")
                return
            end
            add_comment(self, suggestion)
        end
    end
    review.since_review = { left = left, right = right }
    -- Start/resume must retain this range instead of restoring the full PR diff.
    review.initiate = function(self)
        if not checkout_matches(root, right) then
            return
        end
        if self.layout and vim.api.nvim_tabpage_is_valid(self.layout.tabpage)
            and self.layout.left.commit == left and self.layout.right.commit == right then
            self.layout:ensure_layout()
            self.layout:update_files()
            return
        end
        if self.layout then
            require("octo.reviews").reviews[tostring(self.layout.tabpage)] = nil
            self.layout:close()
        end
        self.layout = Layout:new({
            left = Rev:new(left),
            right = Rev:new(right),
            files = {},
        })
        self.layout:open(self)
        vim.cmd.lcd(root)
        self:set_files_and_select_first(files)
    end
    review:initiate()
end

local function open_range(pr, review)
    local root_output = git(vim.fn.getcwd(), { "rev-parse", "--show-toplevel" })
    if not root_output then
        return
    end
    local root = vim.trim(root_output)
    local cwd = vim.fn.getcwd()
    local tab = vim.api.nvim_get_current_tabpage()
    local function still_current()
        if vim.api.nvim_get_current_tabpage() ~= tab or vim.fn.getcwd() ~= cwd then
            fail("The review tab or working directory changed; run the command again")
            return false
        end
        return true
    end
    local endpoint = "repos/" .. pr.repo .. "/pulls/" .. pr.number
    api("user", {}, function(user)
        api(endpoint .. "/reviews?per_page=100", { paginate = true, slurp = true }, function(pages)
            local latest
            for _, page in ipairs(pages) do
                for _, submitted in ipairs(page) do
                    if submitted.user.login == user.login and submitted.state ~= "PENDING"
                        and type(submitted.submitted_at) == "string"
                        and (not latest or submitted.submitted_at >= latest.submitted_at) then
                        latest = submitted
                    end
                end
            end
            if not latest or type(latest.commit_id) ~= "string" then
                fail("No submitted review with a commit was found for " .. user.login)
                return
            end
            api(endpoint, {}, function(remote_pr)
                if not still_current() or not require("plugins.octo.review").checkout_is_clean(root) then
                    return
                end
                local head = remote_pr.head.sha
                local local_head = git(root, { "rev-parse", "HEAD" })
                if not local_head then
                    return
                end
                if vim.trim(local_head) ~= head then
                    fail("Checkout is not at the current PR head; run gh pr checkout "
                        .. pr.number .. " --repo " .. pr.repo .. " and retry")
                    return
                end
                if head == latest.commit_id then
                    vim.notify("No changes since your last review", vim.log.levels.INFO)
                    return
                end
                local function load()
                    if not still_current() or not checkout_matches(root, head) then
                        return
                    end
                    local files = changed_files(root, pr, latest.commit_id, head)
                    if not files then
                        return
                    end
                    if #files == 0 then
                        vim.notify("No file changes since your last review", vim.log.levels.INFO)
                        return
                    end
                    local target = review or require("octo.reviews").Review:new(pr)
                    pr:get_changed_files(function(pr_files)
                        local by_path = {}
                        for _, file in ipairs(pr_files) do
                            by_path[file.path] = file
                        end
                        for _, file in ipairs(files) do
                            local original = by_path[file.path]
                            -- GitHub comments use the full PR's RIGHT coordinates, not delta positions.
                            file.left_comment_ranges = {}
                            file.right_comment_ranges = original and original.right_comment_ranges or {}
                            file.diffhunks = original and original.diffhunks or {}
                            if not original then
                                file.toggle_viewed = function()
                                    fail("This file is absent from the current PR diff and cannot be marked viewed")
                                end
                            end
                        end
                        target:populate_threads(function(response)
                            if still_current() and checkout_matches(root, head) then
                                target:update_threads(response.data.repository.pullRequest.reviewThreads.nodes)
                                show_range(root, pr, target, latest.commit_id, head, files)
                            end
                        end)
                    end)
                end
                local exists = vim.system({
                    "git", "-C", root, "cat-file", "-e", latest.commit_id .. "^{commit}",
                }, { text = true }):wait()
                if exists.code == 0 then
                    load()
                else
                    local hostname = require("octo.utils").get_remote_host()
                    vim.system({
                        "git", "-C", root, "fetch", "--no-tags",
                        "https://" .. hostname .. "/" .. pr.repo .. ".git", latest.commit_id,
                    }, { text = true }, vim.schedule_wrap(function(result)
                        if result.code ~= 0 then
                            fail("Could not fetch the reviewed commit: " .. vim.trim(result.stderr))
                            return
                        end
                        load()
                    end))
                end
            end)
        end)
    end)
end

function M.open()
    local review = require("octo.reviews").get_current_review()
    if review then
        open_range(review.pull_request, review)
    else
        require("plugins.octo.review").open(function(pr)
            open_range(pr)
        end)
    end
end

function M.setup()
    local commands = require("octo.commands").commands.review
    commands.since = M.open
    local resume = commands.resume
    commands.resume = function(...)
        local review = require("octo.reviews").get_current_review()
        if review and review.since_review then
            review:resume()
        else
            resume(...)
        end
    end
    local utils = require("octo.utils")
    local is_thread_placed = utils.is_thread_placed_in_buffer
    utils.is_thread_placed_in_buffer = function(thread, bufnr)
        if in_since_range(require("octo.reviews").get_current_review())
            and utils.get_split_and_path(bufnr) == "LEFT" then
            return false
        end
        return is_thread_placed(thread, bufnr)
    end
end

return M
