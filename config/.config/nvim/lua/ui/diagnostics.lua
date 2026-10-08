local M = {}

function M.is_visible(diagnostic)
    return diagnostic.source ~= "GHLite"
        and vim.diagnostic.is_enabled({ bufnr = diagnostic.bufnr, ns_id = diagnostic.namespace })
end

function M.counts(bufnr)
    local counts = { 0, 0, 0, 0 }
    for _, diagnostic in ipairs(vim.diagnostic.get(bufnr or 0)) do
        if M.is_visible(diagnostic) then
            counts[diagnostic.severity] = counts[diagnostic.severity] + 1
        end
    end
    return counts
end

return M
