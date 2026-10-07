-- linux
if vim.loader then
    vim.loader.enable()
end

local ensure_packer = function()
    local fn = vim.fn
    local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'

    if fn.empty(fn.glob(install_path)) > 0 then
        print("🔄 Instalando packer.nvim...")
        fn.system({
            'git',
            'clone',
            '--depth',
            '1',
            'https://github.com/wbthomason/packer.nvim',
            install_path
        })
        vim.cmd('packadd packer.nvim')
        return true
    end

    return false
end

local packer_bootstrap = ensure_packer()

-- OPÇÕES BÁSICAS

vim.deprecate = function() end
vim.opt.guicursor = ""
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt_local.laststatus = 0
vim.g.mapleader = " "
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt_local.ruler = false
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.timeoutlen = 300
vim.opt.updatetime = 50
vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 0
vim.o.shortmess = vim.o.shortmess .. "atI"
vim.o.cmdheight = 1
vim.o.laststatus = 0
vim.opt.ruler = false
vim.o.laststatus = 1
vim.opt.autoread = true

vim.keymap.set('n', 'q', '<Nop>')

-- Opções de desabilitadas teste --
--vim.opt.cursorline = true
--vim.o.laststatus = 2
--vim.o.statusline = " [FILENAME: %t] %= [TYPE: %Y] [LINE: %l/%L : %c] [%p%%] %{Modified_Get()}"
--vim.opt_local.showmode = true
--vim.opt.number = true

-- teste do teste
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

vim.g.loaded_gzip = 1
vim.g.loaded_tarplugin = 1
vim.g.loaded_zipplugin = 1
vim.g.loaded_tohtml = 1
vim.g.loaded_tutor_mode_plugin = 1

-- opções de performance teste --
vim.g.neovide_cursor_animation_length = 0
vim.g.neovide_scroll_animation_length = 0
vim.g.neovide_position_animation_length = 0
vim.g.neovide_cursor_vfx_mode = ""
vim.opt.winblend = 0
vim.opt.pumblend = 0
vim.opt.smoothscroll = false
vim.opt.relativenumber = false
vim.g.neovide_animate_command_line = false
vim.g.neovide_cursor_animate_in_insert_mode = false
vim.g.neovide_cursor_animate_command_line = false
vim.g.neovide_cursor_trail_size = 0
vim.g.neovide_cursor_smooth_blink = false
vim.g.neovide_scroll_animation_far_lines = 0
vim.g.neovide_floating_blur_amount_x = 0
vim.g.neovide_floating_blur_amount_y = 0
vim.g.neovide_floating_shadow = false
vim.g.neovide_opacity = 1.0
vim.g.neovide_window_blurred = false
vim.g.neovide_refresh_rate = 60
vim.g.neovide_refresh_rate_idle = 5
vim.g.neovide_no_idle = false

local watchers = {}

local function unwatch(buf)
    local w = watchers[buf]
    if not w then return end
    watchers[buf] = nil
    w:stop()
    if not w:is_closing() then w:close() end
end

local watch

watch = function(buf)
    if watchers[buf] or not vim.api.nvim_buf_is_valid(buf) then return end
    if vim.bo[buf].buftype ~= "" then return end

    local name = vim.api.nvim_buf_get_name(buf)
    if name == "" or not vim.uv.fs_stat(name) then return end

    local w = vim.uv.new_fs_event()
    if not w then return end

    local ok = w:start(name, {}, vim.schedule_wrap(function()
        if vim.api.nvim_buf_is_valid(buf) then
            vim.cmd("silent! checktime " .. buf)
        end
        unwatch(buf)
        watch(buf)
    end))

    if not ok then
        w:close()
        return
    end
    watchers[buf] = w
end

local reload_group = vim.api.nvim_create_augroup("AutoReload", { clear = true })

vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter" }, {
    group = reload_group,
    callback = function(a) watch(a.buf) end,
})

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = reload_group,
    callback = function(a) unwatch(a.buf) end,
})

vim.api.nvim_create_autocmd("FocusGained", {
    group = reload_group,
    callback = function() vim.cmd("silent! checktime") end,
})

function _G.StatusName()
    if vim.bo.buftype == "terminal" then return "term" end
    local n = vim.fn.expand("%:t")
    return n ~= "" and n or "No Name"
end

vim.o.statusline = " %{v:lua.StatusName()} %m"

local repo_cache = {}

local function esc(s)
    return (s:gsub("%%", "%%%%"))
end

-- com cache: o tabline redesenha a cada movimento do cursor,
-- então não dá para fazer fs_stat em toda chamada
local function tab_dir(tabnr, buf)
    local cwd = vim.fn.getcwd(-1, tabnr)

    if vim.bo[buf].filetype == "netrw" then
        return vim.b[buf].netrw_curdir or cwd
    end
    if vim.bo[buf].buftype ~= "" then return cwd end

    local name = vim.api.nvim_buf_get_name(buf)
    if name == "" or name:match("^%a[%w+.-]*://") then return cwd end

    return vim.fn.fnamemodify(name, ":p:h")
end

local function get_repo_name(dir)
    if repo_cache[dir] then return repo_cache[dir] end

    local d, name = dir, nil
    while d and d ~= "" do
        if vim.uv.fs_stat(d .. "/.git") then
            name = vim.fn.fnamemodify(d, ":t")
            break
        end
        local parent = vim.fn.fnamemodify(d, ":h")
        if parent == d then break end
        d = parent
    end

    name = name or vim.fn.fnamemodify(dir, ":t")
    repo_cache[dir] = name
    return name
end

local function is_diffview_tab(tabnr)
    local tabid = vim.api.nvim_list_tabpages()[tabnr]
    if not tabid then return false end

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabid)) do
        local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
        if ft:match("^Diffview") then return true end
    end
    return false
end

function _G.NvimTabLine()
    local current = vim.fn.tabpagenr()
    local parts = {}

    for i = 1, vim.fn.tabpagenr("$") do
        local buf = vim.fn.tabpagebuflist(i)[vim.fn.tabpagewinnr(i)]
        local repo = get_repo_name(tab_dir(i, buf))
        local label

        if is_diffview_tab(i) then
            label = "Diff: " .. repo
        else
            local name
            if vim.bo[buf].buftype == "terminal" then
                name = "[term]"
            else
                name = vim.fn.fnamemodify(vim.fn.bufname(buf), ":t")
                if name == "" then name = "[No Name]" end
            end
            label = repo .. " - " .. name
            if i ~= current and vim.bo[buf].modified then
                label = label .. " +"
            end
        end

        local hl = i == current and "%#TabLineSel#" or "%#TabLine#"
        -- %iT = aba clicável com o mouse
        parts[#parts + 1] = "%" .. i .. "T" .. hl .. " " .. esc(label) .. " "
    end

    -- lado direito
    local ft = vim.bo.filetype
    ft = ft ~= "" and (" [" .. (ft:gsub("^%l", string.upper)) .. "]") or ""

    local ok, head = pcall(vim.fn.FugitiveHead)
    local branch = (ok and head ~= "") and (" git:" .. esc(head)) or ""

    local S = vim.diagnostic.severity
    local d = vim.diagnostic.count(0)
    local diag = ""
    if d[S.ERROR] then diag = diag .. " E" .. d[S.ERROR] end
    if d[S.WARN] then diag = diag .. " W" .. d[S.WARN] end

    local lnum, last = vim.fn.line("."), vim.fn.line("$")
    local info = branch .. diag .. ft
        .. " " .. lnum .. "/" .. last .. ":" .. vim.fn.col(".")
        .. " " .. math.floor(lnum * 100 / last) .. "%%"
        .. (vim.bo.modified and " [+]" or "")
        .. " "

    return table.concat(parts, "%#TabLineFill#|") .. "%#TabLineFill#%T%=" .. info
end

vim.o.showtabline = 2
vim.o.tabline = "%!v:lua.NvimTabLine()"

vim.api.nvim_create_autocmd("DirChanged", {
    callback = function() repo_cache = {} end,
})

vim.api.nvim_create_autocmd({
    "CursorMoved", "CursorMovedI", "ModeChanged",
    "TextChanged", "TextChangedI", "BufModifiedSet", "DiagnosticChanged",
}, {
    callback = function() vim.cmd.redrawtabline() end,
})

--vim.o.winbar = "%#TabSep#%{repeat('─', winwidth(0))}"

vim.api.nvim_create_autocmd("FileType", {
    pattern = { "NvimTree", "dashboard", "qf", "DiffviewFiles", "DiffviewFileHistory", "trouble" },
    callback = function() vim.opt_local.winbar = "" end,
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "netrw",
    callback = function()
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
        vim.opt_local.signcolumn = "no"

        vim.opt_local.winbar = "%{get(b:, 'netrw_curdir', '')}"
    end,

})

vim.api.nvim_create_autocmd("FileType", {
    pattern = { "NvimTree", "qf", "trouble", "netrw", "undotree", "DiffviewFiles", "DiffviewFileHistory" },
    callback = function() vim.opt_local.statusline = " " end,
})

local function ts_disable(_, buf)
    local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
    if not (ok and stats) then return false end

    local lines = vim.api.nvim_buf_line_count(buf)

    return stats.size > 5 * 1024 * 1024 or (stats.size / math.max(lines, 1)) > 1000
end

local function web_search()
    local query = vim.fn.input("Search: ")

    if query == "" then
        return
    end

    local buf = vim.api.nvim_create_buf(false, true)

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "websearch"

    local width = math.floor(vim.o.columns * 0.80)
    local height = math.floor(vim.o.lines * 0.70)

    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        border = "rounded",
        title = " Search: " .. query .. " ",
        title_pos = "center",
    })

    vim.wo[win].cursorline = true
    vim.wo[win].wrap = true

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "",
        "  Searching...",
        "",
    })

    vim.fn.jobstart({
        "curl",
        "-Ls",
        "-A",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/146 Safari/537.36",
        "-e",
        "https://html.duckduckgo.com/",
        "-d",
        "q=" .. query,
        "https://html.duckduckgo.com/html/",
    }, {
        stdout_buffered = true,

        on_stdout = function(_, data)
            if not data or #data == 0 then
                return
            end

            vim.schedule(function()
                local html = table.concat(data, "\n")
                local results = {}

                for block in html:gmatch(
                    '<a rel="nofollow" class="result__a".-</a>'
                ) do
                    local link = block:match(
                        'href="([^"]+)"'
                    )

                    local title = block:match(
                        '>(.-)</a>'
                    )

                    if link and title then
                        title = title:gsub("<[^>]+>", "")

                        title = title:gsub("&amp;", "&")
                        title = title:gsub("&quot;", '"')
                        title = title:gsub("&#x27;", "'")
                        title = title:gsub("&lt;", "<")
                        title = title:gsub("&gt;", ">")

                        table.insert(results, {
                            title = vim.trim(title),
                            link = link,
                        })
                    end
                end

                local lines = {
                    " Results: " .. query,
                    "",
                }

                if #results == 0 then
                    table.insert(lines, " No results.")
                else
                    for i, result in ipairs(results) do
                        table.insert(
                            lines,
                            string.format(" %d. %s", i, result.title)
                        )

                        table.insert(
                            lines,
                            "    " .. result.link
                        )

                        table.insert(lines, "")
                    end
                end

                vim.bo[buf].modifiable = true

                vim.api.nvim_buf_set_lines(
                    buf,
                    0,
                    -1,
                    false,
                    lines
                )

                vim.bo[buf].modifiable = false
            end)
        end,

        on_stderr = function(_, data)
            if data and #data > 0 then
                vim.schedule(function()
                    vim.notify(
                        "Error: " .. table.concat(data, " "),
                        vim.log.levels.ERROR
                    )
                end)
            end
        end,
    })

    vim.keymap.set("n", "q", "<cmd>close<CR>", {
        buffer = buf,
        silent = true,
        desc = "Close web search",
    })

    vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", {
        buffer = buf,
        silent = true,
        desc = "Close web search",
    })

    vim.keymap.set("n", "<CR>", function()
        local line = vim.api.nvim_get_current_line()

        local link = line:match("https?://%S+")

        if link then
            vim.fn.jobstart({
                "xdg-open",
                link,
            }, {
                detach = true,
            })
        end
    end, {
        buffer = buf,
        silent = true,
        desc = "Open search result",
    })
end

vim.keymap.set("n", "<leader>/", web_search, {
    desc = "Web search",
})

local function setup_autopairs()
    local pairs_map = {
        ['('] = ')',
        ['['] = ']',
        ['{'] = '}',
        ['"'] = '"',
        ["'"] = "'",
        ['`'] = '`',
    }

    local closers = {}
    for _, r in pairs(pairs_map) do closers[r] = true end

    local no_apostrophe = { markdown = true, text = true, gitcommit = true, tex = true }

    local function ctx()
        local col = vim.api.nvim_win_get_cursor(0)[2]
        local line = vim.api.nvim_get_current_line()
        return line:sub(col, col), line:sub(col + 1, col + 1)
    end

    local function can_close(nxt)
        return nxt == '' or nxt:match('%s') ~= nil or closers[nxt] == true
    end

    for l, r in pairs(pairs_map) do
        if l ~= r then
            vim.keymap.set('i', l, function()
                local _, nxt = ctx()
                return can_close(nxt) and (l .. r .. '<Left>') or l
            end, {
                expr = true,
                desc = "Insert matching pair",
            })

            vim.keymap.set('i', r, function()
                local _, nxt = ctx()
                return nxt == r and '<Right>' or r
            end, {
                expr = true,
                desc = "Skip matching closer",
            })
        else
            vim.keymap.set('i', l, function()
                local prev, nxt = ctx()
                if nxt == l then return '<Right>' end
                if l == "'" and no_apostrophe[vim.bo.filetype] then return l end
                if prev:match('[%w_]') or prev == l or not can_close(nxt) then
                    return l
                end
                return l .. l .. '<Left>'
            end, {
                expr = true,
                desc = "Insert matching quote",
            })
        end
    end

    vim.keymap.set('i', '<BS>', function()
        local prev, nxt = ctx()
        if prev ~= '' and pairs_map[prev] == nxt then
            return '<BS><Del>'
        end
        return '<BS>'
    end, {
        expr = true,
        desc = "Delete matching pair",
    })

    vim.keymap.set('i', '<CR>', function()
        if vim.fn.pumvisible() == 1 then return '<CR>' end
        local prev, nxt = ctx()
        if (prev == '(' and nxt == ')')
            or (prev == '[' and nxt == ']')
            or (prev == '{' and nxt == '}') then
            return '<CR><C-o>O'
        end
        return '<CR>'
    end, {
        expr = true,
        desc = "Expand matching pair",
    })
end

setup_autopairs()

-- KEYBIND CHANGER (<leader>cb)

local keybinds = (function()
    local M = {}

    local backed_up = false

    -- structural binds (autopairs) that must not be changed
    local PROTECTED = { ["i|<BS>"] = true, ["i|<CR>"] = true }

    local function config_path()
        local p = vim.env.MYVIMRC
        if not p or p == "" then
            p = vim.fn.stdpath("config") .. "/init.lua"
        end
        return vim.uv.fs_realpath(p) or p
    end

    local function expand(lhs)
        local leader = vim.g.mapleader or "\\"
        if leader == " " then leader = "<Space>" end
        return (lhs:gsub("<[Ll]eader>", leader))
    end

    local function parse_set(line)
        local s, e = line:find("^%s*vim%.keymap%.set%(")
        if not s then s, e = line:find("^%s*set%(") end
        if not s then return end
        local pos = e + 1

        local modes = {}
        local ms, me = line:find("^%s*%b{}", pos)
        if ms then
            for m in line:sub(ms, me):gmatch("[\"'](%a*)[\"']") do
                modes[#modes + 1] = m
            end
        else
            local m
            ms, me, m = line:find("^%s*[\"'](%a*)[\"']", pos)
            if not ms then return end
            modes = { m }
        end

        local cs, ce = line:find("^%s*,%s*", me + 1)
        if not cs then return end

        local ls, le, _, lhs = line:find("^([\"'])(.-)%1", ce + 1)
        if not ls then return end

        return modes, lhs, ls, le
    end

    local function statement(lines, i)
        local buf, depth = {}, 0
        for j = i, math.min(i + 60, #lines) do
            local l = lines[j]
            buf[#buf + 1] = l
            local _, o = l:gsub("%(", "")
            local _, c = l:gsub("%)", "")
            depth = depth + o - c
            if depth <= 0 then break end
        end
        return table.concat(buf, "\n")
    end

    local function collect(lines)
        local wk = {}
        for i, line in ipairs(lines) do
            if not line:match("^%s*%-%-") then
                local lhs, rest = line:match('^%s*{%s*"([^"]+)"%s*,%s*(.*)$')
                if lhs and not rest:match("group%s*=") then
                    local desc = rest:match('desc%s*=%s*"([^"]*)"')
                    if desc then
                        wk[#wk + 1] = {
                            lnum = i,
                            lhs = lhs,
                            desc = desc,
                            mode = rest:match('mode%s*=%s*"(%a+)"') or "n",
                        }
                    end
                end
            end
        end

        local binds = {}
        for i, line in ipairs(lines) do
            if not line:match("^%s*%-%-") then
                local modes, lhs, ls, le = parse_set(line)
                if modes and #modes > 0 then
                    local key = table.concat(modes, ",") .. "|" .. lhs
                    local stmt = statement(lines, i)

                    local buffer_local = stmt:find("buffer%s*=")
                        or stmt:find("[%s,]opts%(")
                        or stmt:find("[%s,]opts%)%s*$")

                    if not buffer_local and not PROTECTED[key] then
                        local desc = stmt:match('desc%s*=%s*"([^"]*)"')
                            or stmt:match("desc%s*=%s*'([^']*)'")
                        if not desc then
                            for _, w in ipairs(wk) do
                                if w.lhs == lhs and vim.tbl_contains(modes, w.mode) then
                                    desc = w.desc
                                    break
                                end
                            end
                        end

                        binds[#binds + 1] = {
                            key = key,
                            lnum = i,
                            modes = modes,
                            lhs = lhs,
                            ls = ls,
                            le = le,
                            desc = desc or "(no description)",
                        }
                    end
                end
            end
        end

        return binds, wk
    end

    local function find_global(mode, lhs)
        local want = vim.keycode(expand(lhs))
        for _, k in ipairs(vim.api.nvim_get_keymap(mode)) do
            if vim.keycode(k.lhs) == want then return k end
        end
    end

    local function apply_to_file(bind, new)
        local path = config_path()

        local nr = vim.fn.bufnr(path)
        if nr ~= -1 and vim.bo[nr].modified then
            return false, "init.lua has unsaved changes. Save it (:w) and try again."
        end

        local lines = vim.fn.readfile(path)
        local binds, wk = collect(lines)

        local target
        for _, b in ipairs(binds) do
            if b.key == bind.key then
                target = b
                break
            end
        end
        if not target then
            return false, "Keybind not found in the file (did it change?)."
        end

        local line = lines[target.lnum]
        local q = line:sub(target.ls, target.ls)
        lines[target.lnum] = line:sub(1, target.ls - 1) .. q .. new .. q .. line:sub(target.le + 1)

        for _, w in ipairs(wk) do
            if w.lhs == bind.lhs and vim.tbl_contains(target.modes, w.mode) then
                local l = lines[w.lnum]
                local s, e = l:find('"' .. w.lhs .. '"', 1, true)
                if s then
                    local tail = l:sub(e + 1)
                    local sp = tail:match("^,(%s*)")
                    if sp then
                        local pad = math.max(1, #sp - (#new - #w.lhs))
                        tail = "," .. string.rep(" ", pad) .. tail:sub(#sp + 2)
                    end
                    lines[w.lnum] = l:sub(1, s - 1) .. '"' .. new .. '"' .. tail
                end
            end
        end

        if not backed_up then
            vim.fn.writefile(vim.fn.readfile(path), path .. ".bak")
            backed_up = true
        end
        vim.fn.writefile(lines, path)
        vim.cmd("checktime")
        return true
    end

    local function apply_live(bind, new)
        for _, mode in ipairs(bind.modes) do
            local k = find_global(mode, bind.lhs)
            if k then
                pcall(vim.keymap.del, mode, expand(bind.lhs))
                vim.keymap.set(mode, new, k.callback or k.rhs or "", {
                    silent = k.silent == 1,
                    expr = k.expr == 1,
                    nowait = k.nowait == 1,
                    remap = k.noremap == 0,
                    desc = k.desc,
                })
            end
        end

        local ok, wk = pcall(require, "which-key")
        if ok then
            local spec = {}
            for _, mode in ipairs(bind.modes) do
                spec[#spec + 1] = { bind.lhs, hidden = true, mode = mode }
                spec[#spec + 1] = { new, desc = bind.desc, mode = mode }
            end
            pcall(wk.add, spec)
        end
    end

    function M.change(bind, binds)
        vim.ui.input({
            prompt = ("New key for '%s' (current: %s): "):format(bind.desc, bind.lhs),
            default = bind.lhs,
        }, function(new)
            if not new then return end
            new = vim.trim(new)
            if new == "" or new == bind.lhs then return end

            if new:find("[\"'\\%c]") then
                vim.notify("Invalid key (quotes, backslashes and control characters are not allowed).",
                    vim.log.levels.ERROR)
                return
            end

            for _, b in ipairs(binds) do
                if b.key ~= bind.key and b.lhs == new then
                    for _, m in ipairs(b.modes) do
                        if vim.tbl_contains(bind.modes, m) then
                            vim.notify(("'%s' is already used by: %s. Change that one first."):format(new, b.desc),
                                vim.log.levels.ERROR)
                            return
                        end
                    end
                end
            end

            for _, mode in ipairs(bind.modes) do
                local k = find_global(mode, new)
                if k then
                    local what = k.desc or k.rhs or "Lua function"
                    local ans = vim.fn.confirm(
                        ("'%s' is already mapped (%s) in mode %s. Overwrite?"):format(new, what, mode),
                        "&Yes\n&No", 2)
                    if ans ~= 1 then return end
                    break
                end
            end

            local ok, err = apply_to_file(bind, new)
            if not ok then
                vim.notify(err, vim.log.levels.ERROR)
                return
            end

            apply_live(bind, new)
            vim.notify(("Keybind changed: %s → %s  (%s)"):format(bind.lhs, new, bind.desc))

            vim.schedule(M.open)
        end)
    end

    function M.open()
        local binds = collect(vim.fn.readfile(config_path()))

        local entries = {}
        for _, b in ipairs(binds) do
            entries[#entries + 1] = string.format(
                "%-24s %-7s %s  :%d", b.lhs, table.concat(b.modes, ","), b.desc, b.lnum)
        end

        require("fzf-lua").fzf_exec(entries, {
            prompt = "Binds> ",
            winopts = { title = " Enter: change the key ", title_pos = "center" },
            actions = {
                ["default"] = function(selected)
                    local sel = selected and selected[1]
                    if not sel then return end
                    local lnum = tonumber(sel:match(":(%d+)%s*$"))
                    for _, b in ipairs(binds) do
                        if b.lnum == lnum then
                            vim.schedule(function() M.change(b, binds) end)
                            return
                        end
                    end
                end,
            },
        })
    end

    return M
end)()

local function setup_dashboard()
    vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("Dashboard", { clear = true }),
        callback = function()
            if vim.fn.argc() > 0 then return end

            local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            if #lines > 1 or (#lines == 1 and #lines[1] > 0) then return end

            local buf = vim.api.nvim_create_buf(false, true)
            vim.bo[buf].bufhidden = "wipe"
            vim.bo[buf].buftype = "nofile"
            vim.bo[buf].filetype = "dashboard"

            vim.api.nvim_win_set_buf(0, buf)

            local win = 0
            vim.opt_local.number = false
            vim.opt_local.relativenumber = false
            vim.opt_local.cursorline = false
            vim.opt_local.cursorcolumn = false
            vim.opt_local.signcolumn = "no"
            vim.opt_local.fillchars = { eob = " " }

            local original_guicursor = vim.o.guicursor
            vim.api.nvim_set_hl(0, "DashboardCursor", { blend = 100, nocombine = true })

            local function hide_cursor()
                vim.opt.guicursor = "a:DashboardCursor"
            end

            local function restore_cursor()
                vim.opt.guicursor = original_guicursor
            end

            hide_cursor()

            vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "VimLeavePre" }, {
                buffer = buf,
                callback = restore_cursor,
            })

            vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
                buffer = buf,
                callback = hide_cursor,
            })

            local logo = {
            }

            local menu = {
                "[n] New File ",
                "[f] Find File",
                "    [e] File Explorer",
                " [wq] Quit     ",
            }

            local width = vim.api.nvim_win_get_width(win)
            local height = vim.api.nvim_win_get_height(win)

            local function center(text_lines)
                local res = {}
                for _, line in ipairs(text_lines) do
                    local pad = math.floor((width - #line) / 2)
                    table.insert(res, string.rep(" ", pad) .. line)
                end
                return res
            end

            local content = {}
            local total_lines = #logo + #menu + 2
            local top_pad = math.floor((height - total_lines) / 2)

            for _ = 1, top_pad do table.insert(content, "") end
            for _, l in ipairs(center(logo)) do table.insert(content, l) end
            table.insert(content, "")
            table.insert(content, "")
            for _, l in ipairs(center(menu)) do table.insert(content, l) end

            vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
            vim.bo[buf].modifiable = false

            local opts = { buffer = buf, noremap = true, silent = true }

            vim.keymap.set("n", "n", function()
                restore_cursor()
                vim.cmd("enew")
            end, vim.tbl_extend("force", opts, {
                desc = "New file",
            }))

            vim.keymap.set("n", "e", function()
                restore_cursor()
                vim.cmd.Ex()
            end, vim.tbl_extend("force", opts, {
                desc = "Open file explorer",
            }))

            vim.keymap.set("n", "f", function()
                restore_cursor()
                if pcall(require, 'fzf-lua') then
                    require('fzf-lua').files()
                else
                    vim.notify("FZF-Lua não está carregado", vim.log.levels.WARN)
                end
            end, vim.tbl_extend("force", opts, {
                desc = "Find file",
            }))

            vim.keymap.set("n", "wq", ":q!<CR>", vim.tbl_extend("force", opts, {
                desc = "Quit Neovim",
            }))
        end,
    })
end

require('packer').startup(function(use)
    use 'wbthomason/packer.nvim'

    use {
        'ibhagwan/fzf-lua',
        requires = { 'nvim-lua/plenary.nvim' },
    }

    use {
        'williamboman/mason.nvim',
        tag = 'v1.10.0',
    }

    use {
        'nvim-treesitter/nvim-treesitter',
        run = function()
            require('nvim-treesitter.install').update({ with_sync = true })
        end,
    }

    use 'mbbill/undotree'
    use 'tpope/vim-fugitive'
    use 'neovim/nvim-lspconfig'

    use {
        'saghen/blink.cmp',
        tag = 'v1.10.1',
        requires = { 'rafamadriz/friendly-snippets' },
    }

    use 'theprimeagen/harpoon'
    use "sindrets/diffview.nvim"

    use { 'folke/zen-mode.nvim' }
    use { 'eero-lehtinen/oklch-color-picker.nvim' }

    use "folke/which-key.nvim"

    use 'dchinmay2/alabaster.nvim'

    use 'mg979/vim-visual-multi'

    use {
        'nvim-tree/nvim-tree.lua',
        requires = { 'nvim-tree/nvim-web-devicons' },
    }

    use 'nvim-neotest/nvim-nio'

    use 'stevearc/conform.nvim'

    use 'windwp/nvim-ts-autotag'

    use 'e-ink-colorscheme/e-ink.nvim'

    use 'flaviodelgrosso/min-theme.nvim'

    use {
        'esmuellert/codediff.nvim',
        config = function()
            pcall(function()
                require('codediff').setup({
                    diff = {
                        conflict_result_position = "bottom",
                        conflict_result_height = 30,
                    },
                })
            end)
        end,
    }
    use {
        'folke/trouble.nvim',
        requires = { 'nvim-tree/nvim-web-devicons' },
    }

    use {
        'williamboman/mason-lspconfig.nvim',
        tag = 'v1.0.0',
        requires = { 'williamboman/mason.nvim' },
    }

    if packer_bootstrap then
        require('packer').sync()
    end
end)

local function post_install_setup()
    setup_dashboard()

    require('fzf-lua').setup({
        winopts = {
            height = 0.75,
            width = 0.70,
            row = 0.5,
            col = 0.5,
            border = "rounded",
            preview = { delay = 150 },
        },
        previewers = {
            builtin = {
                syntax_limit_b = 1024 * 100,
                extensions = {
                    ["png"]  = { "chafa", "{file}" },
                    ["jpg"]  = { "chafa", "{file}" },
                    ["jpeg"] = { "chafa", "{file}" },
                    ["gif"]  = { "chafa", "{file}" },
                    ["webp"] = { "chafa", "{file}" },
                    ["svg"]  = { "chafa", "{file}" },
                },
            },
        },
        files = {
            prompt = 'Files❯ ',
            file_icons = true,
            git_icons = false,
            cmd = "find . \\( -name .git -o -name node_modules -o -name dist -o -name build"
                .. " -o -name __pycache__ -o -name .venv -o -name .cache \\) -prune"
                .. " -o -type f -printf '%P\\n'",
        },
        grep = {
            prompt = 'Grep❯ ',
            file_icons = true,
            git_icons = false,
            grep_opts = "--binary-files=without-match --line-number --recursive --color=auto"
                .. " --perl-regexp"
                .. " --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist"
                .. " --exclude-dir=build --exclude-dir=__pycache__ --exclude-dir=.venv"
                .. " --exclude-dir=.cache -e",
        },
    })

    pcall(function()
        require("mason").setup()
    end)

    pcall(function()
        require('blink.cmp').setup({
            keymap = {
                preset = 'default',
                ['<C-Space>'] = { 'show', 'show_documentation', 'hide_documentation' },
                ['<Tab>'] = { 'select_next', 'snippet_forward', 'fallback' },
                ['<S-Tab>'] = { 'select_prev', 'snippet_backward', 'fallback' },
                ['<C-n>'] = { 'select_next', 'fallback' },
                ['<C-p>'] = { 'select_prev', 'fallback' },
                ['<C-e>'] = { 'hide' },
                ['<C-y>'] = { 'accept' },
            },

            completion = {
                documentation = {
                    auto_show = false,
                },
                menu = {
                    auto_show = true,
                    draw = {
                        columns = { { "label", "label_description", gap = 1 } },
                    },
                },
                list = {
                    max_items = 10,
                    selection = {
                        preselect = false,
                        auto_insert = true,
                    },
                },
            },

            sources = {
                default = { 'lsp', 'path', 'snippets', 'buffer' },
                providers = {
                    lsp = {
                        name = 'LSP',
                        module = 'blink.cmp.sources.lsp',
                        score_offset = 100,
                    },
                    path = {
                        name = 'Path',
                        module = 'blink.cmp.sources.path',
                        score_offset = 10,
                        opts = {
                            trailing_slash = false,
                            label = 'Path',
                        },
                    },
                    buffer = {
                        name = 'Buffer',
                        module = 'blink.cmp.sources.buffer',
                        score_offset = 5,
                        opts = {
                            min_keyword_length = 2,
                            max_entries = 100,
                        },
                    },
                    snippets = {
                        name = 'Snippets',
                        module = 'blink.cmp.sources.snippets',
                        score_offset = 15,
                    },
                },
            },

            snippets = {
                preset = 'default',
            },

            fuzzy = {
                implementation = 'prefer_rust_with_warning',
            },
        })
    end)

    require("mason-lspconfig").setup({
        ensure_installed = {
            "lua_ls",
            "pyright",
            "vtsls",
        },
        automatic_installation = true,
    })

    local lspconfig = require("lspconfig")
    local capabilities = require('blink.cmp').get_lsp_capabilities()

    require("mason-lspconfig").setup_handlers({
        function(server_name)
            lspconfig[server_name].setup({
                capabilities = capabilities,
            })
        end,

        ["lua_ls"] = function()
            lspconfig.lua_ls.setup({
                capabilities = capabilities,
                settings = {
                    Lua = {
                        diagnostics = {
                            globals = { "vim" },
                        },
                        workspace = {
                            checkThirdParty = false,
                            library = {
                                vim.env.VIMRUNTIME,
                            },
                        },
                        telemetry = {
                            enable = false,
                        },
                    },
                },
            })
        end,

        ["pyright"] = function()
            lspconfig.pyright.setup({
                capabilities = capabilities,
                settings = {
                    python = {
                        analysis = {
                            typeCheckingMode = "basic",
                            autoSearchPaths = true,
                            useLibraryCodeForTypes = true,
                        },
                    },
                },
            })
        end,

        ["vtsls"] = function()
            lspconfig.vtsls.setup({
                capabilities = capabilities,
                settings = {
                    typescript = {
                        inlayHints = {
                            includeInlayParameterNameHints = 'all',
                            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                            includeInlayFunctionParameterTypeHints = true,
                            includeInlayVariableTypeHints = true,
                            includeInlayPropertyDeclarationTypeHints = true,
                            includeInlayFunctionLikeReturnTypeHints = true,
                            includeInlayEnumMemberValueHints = true,
                        },
                    },
                    javascript = {
                        inlayHints = {
                            includeInlayParameterNameHints = 'all',
                            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                            includeInlayFunctionParameterTypeHints = true,
                            includeInlayVariableTypeHints = true,
                            includeInlayPropertyDeclarationTypeHints = true,
                            includeInlayFunctionLikeReturnTypeHints = true,
                            includeInlayEnumMemberValueHints = true,
                        },
                    },
                },
            })
        end,
    })

    pcall(function()
        local mark = require("harpoon.mark")
        local ui = require("harpoon.ui")

        vim.keymap.set("n", "<leader>a", mark.add_file, {
            desc = "Harpoon: add file",
        })

        vim.keymap.set("n", "<C-e>", ui.toggle_quick_menu, {
            desc = "Harpoon: toggle menu",
        })

        vim.keymap.set("n", "<leader>1", function()
            ui.nav_file(1)
        end, {
            desc = "Harpoon: file 1",
        })

        vim.keymap.set("n", "<leader>2", function()
            ui.nav_file(2)
        end, {
            desc = "Harpoon: file 2",
        })

        vim.keymap.set("n", "<leader>3", function()
            ui.nav_file(3)
        end, {
            desc = "Harpoon: file 3",
        })

        vim.keymap.set("n", "<leader>4", function()
            ui.nav_file(4)
        end, {
            desc = "Harpoon: file 4",
        })
    end)

    pcall(function()
        local api = require("nvim-tree.api")

        local function editor_wins()
            local wins = {}
            for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                local buf = vim.api.nvim_win_get_buf(w)
                if vim.api.nvim_win_get_config(w).relative == ""
                    and vim.bo[buf].filetype ~= "NvimTree"
                    and vim.bo[buf].buftype == "" then
                    table.insert(wins, w)
                end
            end
            return wins
        end

        local function open_keep_tree()
            local node = api.tree.get_node_under_cursor()
            if not node then return end

            if node.nodes then
                api.node.open.edit()
                return
            end

            local wins = editor_wins()
            local first = #wins == 0
                or (#wins == 1
                    and vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(wins[1])) == ""
                    and not vim.bo[vim.api.nvim_win_get_buf(wins[1])].modified)

            if first then
                api.node.open.edit()
            else
                table.sort(wins, function(a, b)
                    return vim.api.nvim_win_get_position(a)[2] > vim.api.nvim_win_get_position(b)[2]
                end)
                vim.api.nvim_set_current_win(wins[1])
                vim.cmd("rightbelow vsplit " .. vim.fn.fnameescape(node.absolute_path))
            end

            api.tree.focus()
        end

        local function on_attach(bufnr)
            api.config.mappings.default_on_attach(bufnr)

            local function opts(desc)
                return {
                    desc = "nvim-tree: " .. desc,
                    buffer = bufnr,
                    noremap = true,
                    silent = true,
                    nowait = true
                }
            end

            vim.keymap.set("n", "<CR>", open_keep_tree, opts("Open (1st normal, then right split)"))
            vim.keymap.set("n", "<2-LeftMouse>", open_keep_tree, opts("Open (mouse)"))
        end

        require('nvim-tree').setup({
            on_attach = on_attach,
            disable_netrw = false,
            hijack_netrw = false,
            hijack_directories = {
                enable = false,
            },
            view = {
                width = 50,
                side = 'left',
            },
            filters = {
                dotfiles = true,
            },
            update_focused_file = {
                enable = true,
            },
        })
    end)

    pcall(function()
        require('neotest').setup({
            adapters = {
                require('neotest-python')({
                    dap = { justMyCode = false },
                    runner = 'pytest',
                }),
                require('neotest-jest')({
                    jestCommand = 'npx jest',
                }),
            },
        })
    end)

    pcall(function()
        require('conform').setup({
            formatters_by_ft = {
                python = { 'ruff_format' },
                javascript = { 'prettierd', 'prettier', stop_after_first = true },
                typescript = { 'prettierd', 'prettier', stop_after_first = true },
                javascriptreact = { 'prettierd', 'prettier', stop_after_first = true },
                typescriptreact = { 'prettierd', 'prettier', stop_after_first = true },
                json = { 'prettierd', 'prettier', stop_after_first = true },
                css = { 'prettierd', 'prettier', stop_after_first = true },
                lua = { 'stylua' },
            },
            format_on_save = {
                timeout_ms = 1500,
                lsp_format = 'fallback',
            },
        })
    end)

    pcall(function()
        require('nvim-ts-autotag').setup()
    end)

    pcall(function()
        require('trouble').setup()
    end)

    pcall(function()
        require('diffview').setup({
            view = {
                default = {
                    layout = "diff2_horizontal",
                },
                file_history = {
                    layout = "diff2_horizontal",
                },
            },
            panel = {
                position = "left",
                width = 20,
            },
        })
    end)

    pcall(function()
        require("zen-mode").setup({
            plugins = {
                options = { laststatus = 0 },
                tmux = true,
                kitty = { enabled = false, font = "+4" },
                alacritty = { enabled = true, font = "18" },
            },
        })

        vim.keymap.set("n", "<leader>z", "<cmd>ZenMode<cr>", {
            desc = "Zen Mode",
        })
    end)

    pcall(function()
        require("oklch-color-picker").setup({
            highlight_colors = { enable = true },
            keymaps = { confirm = "<CR>" },
        })

        vim.keymap.set("n", "<leader>cp", function()
            require("oklch-color-picker").open_picker()
        end, {
            desc = "Open Color Picker",
        })

        vim.keymap.set("n", "<leader>cP", function()
            require("oklch-color-picker").pick_under_cursor()
        end, {
            desc = "Pick Color Under Cursor",
        })
    end)

    pcall(function()
        local wk = require("which-key")

        wk.setup({
            preset = "helix",
            delay = 300,
        })

        wk.add({
            -- Grupos principais
            { "<leader>w",       group = "window/write" },
            { "<leader>g",       group = "git" },
            { "<leader>v",       group = "lsp" },

            -- Write / quit / arquivo
            { "<leader>ww",      desc = "Write file" },
            { "<leader>wq",      desc = "Quit" },
            { "<leader>q",       desc = "Close tab" },
            { "<leader>e",       desc = "Explorer (netrw)" },
            { "<leader>n",       desc = "New file" },

            -- Splits e navegação de janela
            { "<leader>wv",      desc = "Vertical split" },
            { "<leader>ws",      desc = "Horizontal split" },
            { "<leader>wh",      desc = "Go to left window" },
            { "<leader>wj",      desc = "Go to below window" },
            { "<leader>wk",      desc = "Go to above window" },
            { "<leader>wl",      desc = "Go to right window" },

            -- Terminal / ferramentas externas
            { "<leader>t",       desc = "Open terminal split (zsh)" },
            { "<leader>i",       desc = "Open agy in vsplit" },
            { "<leader>o",       desc = "Open opencode in vsplit" },

            -- Diffview / NvimTree / Undotree
            { "<leader>d",       desc = "Diffview open" },
            { "<leader>b",       desc = "Toggle NvimTree" },
            { "<leader>u",       desc = "Toggle Undotree" },

            -- Tabs
            { "<leader><Tab>",   desc = "Next tab" },
            { "<leader><S-Tab>", desc = "Previous tab" },
            { "<leader>N",       desc = "New tab" },

            -- Git
            { "<leader>gt",      desc = "Git status (fugitive)" },
            { "<leader>gl",      desc = "Git log (fzf-lua)" },
            { "<leader>gs",      desc = "Git status (fzf-lua)" },
            { "<leader>gd",      desc = "Git branches (fzf-lua)" },
            { "<leader>gb",      desc = "Git file history (fzf-lua)" },
            { "<leader>gg",      desc = "Git Grep (fzf-lua)" },
            { "<leader>gc",      desc = "Git commit" },
            { "<leader>gm",      desc = "Git merge conflict" },

            -- LSP
            { "<leader>vww",     desc = "Workspace symbol" },
            { "<leader>vd",      desc = "Open diagnostic float" },
            { "<leader>vca",     desc = "Code action" },
            { "<leader>vrr",     desc = "LSP references" },
            { "<leader>vrn",     desc = "LSP rename" },

            -- Busca
            { "<leader>f",       desc = "Find files (fzf-lua)" },
            { "<leader>x",       desc = "Open directory (new tab)" },
            { "<leader>s",       desc = "Fuzzy find in current buffer" },
            { "<leader>a",       desc = "Harpoon: add file" },
            { "<leader>1",       desc = "Harpoon: file 1" },
            { "<leader>2",       desc = "Harpoon: file 2" },
            { "<leader>3",       desc = "Harpoon: file 3" },
            { "<leader>4",       desc = "Harpoon: file 4" },

            { "<leader>T",       desc = "Trouble: diagnostics" },
            { "<leader>lT",      desc = "Trouble: quickfix" },

            -- Comment toggle
            { "<leader>m",       desc = "Toggle comment",              mode = "v" },

            -- Change binds
            { "<leader>cb",      desc = "Change keybinds" },
        })
    end)

    vim.cmd('hi statusline guibg=NONE')

    -- Keymaps globais
    vim.keymap.set('n', '<leader>ww', ':write<CR>', {
        desc = 'Write file',
    })

    vim.keymap.set('n', '<leader>wq', ':quit<CR>', {
        desc = 'Quit window',
    })

    vim.keymap.set('n', '<leader>e', vim.cmd.Ex, {
        desc = 'Open file explorer',
    })

    vim.keymap.set('n', '<leader>n', ':enew<CR>', {
        desc = 'New file',
    })

    vim.keymap.set('n', '<leader>q', ':tabclose<CR>', {
        desc = 'Close tab',
    })

    vim.keymap.set('n', '<leader>wv', ':vsplit<CR>', {
        silent = true,
        desc = 'Vertical split',
    })

    vim.keymap.set('n', '<leader>ws', ':split<CR>', {
        silent = true,
        desc = 'Horizontal split',
    })

    vim.keymap.set('n', '<leader>wh', '<C-w>h', {
        desc = 'Go to left window',
    })

    vim.keymap.set('n', '<leader>wj', '<C-w>j', {
        desc = 'Go to below window',
    })

    vim.keymap.set('n', '<leader>wk', '<C-w>k', {
        desc = 'Go to above window',
    })

    vim.keymap.set('n', '<leader>wl', '<C-w>l', {
        desc = 'Go to right window',
    })

    vim.keymap.set('n', '<leader>t', ':belowright 12split term://zsh<CR>', {
        silent = true,
        desc = 'Open terminal split',
    })

    vim.keymap.set('n', '<leader>i', function()
        vim.cmd('vsplit')
        vim.cmd('wincmd l')
        vim.cmd('vertical resize 50')
        vim.cmd('terminal agy')
    end, {
        silent = true,
        desc = 'Open AGY CLI',
    })

    vim.keymap.set('n', '<leader>o', function()
        vim.cmd('vsplit')
        vim.cmd('wincmd l')
        vim.cmd('vertical resize 50')
        vim.cmd('terminal ~/bin/opencode --model litellm-pr/gemma4-saj')
    end, {
        silent = true,
        desc = 'Open OpenCode CLI',
    })

    vim.keymap.set('n', '<leader>d', ':DiffviewOpen<CR>', {
        silent = true,
        desc = 'Open Diffview',
    })

    vim.keymap.set('n', '<leader>b', ':NvimTreeToggle<CR>', {
        silent = true,
        desc = 'Toggle NvimTree',
    })

    vim.keymap.set('n', '<leader><Tab>', ':tabnext<CR>', {
        silent = true,
        desc = 'Next tab',
    })

    vim.keymap.set('n', '<leader><S-Tab>', ':tabprevious<CR>', {
        silent = true,
        desc = 'Previous tab',
    })

    vim.keymap.set('n', '<leader>N', ':tabnew<CR>', {
        silent = true,
        desc = 'New tab',
    })

    vim.keymap.set('n', ']e', ':cnext<CR>zz', {
        silent = true,
        desc = 'Next error',
    })

    vim.keymap.set('n', '[e', ':cprevious<CR>zz', {
        silent = true,
        desc = 'Previous error',
    })

    vim.keymap.set('n', '<leader>co', ':copen<CR>', {
        silent = true,
        desc = 'Open quickfix',
    })

    vim.keymap.set('n', '<leader>u', vim.cmd.UndotreeToggle, {
        desc = 'Toggle Undotree',
    })

    vim.keymap.set('n', '<leader>gt', vim.cmd.Git, {
        desc = 'Git status (Fugitive)',
    })

    vim.keymap.set('n', '<leader>gl', function()
        require('fzf-lua').git_commits()
    end, {
        desc = 'Git log (fzf-lua)',
    })

    vim.keymap.set('n', '<leader>gs', function()
        require('fzf-lua').git_status()
    end, {
        desc = 'Git status (fzf-lua)',
    })

    vim.keymap.set('n', '<leader>gd', function()
        require('fzf-lua').git_branches()
    end, {
        desc = 'Git branches (fzf-lua)',
    })

    vim.keymap.set('n', '<leader>gb', function()
        require('fzf-lua').git_bcommits()
    end, {
        desc = 'Git file history (fzf-lua)',
    })

    vim.keymap.set('n', '<leader>gc', ':Git commit<CR>', {
        silent = true,
        desc = 'Git commit',
    })

    vim.keymap.set('n', '<leader>gm', function()
        local ok, err = pcall(function()
            local file = vim.fn.expand('%:p')

            if file == '' then
                vim.notify('No open files', vim.log.levels.WARN)
                return
            end

            vim.cmd('CodeDiff merge ' .. vim.fn.fnameescape(file))
        end)

        if not ok then
            vim.notify('CodeDiff: ' .. err, vim.log.levels.ERROR)
        end
    end, {
        desc = 'Git: merge conflict',
    })

    vim.keymap.set('n', '<C-p>', function()
        require('fzf-lua').git_files()
    end, {
        desc = 'Git files (fzf-lua)',
    })

    vim.keymap.set("n", "gd", vim.lsp.buf.definition, {
        desc = "LSP: go to definition",
    })

    vim.keymap.set("n", "K", vim.lsp.buf.hover, {
        desc = "LSP: hover documentation",
    })

    vim.keymap.set("n", "<leader>vww", vim.lsp.buf.workspace_symbol, {
        desc = "LSP: workspace symbols",
    })

    vim.keymap.set("n", "<leader>vd", vim.diagnostic.open_float, {
        desc = "LSP: diagnostic float",
    })

    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, {
        desc = "LSP: next diagnostic",
    })

    vim.keymap.set("n", "d[", vim.diagnostic.goto_prev, {
        desc = "LSP: previous diagnostic",
    })

    vim.keymap.set("n", "<leader>vca", vim.lsp.buf.code_action, {
        desc = "LSP: code action",
    })

    vim.keymap.set("n", "<leader>vrr", vim.lsp.buf.references, {
        desc = "LSP: references",
    })

    vim.keymap.set("n", "<leader>vrn", vim.lsp.buf.rename, {
        desc = "LSP: rename",
    })

    vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help, {
        desc = "LSP: signature help",
    })

    vim.keymap.set('n', '<leader>-', function()
        vim.opt.number = not vim.opt.number:get()
    end, {
        desc = 'Toggle line numbers',
    })

    vim.keymap.set('n', '<leader>T', '<cmd>Trouble diagnostics toggle<CR>', {
        desc = 'Trouble: diagnostics',
    })

    vim.keymap.set('n', '<leader>lT', '<cmd>Trouble qflist toggle<CR>', {
        desc = 'Trouble: quickfix',
    })

    vim.keymap.set('n', '<leader>f', function()
        require('fzf-lua').files()
    end, {
        desc = 'FZF: find files',
    })

    vim.keymap.set('n', '<leader><leader>', function()
        require('fzf-lua').live_grep()
    end, {
        desc = 'FZF: live grep',
    })

    vim.keymap.set('n', '<leader>s', function()
        require('fzf-lua').blines()
    end, {
        desc = 'FZF: current buffer',
    })

    vim.keymap.set('n', '<leader>gg', function()
        require('fzf-lua').live_grep({
            cmd = "git grep --line-number --column --color=always",
            prompt = 'GitGrep❯ ',
        })
    end, {
        desc = 'FZF: Git grep',
    })

    vim.keymap.set("v", "<leader>m", function()
        local cs = vim.bo.commentstring
        local prefix = cs:match("^(.-)%s*%%s")

        local start_line = vim.fn.line("v")
        local end_line = vim.fn.line(".")
        if start_line > end_line then
            start_line, end_line = end_line, start_line
        end

        local all_commented = true
        for i = start_line, end_line do
            local l = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
            if not l:match("^%s*" .. vim.pesc(prefix)) then
                all_commented = false
                break
            end
        end

        for i = start_line, end_line do
            local l = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
            local new
            if all_commented then
                new = l:gsub("%s*" .. vim.pesc(prefix) .. "%s?", "", 1)
            else
                local indent = l:match("^(%s*)")
                local rest = l:sub(#indent + 1)
                new = indent .. prefix .. " " .. rest
            end
            vim.api.nvim_buf_set_lines(0, i - 1, i, false, { new })
        end

        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "n", false)
    end, {
        desc = "Toggle comment",
    })

    ------------------------------------------------------------
    -- KEYMAPS GLOBAIS EXTRAS
    ------------------------------------------------------------
    local set = vim.keymap.set
    local kopts = { noremap = true, silent = true }

    set("n", "ss", ":split<Return>", vim.tbl_extend("force", kopts, {
        desc = "Horizontal split",
    }))

    set("n", "sv", ":vsplit<Return>", vim.tbl_extend("force", kopts, {
        desc = "Vertical split",
    }))

    set("n", "sx", "<cmd>close<CR>", vim.tbl_extend("force", kopts, {
        desc = "Close window",
    }))

    set("n", "<leader>X", "<cmd>!chmod +x %<CR>", {
        silent = true,
        desc = "Make current file executable",
    })

    set("n", "<C-a>", "gg<S-v>G", {
        desc = "Select entire file",
    })

    set({ "n", "o", "x" }, "<s-h>", "^", {
        desc = "Jump to beginning of line",
    })

    set({ "n", "o", "x" }, "<s-l>", "g_", {
        desc = "Jump to end of line",
    })

    set("n", "<leader>cf", '<cmd>let @+ = expand("%")<CR>', {
        desc = "Copy file name",
    })

    set("n", "<C-u>", "<C-u>zz", {
        desc = "Scroll up and center",
    })

    set("n", "<C-d>", "<C-d>zz", {
        desc = "Scroll down and center",
    })

    set("n", "n", "nzzzv", vim.tbl_extend("force", kopts, {
        desc = "Next search result",
    }))

    set("n", "N", "Nzzzv", vim.tbl_extend("force", kopts, {
        desc = "Previous search result",
    }))

    set("v", "<", "<gv", vim.tbl_extend("force", kopts, {
        desc = "Indent left and keep selection",
    }))

    set("v", ">", ">gv", vim.tbl_extend("force", kopts, {
        desc = "Indent right and keep selection",
    }))

    set("n", "<leader>lw", "<cmd>set wrap!<CR>", vim.tbl_extend("force", kopts, {
        desc = "Toggle line wrap",
    }))

    set("v", "K", ":m '<-2<CR>gv=gv", {
        silent = true,
        desc = "Move selection up",
    })

    set("v", "J", ":m '>+1<CR>gv=gv", {
        silent = true,
        desc = "Move selection down",
    })

    set("n", "x", '"_x', vim.tbl_extend("force", kopts, {
        desc = "Delete character without yanking",
    }))

    set("n", "<leader>rr", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], {
        desc = "Replace word under cursor",
    })

    set('n', 'dd', '"_dd', {
        desc = "Delete line without yanking",
    })

    set('v', 'd', '"_d', {
        desc = "Delete selection without yanking",
    })

    set("x", "p", [["_dP]], {
        desc = "Paste without overwriting register",
    })

    set("n", "<leader><left>", ":vertical resize +20<cr>", {
        desc = "Increase window width",
    })

    set("n", "<leader><right>", ":vertical resize -20<cr>", {
        desc = "Decrease window width",
    })

    set("n", "<leader><up>", ":resize +10<cr>", {
        desc = "Increase window height",
    })

    set("n", "<leader><down>", ":resize -10<cr>", {
        desc = "Decrease window height",
    })

    set("n", "<leader>ll", "<cmd>PackerStatus<CR>", {
        desc = "Open Packer status",
    })

    set("n", "<leader>lm", "<cmd>Mason<CR>", {
        desc = "Open Mason LSP installer",
    })

    set("n", "<leader>ch", function()
        require("fzf-lua").help_tags()
    end, {
        desc = "Search help",
    })

    set("n", "<leader>ck", function()
        require("fzf-lua").keymaps()
    end, {
        desc = "Search keymaps",
    })

    set("n", "<leader>cs", function()
        require("fzf-lua").builtin()
    end, {
        desc = "Search selectors",
    })

    set("n", "<leader>cw", function()
        require("fzf-lua").grep_cword()
    end, {
        desc = "Search word under cursor",
    })

    set("n", "<leader>cd", function()
        require("fzf-lua").diagnostics_document()
    end, {
        desc = "Search buffer diagnostics",
    })

    set("n", "<leader>cD", function()
        require("fzf-lua").diagnostics_workspace()
    end, {
        desc = "Search workspace diagnostics",
    })

    set("n", "<leader>cb", function()
        keybinds.open()
    end, {
        desc = "Change keybinds",
    })

    set('n', ';s', '<Plug>(VM-Find-Under)', {
        remap = true,
        desc = 'Multi-cursor: find under cursor',
    })

    set('n', ';n', '<Plug>(VM-Add-Cursor-At-Next)', {
        remap = true,
        desc = 'Multi-cursor: next occurrence',
    })

    set('n', ';a', '<Plug>(VM-Select-All)', {
        remap = true,
        desc = 'Multi-cursor: select all',
    })

    local ignored = {
        ".git", "node_modules", "dist", "build",
        ".cache", ".npm", ".cargo", ".rustup",
    }

    local function dirs_cmd()
        local home = vim.env.HOME
        local extra_roots = { home .. "/.config", home .. "/.local/bin" }
        local q = vim.fn.shellescape

        local names = {}
        for _, n in ipairs(ignored) do
            names[#names + 1] = "-name " .. q(n)
        end
        local ignored_expr = table.concat(names, " -o ")

        local parts = {
            string.format(
                "find %s -mindepth 1 \\( -name '.*' -o %s \\) -prune -o -type d -print",
                q(home), ignored_expr
            ),
        }

        for _, root in ipairs(extra_roots) do
            if vim.uv.fs_stat(root) then
                parts[#parts + 1] = string.format(
                    "find %s \\( %s \\) -prune -o -type d -print",
                    q(root), ignored_expr
                )
            end
        end

        return "{ " .. table.concat(parts, "; ") .. "; } 2>/dev/null | sort"
    end

    local function open_dir_picker(new_tab)
        require("fzf-lua").fzf_exec(dirs_cmd(), {
            prompt = "Dirs> ",
            fzf_opts = {
                ["--height"] = "100%",
                ["--layout"] = "reverse",
                ["--border"] = "none",
                ["--margin"] = "0",
                ["--padding"] = "0",
            },
            actions = {
                ["default"] = function(selected)
                    local dir = selected[1]
                    if not dir or dir == "" then return end

                    if new_tab then
                        vim.cmd("tabnew")
                        vim.cmd.tcd(vim.fn.fnameescape(dir))
                    else
                        vim.cmd.cd(vim.fn.fnameescape(dir))
                    end

                    vim.cmd.edit(".")
                end,
            },
        })
    end

    vim.keymap.set("n", "<C-x>", function()
        open_dir_picker(false)
    end, {
        desc = "Open directory (current tab)",
    })

    vim.keymap.set("n", "<leader>x", function()
        open_dir_picker(true)
    end, {
        desc = "Open directory (new tab)",
    })

    pcall(function()
        require('nvim-treesitter.configs').setup({
            ensure_installed = {
                "lua",
                "vim",
                "vimdoc",
                "bash",
                "json",
                "javascript",
                "typescript",
                "html",
                "css",
                "markdown",
                "elixir",
                "python",
            },
            highlight = {
                enable = true,
                disable = ts_disable,
            },
            indent = {
                enable = true,
                disable = ts_disable,
            },
            sync_install = true,
            auto_install = true,
        })
    end)
end

if packer_bootstrap then
    vim.api.nvim_create_autocmd('User', {
        pattern = 'PackerComplete',
        once = true,
        callback = post_install_setup
    })
else
    post_install_setup()
end

local function remove_all_italics()
    for _, group in ipairs(vim.fn.getcompletion('', 'highlight')) do
        local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group })
        if ok and hl and hl.italic then
            hl.italic = false
            pcall(vim.api.nvim_set_hl, 0, group, hl)
        end
    end
end

local function dark()
    local hl = vim.api.nvim_set_hl

    hl(0, 'Normal', { bg = 'NONE' })
    hl(0, 'LineNr', { fg = '#858585', bg = 'NONE' })
    hl(0, 'CursorLine', { bg = '#2a2d2e' })
    hl(0, 'CursorLineNr', { fg = '#c6c6c6', bg = 'NONE', bold = true })
    hl(0, 'NonText', { fg = '#3b3b3b', bg = 'NONE' })
    hl(0, 'SpecialKey', { fg = '#3b3b3b', bg = 'NONE' })
    hl(0, 'EndOfBuffer', { fg = '#1e1e1e', bg = 'NONE' })
    hl(0, 'StatusLine', { fg = '#ffffff', bg = '#3c3c3c' })
    hl(0, 'StatusLineNC', { fg = '#858585', bg = '#252526' })
    hl(0, 'VertSplit', { fg = '#444444', bg = '#1e1e1e' })
    hl(0, 'Visual', { bg = '#264f78' })
    hl(0, 'Search', { bg = '#515c6a' })
    hl(0, 'MatchParen', { bg = '#3a3d41', bold = true })
    hl(0, 'Pmenu', { fg = '#d4d4d4', bg = '#252526' })
    hl(0, 'PmenuSel', { fg = '#ffffff', bg = '#04395e' })
    hl(0, 'Comment', { fg = '#edc100' })
    hl(0, 'Constant', { fg = '#4fc1ff' })
    hl(0, 'String', { fg = '#ce9178' })
    hl(0, 'Character', { fg = '#ce9178' })
    hl(0, 'Number', { fg = '#b5cea8' })
    hl(0, 'Float', { fg = '#b5cea8' })
    hl(0, 'Boolean', { fg = '#569cd6' })
    hl(0, 'Identifier', { fg = '#9cdcfe' })
    hl(0, 'Function', { fg = '#dcdcaa' })
    hl(0, 'Statement', { fg = '#569cd6' })
    hl(0, 'Conditional', { fg = '#c586c0' })
    hl(0, 'Repeat', { fg = '#c586c0' })
    hl(0, 'Exception', { fg = '#c586c0' })
    hl(0, 'Include', { fg = '#c586c0' })
    hl(0, 'Operator', { fg = '#d4d4d4' })
    hl(0, 'Delimiter', { fg = '#d4d4d4' })
    hl(0, 'PreProc', { fg = '#c586c0' })
    hl(0, 'Macro', { fg = '#c586c0' })
    hl(0, 'Type', { fg = '#4ec9b0' })
    hl(0, 'StorageClass', { fg = '#569cd6' })
    hl(0, 'Structure', { fg = '#4ec9b0' })
    hl(0, 'Special', { fg = '#d7ba7d' })
    hl(0, 'Error', { fg = '#f44747', bold = true })
    hl(0, 'Todo', { fg = '#d7ba7d', bold = true })
    hl(0, 'TabLine', { fg = '#858585', bg = '#252526' })
    hl(0, 'TabLineSel', { fg = '#ffffff', bg = '#3c3c3c', bold = true })
    hl(0, 'TabLineFill', { fg = '#d4d4d4', bg = '#252526' })
end

local function theme()
    local hl = vim.api.nvim_set_hl

    local c = {
        bg      = '#000000',
        fg      = '#d0d4da',
        dim     = '#6b7280',
        keyword = '#ff7a93', -- rosa-coral: keywords e fluxo de controle
        func    = '#ffd479', -- amarelo suave: funções (maior destaque)
        string  = '#9ece6a', -- verde-oliva claro: strings
        type    = '#7dcfff', -- azul-céu: tipos e estruturas
        const   = '#bb9af7', -- lavanda: números, booleanos, constantes
        comment = '#7c8798', -- cinza azulado: comentários discretos
        special = '#ff9e64', -- laranja: escapes e especiais
        error   = '#ff5370',
        warn    = '#ffd479',
        info    = '#7dcfff',
        sel     = '#2a2f45',
        line    = '#101114',
    }

    -- Base / UI
    hl(0, 'Normal', { fg = c.fg, bg = c.bg })
    hl(0, 'NormalFloat', { fg = c.fg, bg = '#0a0a0c' })
    hl(0, 'FloatBorder', { fg = '#3a3f4b', bg = '#0a0a0c' })
    hl(0, 'SignColumn', { bg = c.bg })
    hl(0, 'LineNr', { fg = '#4b5160', bg = c.bg })
    hl(0, 'CursorLine', { bg = c.line })
    hl(0, 'CursorLineNr', { fg = c.func, bg = c.bg, bold = true })
    hl(0, 'NonText', { fg = '#2a2d35', bg = c.bg })
    hl(0, 'SpecialKey', { fg = '#2a2d35', bg = c.bg })
    hl(0, 'EndOfBuffer', { fg = c.bg, bg = c.bg })
    hl(0, 'ColorColumn', { bg = c.line })
    hl(0, 'StatusLine', { fg = '#ffffff', bg = '#1a1c22' })
    hl(0, 'StatusLineNC', { fg = c.dim, bg = '#0a0a0c' })
    hl(0, 'VertSplit', { fg = '#2f333d', bg = c.bg })
    hl(0, 'WinSeparator', { fg = '#2f333d', bg = c.bg })
    hl(0, 'Visual', { bg = c.sel })
    hl(0, 'Search', { fg = '#000000', bg = '#e0b85a' })
    hl(0, 'IncSearch', { fg = '#000000', bg = c.special, bold = true })
    hl(0, 'MatchParen', { fg = c.func, bg = '#2a2d35', bold = true })
    hl(0, 'Pmenu', { fg = c.fg, bg = '#101114' })
    hl(0, 'PmenuSel', { fg = '#ffffff', bg = c.sel, bold = true })
    hl(0, 'PmenuSbar', { bg = '#1a1c22' })
    hl(0, 'PmenuThumb', { bg = '#3f4452' })
    hl(0, 'Folded', { fg = c.dim, bg = c.line })
    hl(0, 'Title', { fg = c.type, bold = true })
    hl(0, 'Directory', { fg = c.type })
    hl(0, 'TabLine', { fg = c.dim, bg = '#0a0a0c' })
    hl(0, 'TabLineSel', { fg = '#ffffff', bg = '#1a1c22', bold = true })
    hl(0, 'TabLineFill', { fg = c.fg, bg = '#0a0a0c' })

    -- Sintaxe
    hl(0, 'Comment', { fg = c.comment })
    hl(0, 'Constant', { fg = c.const })
    hl(0, 'String', { fg = c.string })
    hl(0, 'Character', { fg = c.string })
    hl(0, 'Number', { fg = c.const })
    hl(0, 'Float', { fg = c.const })
    hl(0, 'Boolean', { fg = c.const })
    hl(0, 'Identifier', { fg = c.fg })
    hl(0, 'Function', { fg = c.func })
    hl(0, 'Statement', { fg = c.keyword })
    hl(0, 'Conditional', { fg = c.keyword })
    hl(0, 'Repeat', { fg = c.keyword })
    hl(0, 'Exception', { fg = c.keyword })
    hl(0, 'Keyword', { fg = c.keyword })
    hl(0, 'Include', { fg = c.keyword })
    hl(0, 'PreProc', { fg = c.keyword })
    hl(0, 'Macro', { fg = c.keyword })
    hl(0, 'Operator', { fg = c.fg })
    hl(0, 'Delimiter', { fg = '#8a919e' })
    hl(0, 'Type', { fg = c.type })
    hl(0, 'StorageClass', { fg = c.keyword })
    hl(0, 'Structure', { fg = c.type })
    hl(0, 'Special', { fg = c.special })
    hl(0, 'Error', { fg = c.error, bold = true })
    hl(0, 'Todo', { fg = '#000000', bg = c.warn, bold = true })

    -- Diagnósticos
    hl(0, 'DiagnosticError', { fg = c.error })
    hl(0, 'DiagnosticWarn', { fg = c.warn })
    hl(0, 'DiagnosticInfo', { fg = c.info })
    hl(0, 'DiagnosticHint', { fg = c.string })
    hl(0, 'DiagnosticUnderlineError', { undercurl = true, sp = c.error })
    hl(0, 'DiagnosticUnderlineWarn', { undercurl = true, sp = c.warn })

    -- Diff
    hl(0, 'DiffAdd', { bg = '#10261a' })
    hl(0, 'DiffDelete', { fg = '#7a2a35', bg = '#2a0f14' })
    hl(0, 'DiffChange', { bg = '#151f2e' })
    hl(0, 'DiffText', { bg = '#26395a', bold = true })
end

local function gruber()
    local hl = vim.api.nvim_set_hl

    local c = {
        bg      = '#000000',
        fg      = '#e4e4ef', -- fg original do Gruber
        dim     = '#6c6468',
        keyword = '#ffdd33', -- amarelo: keywords e fluxo de controle
        func    = '#96a6c8', -- niagara: funções
        string  = '#73c936', -- verde: strings
        type    = '#8fc0ae', -- quartz esverdeado: tipos e estruturas
        const   = '#9e95c7', -- wisteria: números, booleanos, constantes
        comment = '#cc8c3c', -- marrom: comentários
        special = '#e8636b', -- vermelho suave: escapes e especiais
        error   = '#f43841',
        warn    = '#ffdd33',
        info    = '#96a6c8',
        sel     = '#303540', -- niagara-2
        line    = '#161616',
    }

    -- Base / UI
    hl(0, 'Normal', { fg = c.fg, bg = c.bg })
    hl(0, 'NormalFloat', { fg = c.fg, bg = '#0c0c0c' })
    hl(0, 'FloatBorder', { fg = '#484848', bg = '#0c0c0c' })
    hl(0, 'SignColumn', { bg = c.bg })
    hl(0, 'LineNr', { fg = '#52494e', bg = c.bg })
    hl(0, 'CursorLine', { bg = c.line })
    hl(0, 'CursorLineNr', { fg = c.keyword, bg = c.bg, bold = true })
    hl(0, 'NonText', { fg = '#2a2a2a', bg = c.bg })
    hl(0, 'SpecialKey', { fg = '#2a2a2a', bg = c.bg })
    hl(0, 'EndOfBuffer', { fg = c.bg, bg = c.bg })
    hl(0, 'ColorColumn', { bg = c.line })
    hl(0, 'StatusLine', { fg = '#f4f4ff', bg = '#232323' })
    hl(0, 'StatusLineNC', { fg = c.dim, bg = '#0c0c0c' })
    hl(0, 'VertSplit', { fg = '#303030', bg = c.bg })
    hl(0, 'WinSeparator', { fg = '#303030', bg = c.bg })
    hl(0, 'Visual', { bg = c.sel })
    hl(0, 'Search', { fg = c.keyword, bg = '#453d41' })
    hl(0, 'IncSearch', { fg = '#000000', bg = c.keyword, bold = true })
    hl(0, 'MatchParen', { fg = c.keyword, bg = '#2a2a2a', bold = true })
    hl(0, 'Pmenu', { fg = c.fg, bg = '#121212' })
    hl(0, 'PmenuSel', { fg = '#ffffff', bg = c.sel, bold = true })
    hl(0, 'PmenuSbar', { bg = '#232323' })
    hl(0, 'PmenuThumb', { bg = '#484848' })
    hl(0, 'Folded', { fg = c.dim, bg = c.line })
    hl(0, 'Title', { fg = c.func, bold = true })
    hl(0, 'Directory', { fg = c.func })
    hl(0, 'TabLine', { fg = c.dim, bg = '#0c0c0c' })
    hl(0, 'TabLineSel', { fg = '#ffffff', bg = '#232323', bold = true })
    hl(0, 'TabLineFill', { fg = c.fg, bg = '#0c0c0c' })

    -- Sintaxe
    hl(0, 'Comment', { fg = c.comment })
    hl(0, 'Constant', { fg = c.const })
    hl(0, 'String', { fg = c.string })
    hl(0, 'Character', { fg = c.string })
    hl(0, 'Number', { fg = c.const })
    hl(0, 'Float', { fg = c.const })
    hl(0, 'Boolean', { fg = c.const })
    hl(0, 'Identifier', { fg = c.fg })
    hl(0, 'Function', { fg = c.func })
    hl(0, 'Statement', { fg = c.keyword })
    hl(0, 'Conditional', { fg = c.keyword })
    hl(0, 'Repeat', { fg = c.keyword })
    hl(0, 'Exception', { fg = c.keyword })
    hl(0, 'Keyword', { fg = c.keyword })
    hl(0, 'Include', { fg = c.keyword })
    hl(0, 'PreProc', { fg = c.keyword })
    hl(0, 'Macro', { fg = c.keyword })
    hl(0, 'Operator', { fg = c.fg })
    hl(0, 'Delimiter', { fg = '#a0a0ab' })
    hl(0, 'Type', { fg = c.type })
    hl(0, 'StorageClass', { fg = c.keyword })
    hl(0, 'Structure', { fg = c.type })
    hl(0, 'Special', { fg = c.special })
    hl(0, 'Error', { fg = c.error, bold = true })
    hl(0, 'Todo', { fg = '#000000', bg = c.warn, bold = true })

    -- Diagnósticos
    hl(0, 'DiagnosticError', { fg = c.error })
    hl(0, 'DiagnosticWarn', { fg = c.warn })
    hl(0, 'DiagnosticInfo', { fg = c.info })
    hl(0, 'DiagnosticHint', { fg = c.type })
    hl(0, 'DiagnosticUnderlineError', { undercurl = true, sp = c.error })
    hl(0, 'DiagnosticUnderlineWarn', { undercurl = true, sp = c.warn })

    -- Diff
    hl(0, 'DiffAdd', { bg = '#10240f' })
    hl(0, 'DiffDelete', { fg = '#7a2a30', bg = '#2a0f12' })
    hl(0, 'DiffChange', { bg = '#171c28' })
    hl(0, 'DiffText', { bg = '#303a52', bold = true })
end

local function github_dark()
    local hl = vim.api.nvim_set_hl

    local c = {
        bg      = '#0d1117',
        fg      = '#e6edf3',
        dim     = '#7d8590',

        keyword = '#ff7b72', -- if, for, while, return, import...
        func    = '#d2a8ff', -- funções
        string  = '#a5d6ff', -- strings
        type    = '#ffa657', -- tipos / classes
        const   = '#79c0ff', -- números, booleanos, constantes
        comment = '#8b949e', -- comentários
        special = '#79c0ff', -- escapes / especiais

        error   = '#f85149',
        warn    = '#d29922',
        info    = '#58a6ff',

        sel     = '#264f78',
        line    = '#161b22',
    }

    -- Base / UI
    hl(0, 'Normal', { fg = c.fg, bg = c.bg })
    hl(0, 'NormalFloat', { fg = c.fg, bg = '#161b22' })
    hl(0, 'FloatBorder', { fg = '#30363d', bg = '#161b22' })
    hl(0, 'SignColumn', { bg = c.bg })

    hl(0, 'LineNr', { fg = '#484f58', bg = c.bg })
    hl(0, 'CursorLine', { bg = c.line })
    hl(0, 'CursorLineNr', { fg = '#e3b341', bg = c.bg, bold = true })

    hl(0, 'NonText', { fg = '#21262d', bg = c.bg })
    hl(0, 'SpecialKey', { fg = '#21262d', bg = c.bg })
    hl(0, 'EndOfBuffer', { fg = c.bg, bg = c.bg })
    hl(0, 'ColorColumn', { bg = c.line })

    hl(0, 'StatusLine', { fg = c.fg, bg = '#161b22' })
    hl(0, 'StatusLineNC', { fg = c.dim, bg = '#0d1117' })

    hl(0, 'VertSplit', { fg = '#30363d', bg = c.bg })
    hl(0, 'WinSeparator', { fg = '#30363d', bg = c.bg })

    hl(0, 'Visual', { bg = c.sel })

    hl(0, 'Search', {
        fg = '#0d1117',
        bg = '#e3b341',
    })

    hl(0, 'IncSearch', {
        fg = '#0d1117',
        bg = '#e3b341',
        bold = true,
    })

    hl(0, 'MatchParen', {
        fg = '#ffffff',
        bg = '#30363d',
        bold = true,
    })

    -- Completion
    hl(0, 'Pmenu', {
        fg = c.fg,
        bg = '#161b22',
    })

    hl(0, 'PmenuSel', {
        fg = '#ffffff',
        bg = '#264f78',
        bold = true,
    })

    hl(0, 'PmenuSbar', {
        bg = '#21262d',
    })

    hl(0, 'PmenuThumb', {
        bg = '#484f58',
    })

    hl(0, 'Folded', {
        fg = c.dim,
        bg = c.line,
    })

    hl(0, 'Title', {
        fg = c.func,
        bold = true,
    })

    hl(0, 'Directory', {
        fg = c.func,
    })

    -- Tabline
    hl(0, 'TabLine', {
        fg = c.dim,
        bg = '#161b22',
    })

    hl(0, 'TabLineSel', {
        fg = '#ffffff',
        bg = '#21262d',
        bold = true,
    })

    hl(0, 'TabLineFill', {
        fg = c.fg,
        bg = '#0d1117',
    })

    -- Sintaxe
    hl(0, 'Comment', { fg = c.comment })

    hl(0, 'Constant', { fg = c.const })
    hl(0, 'String', { fg = c.string })
    hl(0, 'Character', { fg = c.string })

    hl(0, 'Number', { fg = c.const })
    hl(0, 'Float', { fg = c.const })
    hl(0, 'Boolean', { fg = c.const })

    hl(0, 'Identifier', { fg = c.fg })
    hl(0, 'Function', { fg = c.func })

    hl(0, 'Statement', { fg = c.keyword })
    hl(0, 'Conditional', { fg = c.keyword })
    hl(0, 'Repeat', { fg = c.keyword })
    hl(0, 'Exception', { fg = c.keyword })
    hl(0, 'Keyword', { fg = c.keyword })

    hl(0, 'Include', { fg = c.keyword })
    hl(0, 'PreProc', { fg = c.keyword })
    hl(0, 'Macro', { fg = c.keyword })

    hl(0, 'Operator', { fg = c.fg })
    hl(0, 'Delimiter', { fg = '#8b949e' })

    hl(0, 'Type', { fg = c.type })
    hl(0, 'StorageClass', { fg = c.keyword })
    hl(0, 'Structure', { fg = c.type })

    hl(0, 'Special', { fg = c.special })

    hl(0, 'Error', {
        fg = c.error,
        bold = true,
    })

    hl(0, 'Todo', {
        fg = '#0d1117',
        bg = '#e3b341',
        bold = true,
    })

    -- Diagnósticos
    hl(0, 'DiagnosticError', { fg = c.error })
    hl(0, 'DiagnosticWarn', { fg = c.warn })
    hl(0, 'DiagnosticInfo', { fg = c.info })
    hl(0, 'DiagnosticHint', { fg = c.type })

    hl(0, 'DiagnosticUnderlineError', {
        undercurl = true,
        sp = c.error,
    })

    hl(0, 'DiagnosticUnderlineWarn', {
        undercurl = true,
        sp = c.warn,
    })

    -- Diff
    hl(0, 'DiffAdd', {
        bg = '#12261e',
    })

    hl(0, 'DiffDelete', {
        fg = '#ff7b72',
        bg = '#2d1617',
    })

    hl(0, 'DiffChange', {
        bg = '#17243a',
    })

    hl(0, 'DiffText', {
        bg = '#264f78',
        bold = true,
    })
end

function ColorMyPencils(color)
    --color = color or "alabaster"

    local ok = pcall(vim.cmd.colorscheme, color)
    if not ok then
        return
    end

    dark()
    --gruber()
    --theme()
    --github_dark()
    remove_all_italics()

    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    vim.api.nvim_set_hl(0, "LineNr", { fg = "#393939" })
    vim.api.nvim_set_hl(0, "MsgArea", { bg = "none" })

    vim.api.nvim_set_hl(0, "TabLine", { bg = "none" })
    vim.api.nvim_set_hl(0, "TabLineFill", { bg = "none" })
    vim.api.nvim_set_hl(0, "WinSeparator", { bg = "none" })
    vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" })
    vim.api.nvim_set_hl(0, "Pmenu", { bg = "none" })
    vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
    vim.api.nvim_set_hl(0, "FoldColumn", { bg = "none" })
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    vim.api.nvim_set_hl(0, "LineNr", { fg = "#b5b5b5" })
    vim.api.nvim_set_hl(0, "MsgArea", { bg = "none" })
    vim.api.nvim_set_hl(0, "TabSep", { fg = "#555555" })
    vim.api.nvim_set_hl(0, "WinBar", { bg = "none" })
    vim.api.nvim_set_hl(0, "WinBarNC", { bg = "none" })
    vim.api.nvim_set_hl(0, "TabLineSel", { bold = true, fg = "#e5c07b" })

    -- local float_bg = "#1e1e1e"
    -- vim.api.nvim_set_hl(0, "NormalFloat", { bg = float_bg })
    -- vim.api.nvim_set_hl(0, "FloatBorder", { bg = float_bg })
    -- vim.api.nvim_set_hl(0, "Pmenu", { bg = float_bg })
end

ColorMyPencils()
