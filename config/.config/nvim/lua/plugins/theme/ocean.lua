local M = {}

local function apply()
    local set = vim.api.nvim_set_hl
    local foreground = "#c0c5ce"
    local orange = "#d08770"
    local yellow = "#ebcb8b"
    local purple = "#b48ead"
    local blue = "#8fa1b3"

    set(0, "LineNr", { fg = "#47525c" })
    set(0, "CursorLine", { bg = "#323843" })
    set(0, "NormalFloat", { fg = foreground, bg = "#252932" })
    set(0, "FloatBorder", { fg = "#1a1d23", bg = "#252932" })
    set(0, "NeoTreeNormal", { fg = foreground, bg = "#21252d" })
    set(0, "NeoTreeNormalNC", { fg = foreground, bg = "#21252d" })
    set(0, "Pmenu", { fg = blue, bg = "#252932" })
    set(0, "PmenuSel", { fg = "#eff1f5", bg = "#343d46" })
    set(0, "StatusLine", { fg = "#a7adba", bg = "#1d2027" })
    set(0, "StatusLineNC", { fg = "#6e7d88", bg = "#1d2027" })
    set(0, "Visual", { bg = "#3f5570" })
    set(0, "MatchParen", { fg = foreground, bg = "#4f5b66", bold = true })
    -- Shade diff backgrounds without overriding syntax or Roslyn semantic foregrounds.
    set(0, "DiffAdd", { bg = "#304038" })
    set(0, "DiffDelete", { bg = "#442f35" })
    set(0, "DiffChange", { bg = "#353e4a" })
    set(0, "DiffText", { bg = "#43556a" })
    set(0, "OctoReviewDiffAddText", { bg = "#43563f" })
    set(0, "OctoReviewDiffDeleteText", { bg = "#604047" })

    for _, group in ipairs({ "Conditional", "Repeat", "Exception", "Label", "Statement",
        "@keyword.conditional", "@keyword.repeat", "@keyword.return", "@keyword.exception" }) do
        set(0, group, { fg = purple, bold = true })
    end

    for _, group in ipairs({ "Delimiter", "Operator", "@punctuation", "@punctuation.delimiter",
        "@punctuation.bracket", "@operator",
        "@lsp.type.local", "@lsp.type.variable", "@lsp.type.parameter" }) do
        set(0, group, { fg = foreground })
    end

    set(0, "@lsp.type.namespace.cs", { fg = blue })
    set(0, "@lsp.type.interface", { fg = yellow })
    set(0, "@lsp.type.typeParameter", { fg = yellow })
    set(0, "@lsp.type.struct", { fg = "#ab7976" })
    set(0, "@lsp.type.enum", { fg = "#ab7976" })
    set(0, "@lsp.type.property", { fg = blue, bold = true })
    set(0, "@lsp.type.constant", { fg = orange, bold = true })
    set(0, "@lsp.type.enumMember", { fg = orange, bold = true })

    set(0, "@lsp.typemod.variable.readonly", { fg = orange, bold = true })
end

function M.statusline_theme()
    local background = "#1d2027"
    local foreground = "#a7adba"
    local function mode(accent)
        return {
            a = { fg = background, bg = accent, gui = "bold" },
            b = { fg = "#dfe1e8", bg = "#323843" },
            c = { fg = foreground, bg = background },
        }
    end

    return {
        normal = mode("#518cc7"),
        insert = mode("#a3be8c"),
        visual = mode("#b48ead"),
        replace = mode("#bf616a"),
        command = mode("#ebcb8b"),
        inactive = {
            a = { fg = "#6e7d88", bg = background },
            b = { fg = "#6e7d88", bg = background },
            c = { fg = "#6e7d88", bg = background },
        },
    }
end

function M.setup()
    vim.api.nvim_create_autocmd("ColorScheme", { pattern = "base16-ocean", callback = apply })
    apply()
end

return M
