local M = {}

function M.finder(opts, ctx)
    local fields = { "number", "title", "author", "url", "state", "isDraft", "labels" }
    local args = { "pr", "list", "--limit", tostring(opts.limit or 100), "--state", opts.state or "open" }
    for _, option in ipairs({ "search", "base", "author", "assignee", "label" }) do
        if opts[option] and opts[option] ~= "" then
            vim.list_extend(args, { "--" .. option, opts[option] })
        end
    end
    if opts.draft then
        args[#args + 1] = "--draft"
    end

    return function(cb)
        local api = require("snacks.gh.api")
        local items = api.fetch_sync({ args = args, fields = fields, repo = opts.repo })
        if not items then
            return
        end
        ctx.async:schedule(function()
            for _, item in ipairs(items or {}) do
                local pr = require("snacks.gh.item").new(item, {
                    type = "pr",
                    repo = opts.repo,
                    fields = fields,
                    text = { "number", "title", "author", "labels" },
                })
                -- Register lightweight items so previews can fetch the missing fields.
                api.refresh(pr)
                cb(pr)
            end
        end)
    end
end

return M
