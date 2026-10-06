return {
    "daliusd/ghlite.nvim",
    dependencies = { "lewis6991/async.nvim", "esmuellert/codediff.nvim" },
    cmd = {
        "GHLitePRSelect", "GHLitePRList", "GHLitePRCheckout", "GHLitePRView",
        "GHLitePRApprove", "GHLitePRRequestChanges", "GHLitePRStartReview",
        "GHLitePRSubmitReview", "GHLitePRDiscardReview", "GHLitePRMerge",
        "GHLitePRAddPRComment", "GHLitePRLoadComments", "GHLitePRDiff",
        "GHLitePRDiffview", "GHLitePRAddComment", "GHLitePRUpdateComment",
        "GHLitePROpenComment", "GHLitePRDeleteComment", "GHLitePRResolveComment",
        "GHLitePRUnresolveComment", "GHLiteCommitView",
    },
    keys = {
        { "<leader>Gp", function() require("config.git-review").pr_diff() end, desc = "PR changed files for current branch" },
        { "<leader>Gc", function() require("config.git-review").toggle_comments() end, desc = "Toggle PR comment signs" },
        { "<leader>Gt", function() require("config.git-review").show_comment() end, desc = "Show PR comments on current line" },
        { "<leader>Ga", function() require("config.git-review").add_comment() end, mode = { "n", "x" }, desc = "Add PR comment or reply" },
        { "<leader>Gr", function() require("config.git-review").review_command("GHLitePRResolveComment") end, desc = "Resolve PR comment thread" },
        { "<leader>Gs", function() require("config.git-review").review_command("GHLitePRStartReview") end, desc = "Start pending PR review" },
        { "<leader>Gu", function() require("config.git-review").review_command("GHLitePRSubmitReview") end, desc = "Submit pending PR review" },
    },
    opts = {
        diff_tool = "codediff",
        view_split = "",
        comment_split = "split",
        comment_hunk = false,
        open_command = "xdg-open",
        html_comments_command = false,
        refresh_interval = 0,
        pr_commands = {},
    },
    config = function(_, opts)
        require("ghlite").setup(opts)
        require("ghlite.config").s.pr_commands = {}
        require("config.git-review").setup()
    end,
}
