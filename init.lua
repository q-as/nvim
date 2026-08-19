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

------------------------------------------------------------
-- OPÇÕES BÁSICAS
------------------------------------------------------------
vim.deprecate = function() end
--vim.opt.guicursor = ""-- comando que faz com que seja bloco ao inves de linha
vim.opt.number = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt_local.laststatus = 0
vim.g.mapleader = " "
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt_local.ruler = false
vim.opt_local.showmode = true
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.timeoutlen = 300
vim.opt.updatetime = 50

vim.cmd([[
function! Modified_Get()
    return &modified ? '[+]' : ''
endfunction
]])

vim.o.statusline = " [FILENAME: %t] %= [TYPE: %Y] [LINE: %l/%L : %c] [%p%%] %{Modified_Get()}"
vim.o.laststatus = 2
vim.o.shortmess = vim.o.shortmess .. "atI"
vim.o.cmdheight = 1

------------------------------------------------------------
-- AUTOPAIRS NATIVO (INDEPENDENTE DE PLUGINS)
------------------------------------------------------------
local function setup_autopairs()
  local pairs_map = {
    ['('] = ')',
    ['['] = ']',
    ['{'] = '}',
    ['"'] = '"',
    ["'"] = "'",
    ['`'] = '`',
  }

  local function insert_pair(l, r)
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local before = line:sub(1, col)
    local after = line:sub(col + 1)

    if after:sub(1, 1) == r then
      vim.api.nvim_win_set_cursor(0, { vim.fn.line('.'), col + 1 })
    else
      vim.api.nvim_set_current_line(before .. l .. r .. after)
      vim.api.nvim_win_set_cursor(0, { vim.fn.line('.'), col + 1 })
    end
  end

  for l, r in pairs(pairs_map) do
    vim.keymap.set('i', l, function()
      insert_pair(l, r)
    end, { noremap = true, silent = true })
  end
end

setup_autopairs()

------------------------------------------------------------
-- COMPILE / RUN (estilo M-x compile do Emacs)
------------------------------------------------------------
local compile_state = { bufnr = nil, last_cmd = nil }

local function open_compile_buffer()
  if compile_state.bufnr and vim.api.nvim_buf_is_valid(compile_state.bufnr) then
    vim.bo[compile_state.bufnr].modifiable = true
  else
    compile_state.bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[compile_state.bufnr].bufhidden = "hide"
    vim.bo[compile_state.bufnr].buftype = "nofile"
    vim.bo[compile_state.bufnr].filetype = "compilation"
    vim.api.nvim_buf_set_name(compile_state.bufnr, "*compilation*")
  end

  local visible = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == compile_state.bufnr then
      visible = true
      break
    end
  end

  if not visible then
    vim.cmd("belowright 12split")
    vim.api.nvim_win_set_buf(0, compile_state.bufnr)
  end

  return compile_state.bufnr
end

local function append_lines(bufnr, lines)
  if not lines or #lines == 0 then return end
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
end

local function run_compile(cmd)
  compile_state.last_cmd = cmd
  local bufnr = open_compile_buffer()

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "$ " .. cmd, "" })

  vim.fn.jobstart(cmd, {
    shell = true,
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      if vim.api.nvim_buf_is_valid(bufnr) then append_lines(bufnr, data) end
    end,
    on_stderr = function(_, data)
      if vim.api.nvim_buf_is_valid(bufnr) then append_lines(bufnr, data) end
    end,
    on_exit = function(_, code)
      if not vim.api.nvim_buf_is_valid(bufnr) then return end
      append_lines(bufnr, { "", "[processo finalizado, código " .. code .. "]" })

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      vim.fn.setqflist({}, ' ', {
        title = cmd,
        lines = lines,
        efm = vim.o.errorformat,
      })

      -- Erro real = código de saída diferente de 0
      local has_error = (code ~= 0)

      if has_error then
        local qf = vim.fn.getqflist()
        for i, item in ipairs(qf) do
          if item.valid == 1 then
            -- Abre a quickfix e pula pro arquivo/linha do erro,
            -- sem fechar o buffer de output
            vim.cmd("copen")
            vim.cmd("cc " .. i)
            break
          end
        end
        vim.notify("Compilação falhou (código " .. code .. ")", vim.log.levels.ERROR)
      else
        vim.notify("Compilação concluída com sucesso (código " .. code .. ")", vim.log.levels.INFO)
      end
    end,
  })
end

------------------------------------------------------------
-- DASHBOARD PERSONALIZADO
-- (Lightweight, sem dependências externas)
------------------------------------------------------------
local function setup_dashboard()
    vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("Dashboard", { clear = true }),
        callback = function()
            -- Não mostrar dashboard se abrir com arquivos
            if vim.fn.argc() > 0 then return end

            -- Não mostrar se o buffer já tem conteúdo
            local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            if #lines > 1 or (#lines == 1 and #lines[1] > 0) then return end

            -- Criar e configurar buffer
            local buf = vim.api.nvim_create_buf(false, true)
            vim.bo[buf].bufhidden = "wipe"
            vim.bo[buf].buftype = "nofile"
            vim.bo[buf].filetype = "dashboard"

            vim.api.nvim_win_set_buf(0, buf)

            -- Configurações visuais limpas
            local win = 0
            vim.opt_local.number = false
            vim.opt_local.relativenumber = false
            vim.opt_local.cursorline = false
            vim.opt_local.cursorcolumn = false
            vim.opt_local.signcolumn = "no"
            vim.opt_local.fillchars = { eob = " " }

            -- Esconder cursor no dashboard
            local original_guicursor = vim.o.guicursor
            vim.api.nvim_set_hl(0, "DashboardCursor", { blend = 100, nocombine = true })

            local function hide_cursor()
                vim.opt.guicursor = "a:DashboardCursor"
            end

            local function restore_cursor()
                vim.opt.guicursor = original_guicursor
            end

            hide_cursor()

            -- Restaurar cursor ao sair
            vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "VimLeavePre" }, {
                buffer = buf,
                callback = restore_cursor,
            })

            vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
                buffer = buf,
                callback = hide_cursor,
            })

            -- Conteúdo do dashboard
            local logo = {
            }

            local menu = {
                "[n] New File ",
                "[f] Find File",
                "    [e] File Explorer",
                " [wq] Quit     ",
            }

            -- Centralizar conteúdo
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

            -- Escrever conteúdo
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
            vim.bo[buf].modifiable = false

            -- Keymaps do dashboard
            local opts = { buffer = buf, noremap = true, silent = true }

            -- Novo arquivo
            vim.keymap.set("n", "n", function()
                restore_cursor()
                vim.cmd("enew")
            end, opts)

            -- Gerenciador de arquivos (tecla 'e')
                        vim.keymap.set("n", "e", function()
                            restore_cursor()
                            vim.cmd.Ex()
                        end, opts)

            -- Buscar arquivos (usando fzf-lua)
            vim.keymap.set("n", "f", function()
                restore_cursor()
                if pcall(require, 'fzf-lua') then
                    require('fzf-lua').files()
                else
                    vim.notify("FZF-Lua não está carregado", vim.log.levels.WARN)
                end
            end, opts)

            -- Sair
            vim.keymap.set("n", "wq", ":q!<CR>", opts)
        end,
    })
end

------------------------------------------------------------
-- PACKER + PLUGINS (SEM CONFIG DURANTE BOOTSTRAP)
------------------------------------------------------------
require('packer').startup(function(use)
  use 'wbthomason/packer.nvim'
  use {
      'ibhagwan/fzf-lua',
      requires = { 'nvim-lua/plenary.nvim' },
  }
  use {
      'williamboman/mason.nvim',
      tag = 'v1.10.0', -- estável
  }
  use { 'tahayvr/matteblack.nvim', as = 'matteblack' }
  use 'xero/miasma.nvim'
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
  use 'rose-pine/neovim'
  use 'theprimeagen/harpoon'
  use "sindrets/diffview.nvim"

  use "folke/which-key.nvim"

  use 'dchinmay2/alabaster.nvim'

  use 'martinsione/darkplus.nvim'

  use {
      'nvim-tree/nvim-tree.lua',
      requires = { 'nvim-tree/nvim-web-devicons' },
  }

  use {
      'williamboman/mason-lspconfig.nvim',
      tag = 'v1.0.0', -- compatível com mason v1.x
      requires = { 'williamboman/mason.nvim' },
  }

  if packer_bootstrap then
    require('packer').sync()
  end
end)

------------------------------------------------------------
-- CONFIGURAÇÕES APÓS INSTALAÇÃO
------------------------------------------------------------
local function post_install_setup()
  -- Setup do dashboard primeiro (sem dependências)
  setup_dashboard()

  -- Plugins
  pcall(function()
      require('fzf-lua').setup({
          winopts = {
              height = 0.85,
              width = 0.85,
              row = 0.5,
              col = 0.5,
              border = 'rounded',
          },
          files = {
              prompt = 'Files❯ ',
          },
          grep = {
              prompt = 'Grep❯ ',
          },
      })
  end)

  pcall(function()
      require("mason").setup()
  end)

  pcall(function()
      require('blink.cmp').setup({
          -- 🔥 Aceitar com TAB e navegação com setas
          keymap = {
              preset = 'default',
              ['<C-Space>'] = { 'show', 'show_documentation', 'hide_documentation' },
              ['<Tab>'] = { 'accept', 'fallback' },  -- TAB aceita a sugestão
              ['<S-Tab>'] = { 'select_prev', 'fallback' },
              ['<C-n>'] = { 'select_next', 'fallback' },
              ['<C-p>'] = { 'select_prev', 'fallback' },
              ['<C-e>'] = { 'hide' },
              ['<C-y>'] = { 'accept' },
          },

          -- ⚡ COMPLETION MAIS RÁPIDO
          completion = {
              documentation = {
                  auto_show = false,  -- Desativar docs automáticas para não atrasar
              },
              menu = {
                  auto_show = true,
                  draw = {
                      columns = { { "label", "label_description", gap = 1 } },
                  },
              },
              -- Mostrar sugestões mais rápido
              list = {
                  max_items = 10,  -- Limitar itens para performance
                  selection = {
                      preselect = true,  -- Pré-selecionar o primeiro item
                  },
              },
          },

          -- ⚡ SOURCES MAIS RÁPIDOS
          sources = {
              default = { 'lsp', 'path', 'snippets', 'buffer' },
              -- Cache para buffer e path (mais rápido)
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
                          min_keyword_length = 2,  -- Reduzir mínimo de caracteres
                          max_entries = 100,        -- Limitar para performance
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
              -- REMOVIDO: prefilter = true, -- Este campo não existe mais
          },
      })
  end)

  -- 🔥 GARANTIR INSTALAÇÃO DO PYRIGHT E VTSLS
  require("mason-lspconfig").setup({
      ensure_installed = { 
          "lua_ls",
          "pyright",        -- Python LSP
          "vtsls",          -- TypeScript/JavaScript LSP (mais completo que tsserver)
      },
      automatic_installation = true, -- Instala automaticamente se não estiver presente
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

      -- Configuração específica para pyright (opcional)
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

      -- Configuração específica para vtsls (opcional)
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

      vim.keymap.set("n", "<leader>a", mark.add_file)
      vim.keymap.set("n", "<C-e>", ui.toggle_quick_menu)

      vim.keymap.set("n", "<leader>1", function() ui.nav_file(1) end)
      vim.keymap.set("n", "<leader>2", function() ui.nav_file(2) end)
      vim.keymap.set("n", "<leader>3", function() ui.nav_file(3) end)
      vim.keymap.set("n", "<leader>4", function() ui.nav_file(4) end)
  end)

  pcall(function()
      require('nvim-tree').setup({
         disable_netrw = false,   -- deixa o netrw vivo
          hijack_netrw = false,    -- não sequestra
          hijack_directories = {
              enable = false,      -- não abre ao entrar em diretório
          },
          view = {
              width = 30,
              side = 'left',
          },
          filters = {
              dotfiles = false,
          },
          update_focused_file = {
              enable = true,
          },
      })
  end)


  pcall(function()
      require('diffview').setup({
          view = {
              default = {
                  --layout = "diff2_vertical",  
                  layout = "diff2_horizontal",
              },
              file_history = {
                  --layout = "diff2_vertical",
                  layout = "diff2_horizontal",
              },
          },
          panel = {
              position = "left",
              width = 20,
              --position = "bottom",
              --height = 16,
          },
      })
  end)

  pcall(function()
      local wk = require("which-key")
      wk.setup({
          preset = "helix", -- modern classic
          delay = 300,
      })

      wk.add({
          -- Grupos principais
          { "<leader>w", group = "window/write" },
          { "<leader>g", group = "git" },
          { "<leader>v", group = "lsp" },

          -- Write / quit / arquivo
          { "<leader>ww", desc = "Write file" },
          { "<leader>wq", desc = "Quit" },
          { "<leader>q",  desc = "Close tab" },
          { "<leader>e",  desc = "Explorer (netrw)" },
          { "<leader>n",  desc = "New file" },
          -- 
          -- Splits e navegação de janela
          { "<leader>wv", desc = "Vertical split" },
          { "<leader>ws", desc = "Horizontal split" },
          { "<leader>wh", desc = "Go to left window" },
          { "<leader>wj", desc = "Go to below window" },
          { "<leader>wk", desc = "Go to above window" },
          { "<leader>wl", desc = "Go to right window" },
          -- 
          -- Terminal / ferramentas externas
          { "<leader>t", desc = "Open terminal split (zsh)" },
          { "<leader>i", desc = "Open agy in vsplit" },
          { "<leader>o", desc = "Open opencode in vsplit" },
          -- 
          -- -- Diffview / NvimTree / Undotree
          { "<leader>d", desc = "Diffview open" },
          { "<leader>b", desc = "Toggle NvimTree" },
          { "<leader>u", desc = "Toggle Undotree" },
          -- 
          -- Tabs
          { "<leader><Tab>",   desc = "Next tab" },
          { "<leader><S-Tab>", desc = "Previous tab" },
          { "<leader>N", desc = "New tab" },
          -- 
          -- Git (fugitive + fzf-lua)
          { "<leader>gt", desc = "Git status (fugitive)" },
          { "<leader>gl", desc = "Git log (fzf-lua)" },
          { "<leader>gs", desc = "Git status (fzf-lua)" },
          { "<leader>gd", desc = "Git branches (fzf-lua)" },
          { "<leader>gb", desc = "Git file history (fzf-lua)" },
          { "<leader>gg", desc = "Git Grep (fzf-lua)" },
          { "<leader>gc", desc = "Git commit" },
          -- 
          -- -- LSP
          { "<leader>vww", desc = "Workspace symbol" },
          { "<leader>vd",  desc = "Open diagnostic float" },
          { "<leader>vca", desc = "Code action" },
          { "<leader>vr",  desc = "LSP references" },
          { "<leader>vrn", desc = "LSP rename" },
          -- 
          -- FZF (fora do grupo leader-w/g/v)
          { "<leader>f", desc = "FZF find files" },
          { "<leader>z", desc = "Live grep" },
          { "<leader>s", desc = "Fuzzy find in current buffer" },
          { "<leader>a", desc = "Harpoon: add file" },
          { "<leader>1", desc = "Harpoon: file 1" },
          { "<leader>2", desc = "Harpoon: file 2" },
          { "<leader>3", desc = "Harpoon: file 3" },
          { "<leader>4", desc = "Harpoon: file 4" },
          -- 
          -- Comment toggle (modo visual)
          { "<leader>m", desc = "Toggle comment", mode = "v" },
      })
  end)

  -- Cores
  vim.cmd('hi statusline guibg=NONE')


  -- Keymaps globais
  vim.keymap.set('n', '<leader>ww', ':write<CR>')
  vim.keymap.set('n', '<leader>wq', ':quit<CR>')
  vim.keymap.set('n', '<leader>e', vim.cmd.Ex)
  vim.keymap.set('n', '<leader>n', ':enew<CR>', { desc = 'New File' })
  vim.keymap.set('n', '<leader>q', ':tabclose<CR>')

  vim.keymap.set('n', '<leader>wv', ':vsplit<CR>', { silent = true })
  vim.keymap.set('n', '<leader>ws', ':split<CR>', { silent = true })

  vim.keymap.set('n', '<leader>wh', '<C-w>h')
  vim.keymap.set('n', '<leader>wj', '<C-w>j')
  vim.keymap.set('n', '<leader>wk', '<C-w>k')
  vim.keymap.set('n', '<leader>wl', '<C-w>l')

  vim.keymap.set('n', '<leader>t', ':belowright 12split term://zsh<CR>', { silent = true })
  vim.keymap.set('n', '<leader>i', function()
      vim.cmd('vsplit')
      vim.cmd('wincmd l')
      vim.cmd('vertical resize 50')
      vim.cmd('terminal cmd.exe /k agy')
  end, { silent = true, desc = 'Open CLI' })
  vim.keymap.set('n', '<leader>d', ':DiffviewOpen<CR>', { silent = true, desc = 'Diffview' })
  vim.keymap.set('n', '<leader>b', ':NvimTreeToggle<CR>', { silent = true, desc = 'Toggle NvimTree' })
  vim.keymap.set('n', '<leader><Tab>', ':tabnext<CR>', { silent = true, desc = 'Next tab' })
  vim.keymap.set('n', '<leader><S-Tab>', ':tabprevious<CR>', { silent = true, desc = 'Last tab' })
  vim.keymap.set('n', '<leader>N', ':tabnew<CR>', { silent = true, desc = 'New tab' })
  vim.keymap.set('n', '<leader>cc', function()
      local input = vim.fn.input("Compile command: ", compile_state.last_cmd or "")
      if input and input ~= "" then
          run_compile(input)
      end
  end, { silent = true, desc = "Compile/Run project" })

  vim.keymap.set('n', ']e', ':cnext<CR>zz', { silent = true, desc = "Next error" })
  vim.keymap.set('n', '[e', ':cprevious<CR>zz', { silent = true, desc = "Previous error" })
  vim.keymap.set('n', '<leader>co', ':copen<CR>', { silent = true, desc = "Open quickfix" })

  vim.keymap.set('n', '<leader>u', vim.cmd.UndotreeToggle)
  vim.keymap.set('n', '<leader>gt', vim.cmd.Git)

  vim.keymap.set('n', '<leader>gl', function()
      require('fzf-lua').git_commits()  -- Log visual
  end, { desc = 'Git Log (fzf-lua)' })

  vim.keymap.set('n', '<leader>gs', function()
      require('fzf-lua').git_status()  -- Status com preview
  end, { desc = 'Git Status (fzf-lua)' })

  vim.keymap.set('n', '<leader>gd', function()
      require('fzf-lua').git_branches()  -- Lista branches
  end, { desc = 'Git Branches (fzf-lua)' })

  vim.keymap.set('n', '<leader>gb', function()
      require('fzf-lua').git_bcommits()  -- Histórico do arquivo
  end, { desc = 'Git File History (fzf-lua)' })

  vim.keymap.set('n', '<leader>gc', ':Git commit<CR>', { silent = true, desc = 'Git commit' })

  vim.keymap.set('n', '<C-p>', function()
      require('fzf-lua').git_files()  -- Histórico do arquivo
  end, { desc = 'Git Files (fzf-lua)' })

  vim.keymap.set("n", "gd", vim.lsp.buf.definition)
  vim.keymap.set("n", "K", vim.lsp.buf.hover)
  vim.keymap.set("n", "<leader>vww", vim.lsp.buf.workspace_symbol)
  vim.keymap.set("n", "<leader>vd", vim.diagnostic.open_float)
  vim.keymap.set("n", "[d", vim.diagnostic.goto_next)
  vim.keymap.set("n", "]d",vim.diagnostic.goto_prev)
  vim.keymap.set("n", "<leader>vca", vim.lsp.buf.code_action)
  vim.keymap.set("n", "<leader>vrr", vim.lsp.buf.references)
  vim.keymap.set("n", "<leader>rr",vim.lsp.buf.rename)
  vim.keymap.set("i", "<C-h>",  vim.lsp.buf.signature_help)

  vim.keymap.set('n', '<leader>f', function()
      require('fzf-lua').files()
  end, { desc = 'FZF Files' })

  vim.keymap.set('n', '<leader>z', function()
      require('fzf-lua').live_grep()
  end, { desc = 'Live grep' })

  vim.keymap.set('n', '<leader>s', function()
      require('fzf-lua').blines()
  end, { desc = 'Fuzzy find in current buffer' })

  vim.keymap.set('n', '<leader>gg', function()
      require('fzf-lua').live_grep({
          cmd = "git grep --line-number --column --color=always",
          prompt = 'GitGrep❯ ',
      })
  end, { desc = 'Live Grep (git files only)' })

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

      -- volta pro normal mode
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "n", false)
  end, { desc = "toggle comentário na seleção" })



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
          sync_install = true,
          auto_install = true,
          highlight = {
              enable = true,
          },
          indent = {
              enable = true,
          },
      })
  end)
end

------------------------------------------------------------
-- EXECUTA SETUP CORRETAMENTE
------------------------------------------------------------
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

function ColorMyPencils(color)
  color = color or "alabaster"
  --color = color or "tema"

  local ok = pcall(vim.cmd.colorscheme, color)
  if not ok then
    return
  end

  remove_all_italics()

  vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
  vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
  vim.api.nvim_set_hl(0, "LineNr", { fg = "#b5b5b5" })
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

end

ColorMyPencils()
