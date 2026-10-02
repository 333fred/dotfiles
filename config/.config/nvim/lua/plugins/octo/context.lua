local M = {}

local method_nodes = {
    method_declaration = true,
    constructor_declaration = true,
    destructor_declaration = true,
    local_function_statement = true,
    operator_declaration = true,
    conversion_operator_declaration = true,
    accessor_declaration = true,
}

function M.setup()
    local expanded = {}
    local group = vim.api.nvim_create_augroup("OctoMethodContext", { clear = true })

    local function expand()
        local winid = vim.api.nvim_get_current_win()
        local bufnr = vim.api.nvim_get_current_buf()
        local review = require("octo.reviews").get_current_review()
        local layout = review and review.layout
        if not layout or (winid ~= layout.left_winid and winid ~= layout.right_winid)
            or not vim.wo.diff or vim.wo.foldmethod ~= "diff" or vim.bo.filetype ~= "cs" then
            expanded[winid] = nil
            return
        end

        local parser, err = vim.treesitter.get_parser(bufnr, "c_sharp")
        if not parser then
            vim.notify_once("Octo method context: " .. err .. "\nRun :TSInstall c_sharp", vim.log.levels.WARN)
            return
        end
        parser:parse()
        local node = vim.treesitter.get_node({ bufnr = bufnr, lang = "c_sharp" })
        while node and not method_nodes[node:type()] do
            node = node:parent()
        end
        if not node then
            expanded[winid] = nil
            return
        end

        local start_row, _, end_row, end_col = node:range()
        local first = start_row + 1
        local last = end_col == 0 and end_row or end_row + 1
        local context = { bufnr, first, last, vim.api.nvim_buf_get_changedtick(bufnr) }
        if vim.deep_equal(expanded[winid], context) then
            return
        end
        -- Diff folds can span adjacent methods; opening one reveals the entire fold.
        for line = first, last do
            if vim.fn.foldclosed(line) ~= -1 then
                vim.cmd(string.format("%d,%dfoldopen!", first, last))
                break
            end
        end
        expanded[winid] = context
    end

    vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "CursorMoved", "CursorMovedI", "TextChanged", "TextChangedI" }, {
        group = group,
        callback = function(event)
            local winid = vim.api.nvim_get_current_win()
            local bufnr = vim.api.nvim_get_current_buf()
            if event.event == "BufWinEnter" or event.event == "WinEnter" then
                expanded[winid] = nil
            end
            -- Octo enables diff mode after entering the buffer.
            vim.schedule(function()
                if vim.api.nvim_get_current_win() == winid and vim.api.nvim_get_current_buf() == bufnr then
                    expand()
                end
            end)
        end,
    })
    vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        callback = function(event)
            expanded[tonumber(event.match)] = nil
        end,
    })
end

return M
