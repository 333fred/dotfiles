local M = {}

function M.counts(bufnr)
    local counts = { 0, 0, 0, 0 }
    for _, diagnostic in ipairs(vim.diagnostic.get(bufnr or 0)) do
        if diagnostic.source ~= "GHLite"
            and vim.diagnostic.is_enabled({ bufnr = diagnostic.bufnr, ns_id = diagnostic.namespace }) then
            counts[diagnostic.severity] = counts[diagnostic.severity] + 1
        end
    end
    return counts
end

return M
