return {
    dir = vim.fn.stdpath("config") .. "/local/git-review.nvim",
    name = "git-review.nvim",
    lazy = false,
    dependencies = { "folke/snacks.nvim" },
    keys = {
        { "<localleader>p", function() require("git-review").pr_diff() end, desc = "PR changed files and description" },
        { "<localleader>S", function() require("git-review").since_review() end, desc = "PR changes since your last review" },
        { "<localleader>v", function() require("git-review").description() end, desc = "View/toggle PR description" },
        { "<localleader>C", function() require("git-review").checkout_pr() end, desc = "Check out selected PR" },
        { "<localleader>c", function() require("git-review").toggle_comments() end, desc = "Toggle PR comments inline and in gutter" },
        { "<localleader>t", function() require("git-review").show_comment() end, desc = "Show PR comments on current line" },
        { "<localleader>a", function() require("git-review").add_comment() end, mode = { "n", "x" }, desc = "Add PR comment or reply" },
        { "<localleader>r", function() require("git-review").review_command("GHLitePRResolveComment") end, desc = "Resolve PR comment thread" },
        { "<localleader>s", function() require("git-review").review_command("GHLitePRStartReview") end, desc = "Start pending PR review" },
        { "<localleader>u", function() require("git-review").review_command("GHLitePRSubmitReview") end, desc = "Submit pending PR review" },
    },
    config = function()
        require("git-review").setup()
    end,
}
