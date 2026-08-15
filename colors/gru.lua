-- tema.lua
-- Colorscheme inspirado no Gruber Darker + filosofia Alabaster
-- Mantém: poucas cores, sem destaque para keywords, comentários vivos
-- Adiciona: paleta mais quente/contrastante, estilo visual do Gruber

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end
vim.o.termguicolors = true
vim.g.colors_name = "tema"

-- === Paleta inspirada no Gruber Darker ===========================
-- Cores principais (mantendo 5 + variações)
local bg        = "#181818" -- fundo mais escuro
local bg_alt    = "#242424" -- fundo alternativo
local fg        = "#e4e4e4" -- texto base (quente)
local fg_light  = "#f5f5f5" -- texto mais claro
local muted     = "#6c6c6c" -- pontuação/delimitadores
local green     = "#95c56e" -- strings/números (verde vivo)
local green_bold= "#b5e48c" -- strings em destaque
local purple    = "#b87ed4" -- roxo (tipos/booleanos)
local purple_bold= "#d4a0f0" -- roxo mais claro
local yellow    = "#f5c35b" -- comentários (amarelo vivo)
local orange    = "#e69a4b" -- constantes/importantes
local blue      = "#8bb6e8" -- definições (azul claro)
local blue_bold = "#a8ccf0" -- azul mais claro
local red       = "#e05a5a" -- apenas erros
local red_bold  = "#f06a6a" -- erro em destaque

-- Tabela auxiliar para criar grupos
local function hi(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- === Base UI =====================================================
hi("Normal",       { fg = fg, bg = bg })
hi("NormalFloat",  { fg = fg, bg = bg_alt })
hi("CursorLine",   { bg = bg_alt })
hi("CursorLineNr", { fg = yellow, bold = true })
hi("LineNr",       { fg = muted })
hi("SignColumn",   { bg = bg })
hi("VertSplit",    { fg = muted, bg = bg })
hi("Visual",       { bg = "#3a3a3a" })
hi("Search",       { fg = bg, bg = yellow })
hi("IncSearch",    { fg = bg, bg = blue })
hi("Pmenu",        { fg = fg, bg = bg_alt })
hi("PmenuSel",     { fg = bg, bg = blue })
hi("PmenuThumb",   { bg = blue_bold })
hi("StatusLine",   { fg = fg, bg = bg_alt })
hi("StatusLineNC", { fg = muted, bg = bg_alt })
hi("Directory",    { fg = blue })
hi("Title",        { fg = blue_bold, bold = true })
hi("MatchParen",   { fg = yellow, bold = true, underline = true })
hi("Cursor",       { fg = bg, bg = fg })
hi("EndOfBuffer",  { fg = bg })
hi("Whitespace",   { fg = bg_alt })

-- === Sintaxe (grupos legacy) ===================================
-- Regra mantida: nada de destaque para keywords, variáveis ou chamadas
hi("Comment",       { fg = yellow, italic = false })        -- comentários vivos
hi("Constant",      { fg = orange })                         -- constantes (laranja)
hi("String",        { fg = green, italic = false })          -- strings (verde)
hi("Character",     { fg = green })
hi("Number",        { fg = orange })                         -- números (laranja)
hi("Boolean",       { fg = purple_bold, bold = true })       -- booleanos (roxo)
hi("Float",         { fg = orange })

hi("Identifier",    { fg = fg })                            -- variáveis (sem cor)
hi("Function",      { fg = blue_bold, bold = true })        -- definições top-level (azul)

hi("Statement",     { fg = fg })                            -- if/for/return...
hi("Conditional",   { fg = fg })
hi("Repeat",        { fg = fg })
hi("Label",         { fg = fg })
hi("Operator",      { fg = muted })
hi("Keyword",       { fg = fg })
hi("Exception",     { fg = fg })

hi("PreProc",       { fg = fg })
hi("Include",       { fg = fg })
hi("Define",        { fg = fg })
hi("Macro",         { fg = purple })
hi("PreCondit",     { fg = fg })

hi("Type",          { fg = purple, italic = false })       -- tipos (roxo)
hi("StorageClass",  { fg = fg })
hi("Structure",     { fg = purple })
hi("Typedef",       { fg = purple })

hi("Special",       { fg = purple })
hi("SpecialChar",   { fg = orange })
hi("Tag",           { fg = blue })
hi("Delimiter",     { fg = muted })                        -- pontuação esmaecida
hi("SpecialComment",{ fg = yellow, bold = true })
hi("Debug",         { fg = red_bold })

hi("Underlined",    { fg = blue, underline = true })
hi("Ignore",        { fg = muted })
hi("Error",         { fg = red_bold, bold = true })
hi("Todo",          { fg = yellow, bold = true, bg = bg })

-- === Treesitter (grupos modernos) ================================
-- Mantém filosofia: chamadas e keywords sem destaque
hi("@variable",              { fg = fg })
hi("@variable.builtin",      { fg = fg })
hi("@parameter",             { fg = fg })
hi("@field",                 { fg = fg })
hi("@property",              { fg = fg })

hi("@function",              { fg = blue_bold, bold = true })  -- definições
hi("@function.call",         { fg = fg })                     -- chamadas: sem destaque
hi("@method",                { fg = blue_bold, bold = true })
hi("@method.call",           { fg = fg })
hi("@constructor",           { fg = blue_bold, bold = true })

-- Keywords NÃO destacadas (filosofia Alabaster)
hi("@keyword",               { fg = fg })
hi("@keyword.function",      { fg = fg })
hi("@keyword.return",        { fg = fg })
hi("@keyword.operator",      { fg = fg })
hi("@conditional",           { fg = fg })
hi("@repeat",                { fg = fg })
hi("@exception",             { fg = fg })

-- Constantes, strings e números
hi("@string",                { fg = green, italic = false })
hi("@number",                { fg = orange })
hi("@float",                 { fg = orange })
hi("@boolean",               { fg = purple_bold, bold = true })
hi("@constant",              { fg = orange })
hi("@constant.builtin",      { fg = orange })

-- Tipos (roxo)
hi("@type",                  { fg = purple, italic = false })
hi("@type.builtin",          { fg = purple, italic = false })

-- Comentários e pontuação
hi("@comment",               { fg = yellow, italic = false })
hi("@punctuation.delimiter", { fg = muted })
hi("@punctuation.bracket",   { fg = muted })
hi("@operator",              { fg = muted })

hi("@tag",                   { fg = blue })
hi("@tag.attribute",         { fg = fg })

-- === Extras para linguagens específicas ===========================
-- Python
hi("@keyword.import",        { fg = fg })
hi("@module",                { fg = fg })
hi("@module.builtin",        { fg = fg })

-- JS/TS
hi("@keyword.as",            { fg = fg })
hi("@keyword.from",          { fg = fg })

-- LSP/Diagnostics (único lugar onde vermelho aparece)
hi("DiagnosticError", { fg = red_bold, bold = true })
hi("DiagnosticWarn",  { fg = yellow })
hi("DiagnosticInfo",  { fg = blue })
hi("DiagnosticHint",  { fg = muted })
hi("DiagnosticUnderlineError", { undercurl = true, sp = red })
hi("DiagnosticUnderlineWarn",  { undercurl = true, sp = yellow })
hi("DiagnosticUnderlineInfo",  { undercurl = true, sp = blue })
hi("DiagnosticUnderlineHint",  { undercurl = true, sp = muted })

-- LSP References
hi("LspReferenceText",  { bg = "#2a2a2a" })
hi("LspReferenceRead",  { bg = "#2a2a2a" })
hi("LspReferenceWrite", { bg = "#2a2a2a" })

-- === Git / diff ====================================================
hi("DiffAdd",    { fg = green_bold })
hi("DiffChange", { fg = yellow })
hi("DiffDelete", { fg = red_bold })
hi("DiffText",   { fg = blue_bold })

-- === Plugins populares =============================================
-- Telescope
hi("TelescopeNormal",    { fg = fg, bg = bg })
hi("TelescopeBorder",    { fg = muted, bg = bg })
hi("TelescopePromptBorder", { fg = blue, bg = bg })
hi("TelescopeResultsBorder", { fg = muted, bg = bg })
hi("TelescopePreviewBorder", { fg = muted, bg = bg })
hi("TelescopeSelection", { fg = yellow, bg = bg_alt })

-- NvimTree
hi("NvimTreeNormal",     { fg = fg, bg = bg })
hi("NvimTreeFolderName", { fg = blue })
hi("NvimTreeEmptyFolderName", { fg = muted })
hi("NvimTreeOpenedFolderName", { fg = blue_bold, bold = true })
hi("NvimTreeFileIcon",   { fg = muted })
hi("NvimTreeGitDirty",   { fg = yellow })
hi("NvimTreeGitStaged",  { fg = green })
hi("NvimTreeGitMerge",   { fg = blue })
hi("NvimTreeGitRenamed", { fg = purple })
hi("NvimTreeGitNew",     { fg = green })
hi("NvimTreeGitDeleted", { fg = red })

-- WhichKey
hi("WhichKey",           { fg = blue_bold })
hi("WhichKeyGroup",      { fg = yellow })
hi("WhichKeyDesc",       { fg = fg })
hi("WhichKeySeparator",  { fg = muted })

-- Indent Blankline
hi("IndentBlanklineContextChar", { fg = muted })
hi("IndentBlanklineContextStart", { fg = yellow, bold = true })
