-- Run with: nvim --headless -u NONE -l <path-to-this-file>
local plugin = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = plugin .. "/lua/?.lua;" .. plugin .. "/lua/?/init.lua;" .. package.path

local original_cwd = vim.fn.getcwd()
local temp = vim.fn.tempname()
vim.fn.mkdir(temp, "p")
local repo = vim.fs.joinpath(temp, "repo")
local worktree = vim.fs.joinpath(temp, "linked worktree")
local function git(...)
    local result = vim.system({ "git", ... }, { text = true }):wait()
    assert(result.code == 0, result.stderr)
    return vim.trim(result.stdout)
end

local ok, err = xpcall(function()
    git("init", "--quiet", repo)
    git("-C", repo, "-c", "user.name=Review Test", "-c", "user.email=review@example.invalid",
        "-c", "commit.gpgsign=false", "commit", "--quiet", "--allow-empty", "-m", "Initial")
    git("-C", repo, "worktree", "add", "--quiet", "-b", "review-worktree", worktree)
    assert(vim.fn.filereadable(vim.fs.joinpath(worktree, ".git")) == 1)

    local notices, opened = {}, {}
    vim.notify = function(message) notices[#notices + 1] = message end
    package.loaded["lazy"] = { load = function() end }
    package.loaded["review.marks"] = { clear_all = function() end }
    package.loaded["review.store"] = {
        reset = function() end,
        load = function() assert(vim.fn.getcwd() == opened.cwd) end,
    }
    package.loaded["review.reviewed"] = { reset = function() end }
    package.loaded["codediff.ui.lifecycle"] = { get_session = function() end }
    local workflow = require("git-review.workflow")
    vim.api.nvim_create_user_command("CodeDiff", function(opts)
        assert(vim.deep_equal(opts.fargs, { "--repo", opened.root }))
        assert(workflow.set_target("local", opened.root))
    end, { nargs = "*" })
    package.loaded["review"] = {
        open_branch = function() assert(workflow.set_target("local", opened.root)) end,
        open_commits = function() assert(workflow.set_target("local", opened.root)) end,
    }

    local function open(root, action, named)
        vim.cmd.enew()
        vim.cmd.lcd(temp)
        if named then
            vim.api.nvim_buf_set_name(0, vim.fs.joinpath(root, action .. ".lua"))
        else
            vim.cmd.lcd(root)
        end
        opened = { root = vim.fs.normalize(vim.uv.fs_realpath(root)), cwd = vim.uv.fs_realpath(root) }
        workflow.open_local(action)
        local target = workflow.target()
        assert(target and target.root == opened.root and workflow.valid(target))
        assert(target.branch == git("-C", root, "branch", "--show-current"))
        assert(#notices == 0, vim.inspect(notices))
    end

    open(repo, "open", true)
    open(worktree, "open", true)
    open(worktree, "open_branch", true)
    open(worktree, "open_commits", true)
    open(worktree, "open", false)
    vim.cmd.enew()
    vim.api.nvim_buf_set_name(0, vim.fs.joinpath(repo, "other-file.lua"))
    assert(not workflow.valid(workflow.target()), "Another worktree must invalidate the review")
    vim.cmd.enew()
    vim.cmd.lcd(temp)
    workflow.open_local("open")
    assert(notices[#notices] == "Open a Git checkout first")
end, debug.traceback)

vim.cmd.enew()
vim.cmd.lcd(original_cwd)
vim.fn.delete(temp, "rf")
assert(ok, err)
print("Passed local review checkout scenarios")
