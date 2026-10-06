local M = {}
local utf8_bom = "\239\187\191"
-- Normalize once: a second leading U+FEFF is source text, not another BOM.
local normalized_boms = setmetatable({}, { __mode = "k" })

local function normalize_bom(lines)
    if normalized_boms[lines] ~= nil then
        return lines, normalized_boms[lines]
    end
    local bomb = #lines > 0 and lines[1]:sub(1, 3) == utf8_bom
    if bomb then
        lines = vim.list_extend({}, lines)
        lines[1] = lines[1]:sub(4)
    end
    normalized_boms[lines] = bomb
    return lines, bomb
end

function M.setup()
    local git = require("codediff.core.git")
    local get_file_content = git.get_file_content
    git.get_file_content = function(revision, root, path, callback)
        return get_file_content(revision, root, path, function(err, lines)
            if err then
                callback(err, lines)
                return
            end
            local normalized = normalize_bom(lines)
            callback(nil, normalized)
        end)
    end

    local virtual = require("codediff.core.virtual_file")
    local set_content = virtual.set_content
    virtual.set_content = function(buf, lines, path)
        local normalized, bomb = normalize_bom(lines)
        local result = set_content(buf, normalized, path)
        if result then
            vim.bo[buf].bomb = bomb
        end
        return result
    end
end

return M
