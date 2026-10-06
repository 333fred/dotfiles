local M = {}

local function lines(text)
    if text == "" then
        return {}
    end
    local result = vim.split(text, "\n", { plain = true })
    if result[#result] == "" then
        table.remove(result)
    end
    return result
end

function M.new(original, current)
    local hunks = vim.diff(original, current, { result_type = "indices", algorithm = "histogram" })
    local original_lines = lines(original)
    local current_lines = lines(current)

    local function map_line(line, reverse)
        local offset = 0
        for _, hunk in ipairs(hunks) do
            local start, count, target_count = hunk[1], hunk[2], hunk[4]
            if reverse then
                start, count, target_count = hunk[3], hunk[4], hunk[2]
            end
            local boundary = count == 0 and start + 1 or start
            if line < boundary then
                break
            end
            if count > 0 and line < start + count then
                return nil
            end
            offset = offset + target_count - count
        end
        return line + offset
    end

    local function map_range(first, last, reverse)
        last = last or first
        local source = reverse and current_lines or original_lines
        if first < 1 or last < first or last > #source then
            return nil
        end
        local mapped_first, previous
        for line = first, last do
            local mapped = map_line(line, reverse)
            if not mapped or (previous and mapped ~= previous + 1) then
                return nil
            end
            mapped_first = mapped_first or mapped
            previous = mapped
        end
        return mapped_first, previous
    end

    return {
        original_lines = original_lines,
        to_local = function(first, last) return map_range(first, last, false) end,
        to_pr = function(first, last) return map_range(first, last, true) end,
    }
end

return M
