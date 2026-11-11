vim.diagnostic.config({
    virtual_text = {
        severity = { min = vim.diagnostic.severity.WARN },
        source = "if_many",
    },
    severity_sort = true,
})

vim.opt.updatetime = 300

local document_highlight_group = vim.api.nvim_create_augroup("lsp_document_highlight", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(event)
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if not client then
            return
        end
        if client:supports_method("textDocument/documentHighlight", event.buf) then
            vim.api.nvim_clear_autocmds({ group = document_highlight_group, buffer = event.buf })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                group = document_highlight_group,
                buffer = event.buf,
                callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                group = document_highlight_group,
                buffer = event.buf,
                callback = vim.lsp.buf.clear_references,
            })
        end
        if client:supports_method("textDocument/completion", event.buf) then
            vim.lsp.completion.enable(true, client.id, event.buf)
        end
    end,
})
