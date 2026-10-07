local function close_buffer(bufnr)
    Snacks.bufdelete(bufnr)
end

local function pull_request_name(path)
    local host, repo, number = path:match("^git%-review://([^/]+)/([^/]+/[^/]+)/pull/(%d+)%?")
    if repo then
        return (host == "github.com" and "" or host .. "/") .. repo .. "#" .. number
    end
end

return {
    "akinsho/bufferline.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
        { "[b", "<Cmd>BufferLineCyclePrev<CR>", desc = "Previous buffer" },
        { "]b", "<Cmd>BufferLineCycleNext<CR>", desc = "Next buffer" },
        { "<leader>x", function() close_buffer() end, desc = "Close buffer" },
    },
    opts = {
        options = {
            diagnostics = "nvim_lsp",
            diagnostics_indicator = function(_, _, _, ctx)
                local count = 0
                for _, value in ipairs(require("ui.diagnostics").counts(ctx.buffer.id)) do
                    count = count + value
                end
                return count > 0 and " (" .. count .. ")" or ""
            end,
            close_command = close_buffer,
            right_mouse_command = close_buffer,
            middle_mouse_command = close_buffer,
            show_close_icon = false,
            separator_style = "thin",
            name_formatter = function(buffer)
                return pull_request_name(buffer.path)
            end,
            custom_filter = function(bufnr)
                local name = vim.api.nvim_buf_get_name(bufnr)
                if vim.b[bufnr].git_review_pr_url and vim.bo[bufnr].buftype == "nofile" then
                    return pull_request_name(name) ~= nil
                end
                return vim.bo[bufnr].buftype == ""
            end,
            offsets = {
                {
                    filetype = "snacks_layout_box",
                    text = "Files",
                    highlight = "BufferLineFill",
                    separator = true,
                },
            },
        },
        highlights = require("plugins.theme.ocean").bufferline_theme(),
    },
}
