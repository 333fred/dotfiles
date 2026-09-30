local M = {}

local function checkout_is_clean(root)
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        local path = vim.api.nvim_buf_get_name(bufnr)
        if vim.bo[bufnr].modified and vim.fs.relpath(root, path) then
            vim.notify("Save or close modified buffers before checking out a review PR", vim.log.levels.ERROR)
            return false
        end
    end
    local status = vim.system({ "git", "status", "--porcelain" }, { cwd = root, text = true }):wait()
    if status.code ~= 0 then
        vim.notify(status.stderr, vim.log.levels.ERROR)
        return false
    end
    if vim.trim(status.stdout) ~= "" then
        vim.notify("Review checkout has local changes; use a clean worktree before switching PRs", vim.log.levels.ERROR)
        return false
    end
    return true
end

function M.open()
    local utils = require("octo.utils")
    local buffer = utils.get_current_buffer()
    if not buffer or not buffer:isPullRequest() then
        vim.notify("Open a PR with ,p before entering its local review", vim.log.levels.ERROR)
        return
    end
    if not utils.in_pr_repo() then
        return
    end
    local node = buffer:pullRequest()
    if type(node.headRepository) ~= "table" or not node.headRepository.nameWithOwner then
        vim.notify("This PR's head repository is unavailable for local review", vim.log.levels.ERROR)
        return
    end
    local pr = {
        repo = buffer.repo,
        number = buffer.number,
        head_repo = node.headRepository.nameWithOwner,
        head_ref_name = node.headRefName,
    }
    if utils.in_pr_branch(pr) then
        require("octo.reviews").browse_review()
        return
    end

    local root_result = vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true }):wait()
    if root_result.code ~= 0 then
        vim.notify(root_result.stderr, vim.log.levels.ERROR)
        return
    end
    local root = vim.trim(root_result.stdout)
    if not checkout_is_clean(root) then
        return
    end
    local pr_bufnr = vim.api.nvim_get_current_buf()
    local pr_winid = vim.api.nvim_get_current_win()

    vim.ui.select({ "Checkout and review", "Cancel" }, {
        prompt = "Checkout " .. pr.repo .. "#" .. pr.number .. " in " .. root .. "?",
    }, function(choice)
        if choice ~= "Checkout and review" or not checkout_is_clean(root) then
            return
        end
        vim.system({ "gh", "pr", "checkout", tostring(pr.number), "--repo", pr.repo }, {
            cwd = root,
            text = true,
        }, vim.schedule_wrap(function(result)
            if result.code ~= 0 then
                vim.notify("PR checkout failed: " .. result.stderr, vim.log.levels.ERROR)
                return
            end
            vim.cmd.checktime()
            vim.api.nvim_exec_autocmds("User", { pattern = "ReviewCheckout", data = { root = root } })
            if not vim.api.nvim_buf_is_valid(pr_bufnr) or not vim.api.nvim_win_is_valid(pr_winid) then
                vim.notify("PR checked out; reopen its PR buffer and press ,r to review", vim.log.levels.WARN)
                return
            end
            vim.api.nvim_set_current_win(pr_winid)
            vim.api.nvim_win_set_buf(pr_winid, pr_bufnr)
            vim.cmd.lcd(root)
            if not utils.in_pr_branch(pr) then
                vim.notify("Octo cannot recognize the checked-out PR branch", vim.log.levels.ERROR)
                return
            end
            require("octo.reviews").browse_review()
        end))
    end)
end

return M
