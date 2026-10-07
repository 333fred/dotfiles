return {
    "daliusd/ghlite.nvim",
    dependencies = { "lewis6991/async.nvim", "esmuellert/codediff.nvim", "git-review.nvim" },
    cmd = {
        "GHLitePRSelect", "GHLitePRList", "GHLitePRCheckout", "GHLitePRView",
        "GHLitePRApprove", "GHLitePRRequestChanges", "GHLitePRStartReview",
        "GHLitePRSubmitReview", "GHLitePRDiscardReview", "GHLitePRMerge",
        "GHLitePRAddPRComment", "GHLitePRLoadComments", "GHLitePRDiff",
        "GHLitePRDiffview", "GHLitePRAddComment", "GHLitePRUpdateComment",
        "GHLitePROpenComment", "GHLitePRDeleteComment", "GHLitePRResolveComment",
        "GHLitePRUnresolveComment", "GHLiteCommitView",
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
        require("git-review").setup_ghlite()
    end,
}
