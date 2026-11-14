local M = {}

function M.setup()
    -- Both initial reads and Roslyn's content-refresh handler use this helper.
    require("roslyn.utils").populate_virtual_buffer_content = function(client, uri, bufnr)
        local response, err = client:request_sync("workspace/textDocumentContent", { uri = uri }, nil, bufnr)
        assert(response, "Failed to load Roslyn document: " .. tostring(err))
        assert(not response.err, vim.inspect(response.err))
        assert(type(response.result) == "table" and type(response.result.text) == "string",
            "Roslyn returned no document text")

        local text = response.result.text:gsub("\r\n", "\n")
        -- Empty lines are significant: LSP locations refer to the original line numbers.
        local lines = vim.split(text, "\n", { plain = true })
        local endofline = text:sub(-1) == "\n"
        if endofline then
            table.remove(lines)
        end
        local readonly = vim.bo[bufnr].readonly
        vim.bo[bufnr].readonly = false
        vim.bo[bufnr].modifiable = true
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        vim.bo[bufnr].endofline = endofline
        vim.bo[bufnr].modifiable = false
        vim.bo[bufnr].modified = false
        vim.bo[bufnr].readonly = readonly
    end
end

function M.picker_transform(item)
    if item.file and item.file:match("^roslyn%-source%-generated://") then
        -- Snacks' file preview only recognizes word-character URI schemes.
        item.buf = vim.uri_to_bufnr(item.file)
    end
end

return M
