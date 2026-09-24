# nvim

[English](README.md)

Configuração do Neovim em Lua, com busca rápida, LSP, autocomplete,
Git, testes, formatação e atalhos organizados pelo `which-key`.

## Visão geral

### Neovim com OpenCode em split

![Neovim com OpenCode aberto em um split](https://i.postimg.cc/mkwVsBGx/Captura-de-ecra-de-2026-09-23-14-06-40.png)

### Menu dos principais recursos

Pressione `Space` para abrir o menu de atalhos.

![Menu de acesso aos principais recursos](https://i.postimg.cc/qvCbtfsW/nvim-plugin-menu.png)

### Color picker

Use `Space c p` para abrir o seletor de cores.

![Seletor de cores](https://i.postimg.cc/T1GQFhBx/Captura-de-ecra-de-2026-09-23-14-11-30.png)

### Busca no buffer atual

Use `Space s` para procurar no arquivo aberto.

![Busca no buffer atual](https://i.postimg.cc/8PTNBHKH/Captura-de-ecra-de-2026-09-23-14-34-13.png)

### Busca no projeto

Use `Space Space` para pesquisar o conteúdo dos arquivos.

![Busca com grep no projeto](https://i.postimg.cc/Dy7ndgj6/Captura-de-ecra-de-2026-09-23-14-35-02.png)

## Instalação

Requer [Neovim](https://neovim.io/) e Git. Faça backup de uma configuração
existente antes de clonar:

```sh
cd ~/.config
git clone https://github.com/kndrio/nvim.git
cd nvim
nvim init.lua
```

Dentro do Neovim, execute:

```vim
:so
:PackerSync
```

Reabra o Neovim após a instalação dos plugins.

## Principais Atalhos Padrões

| Shortcut | Action |
| --- | --- |
| `Space` | Show available shortcuts |
| `Space Space` | Search text across the project |
| `Space s` | Search the current buffer |
| `Space f` | Find files |
| `Space c p` | Open the color picker |
| `Space o` | Open OpenCode in a vertical split |
| `Space e` | Open the file explorer |
| `Space g t` | Open Git status |
| `Space z` | Toggle Zen mode |

## Keybinds do Neovim (init.lua – Linux)

- **Leader:** `<Space>` (`vim.g.mapleader = " "`)
- **timeoutlen:** 300 ms (o `which-key` aparece após 300 ms)
- Legenda de modos: **n** = normal, **v** = visual, **x** = visual (seleção), **o** = operator-pending, **i** = insert

---

## 1. Arquivo, janelas e abas

| Atalho | Modo | O que faz |
|---|---|---|
| `<leader>ww` | n | Salvar arquivo (`:write`) |
| `<leader>wq` | n | Sair da janela (`:quit`) |
| `<leader>e` | n | Abrir explorador netrw (`:Ex`) |
| `<leader>n` | n | Novo arquivo (`:enew`) |
| `<leader>q` | n | Fechar aba (`:tabclose`) |
| `<leader>wv` | n | Split vertical |
| `<leader>ws` | n | Split horizontal |
| `<leader>wh` | n | Ir para janela à esquerda |
| `<leader>wj` | n | Ir para janela abaixo |
| `<leader>wk` | n | Ir para janela acima |
| `<leader>wl` | n | Ir para janela à direita |
| `sv` | n | Split vertical |
| `ss` | n | Split horizontal |
| `sx` | n | Fechar janela atual |
| `<leader><Tab>` | n | Próxima aba |
| `<leader><S-Tab>` | n | Aba anterior |
| `<leader>N` | n | Nova aba (`:tabnew`) |
| `<leader><Left>` | n | Aumentar largura da janela (+20) |
| `<leader><Right>` | n | Diminuir largura da janela (−20) |
| `<leader><Up>` | n | Aumentar altura da janela (+10) |
| `<leader><Down>` | n | Diminuir altura da janela (−10) |
| `<leader>X` | n | `chmod +x` no arquivo atual |
| `<leader>lw` | n | Alternar quebra de linha (`wrap`) |

## 2. Navegação e edição

| Atalho | Modo | O que faz |
|---|---|---|
| `<S-h>` | n, o, x | Ir para o início da linha (`^`) |
| `<S-l>` | n, o, x | Ir para o fim da linha (`g_`) |
| `<C-u>` | n | Meia página para cima, centralizando (`zz`) |
| `<C-d>` | n | Meia página para baixo, centralizando (`zz`) |
| `n` | n | Próxima ocorrência da busca, centralizada |
| `N` | n | Ocorrência anterior da busca, centralizada |
| `<C-a>` | n | Selecionar o arquivo inteiro (`gg<S-v>G`) |
| `<` | v | Indentar para a esquerda mantendo a seleção |
| `>` | v | Indentar para a direita mantendo a seleção |
| `K` | v | Mover linhas selecionadas para cima |
| `J` | v | Mover linhas selecionadas para baixo |
| `x` | n | Apagar caractere **sem** copiar para o registrador |
| `<leader>dd` | n, v | Apagar **sem** copiar para o registrador (`"_d`) |
| `p` | x | Colar sobre a seleção **sem** perder o conteúdo copiado |
| `<leader>rr` | n | Substituir a palavra sob o cursor no arquivo todo (abre `:%s` já preenchido) |
| `<leader>m` | v | Comentar/descomentar as linhas selecionadas |
| `<leader>cf` | n | Copiar o nome/caminho do arquivo para o clipboard |

## 3. Busca e fuzzy finder (fzf-lua)

| Atalho | Modo | O que faz |
|---|---|---|
| `<leader>f` | n | Buscar arquivos |
| `<C-p>` | n | Buscar arquivos versionados pelo git |
| `<leader><leader>` | n | Live grep no projeto |
| `<leader>s` | n | Busca fuzzy nas linhas do buffer atual |
| `<leader>gg` | n | Live grep somente em arquivos do git (`git grep`) |
| `<leader>ch` | n | Buscar nas help tags |
| `<leader>ck` | n | Buscar keymaps |
| `<leader>cs` | n | Menu de pickers do fzf-lua (`builtin`) |
| `<leader>cw` | n | Grep da palavra sob o cursor |
| `<leader>cd` | n | Diagnósticos do documento |
| `<leader>cD` | n | Diagnósticos do workspace |
| `<C-x>` | n | Seletor de diretórios – muda o diretório da janela atual |
| `<leader>x` | n | Seletor de diretórios – abre em nova aba (`tcd`) |
| `<leader>/` | n | Pesquisa web (DuckDuckGo) em janela flutuante |

### Dentro da janela de pesquisa web

| Atalho | O que faz |
|---|---|
| `q` | Fechar a janela |
| `<Esc>` | Fechar a janela |
| `<CR>` | Abrir o link da linha atual no navegador (`xdg-open`) |

## 4. Git

| Atalho | Modo | O que faz |
|---|---|---|
| `<leader>gt` | n | Fugitive – `:Git` (status) |
| `<leader>gc` | n | `:Git commit` |
| `<leader>gl` | n | Log de commits (fzf-lua) |
| `<leader>gs` | n | Git status (fzf-lua) |
| `<leader>gd` | n | Branches (fzf-lua) |
| `<leader>gb` | n | Histórico do arquivo atual (fzf-lua) |
| `<leader>gg` | n | Git grep (fzf-lua) |
| `<leader>d` | n | Abrir Diffview |

## 5. LSP e diagnósticos

| Atalho | Modo | O que faz |
|---|---|---|
| `gd` | n | Ir para a definição |
| `K` | n | Hover (documentação) |
| `<leader>vww` | n | Buscar símbolo no workspace |
| `<leader>vd` | n | Abrir float de diagnóstico |
| `<leader>vca` | n | Code action |
| `<leader>vrr` | n | Referências |
| `<leader>vrn` | n | Renomear símbolo |
| `<C-h>` | i | Signature help |
| `[d` | n | Próximo diagnóstico (`goto_next`) |
| `]d` | n | Diagnóstico anterior (`goto_prev`) |
| `]e` | n | Próximo item da quickfix (centraliza) |
| `[e` | n | Item anterior da quickfix (centraliza) |
| `<leader>co` | n | Abrir quickfix |
| `<leader>T` | n | Trouble: diagnósticos |
| `<leader>lT` | n | Trouble: quickfix |

## 6. Harpoon

| Atalho | Modo | O que faz |
|---|---|---|
| `<leader>a` | n | Adicionar arquivo atual ao Harpoon |
| `<C-e>` | n | Abrir/fechar menu rápido do Harpoon |
| `<leader>1` | n | Ir para o arquivo 1 |
| `<leader>2` | n | Ir para o arquivo 2 |
| `<leader>3` | n | Ir para o arquivo 3 |
| `<leader>4` | n | Ir para o arquivo 4 |

## 7. Ferramentas, plugins e terminal

| Atalho | Modo | O que faz |
|---|---|---|
| `<leader>t` | n | Terminal `zsh` num split inferior (12 linhas) |
| `<leader>i` | n | Abrir `agy` num vsplit (largura 50) |
| `<leader>o` | n | Abrir `opencode` (modelo `litellm-pr/gemma4-saj`) num vsplit |
| `<leader>b` | n | Alternar NvimTree |
| `<leader>u` | n | Alternar Undotree |
| `<leader>z` | n | Zen Mode |
| `<leader>cp` | n | Abrir color picker (oklch) |
| `<leader>cP` | n | Color picker na cor sob o cursor |
| `<leader>ll` | n | Status do Packer (`:PackerStatus`) |
| `<leader>lm` | n | Abrir o Mason |

## 8. Múltiplos cursores (vim-visual-multi)

| Atalho | Modo | O que faz |
|---|---|---|
| `;s` | n | Selecionar a palavra sob o cursor (find under) |
| `;n` | n | Adicionar cursor na próxima ocorrência |
| `;a` | n | Selecionar todas as ocorrências |

## 9. Autocompletar (blink.cmp)

Preset `default` do blink.cmp + as seguintes customizações:

| Atalho | Modo | O que faz |
|---|---|---|
| `<C-Space>` | i | Mostrar menu / alternar documentação |
| `<Tab>` | i | Próximo item / avançar snippet |
| `<S-Tab>` | i | Item anterior / voltar snippet |
| `<C-n>` | i | Próximo item |
| `<C-p>` | i | Item anterior |
| `<C-y>` | i | Aceitar item |
| `<C-e>` | i | Esconder o menu |

## 10. Autopairs (customizado)

No modo **insert**, ao digitar o caractere de abertura o par é inserido automaticamente; se o próximo caractere já for o fechamento, o cursor apenas pula por cima dele.

| Digitado | Resultado |
|---|---|
| `(` | `()` |
| `[` | `[]` |
| `{` | `{}` |
| `"` | `""` |
| `'` | `''` |
| `` ` `` | ` `` ` |

## 11. Dashboard (tela inicial, sem argumentos)

Atalhos válidos apenas no buffer do dashboard:

| Atalho | O que faz |
|---|---|
| `n` | Novo arquivo |
| `f` | Buscar arquivo (fzf-lua) |
| `e` | Explorador de arquivos (`:Ex`) |
| `wq` | Sair (`:q!`) |