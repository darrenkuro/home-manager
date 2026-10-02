-- Neovim config that mirrors Helix's out-of-the-box feel.
-- Installed by modules/apps/neovim.nix (plugins come from nixpkgs, nothing
-- is downloaded at runtime). Keymaps follow Helix's <space>/g menus where
-- that doesn't fight a core vim key; which-key shows them on demand.

-- ── Options ──────────────────────────────────────────────────────────────
vim.g.mapleader = " "
vim.g.maplocalleader = ","
-- Remote-plugin hosts are off in neovim.nix; keep :checkhealth quiet about them
for _, prov in ipairs({ "python3", "ruby", "node", "perl" }) do
    vim.g["loaded_" .. prov .. "_provider"] = 0
end

local o = vim.o
o.number = true
o.relativenumber = true -- hybrid: current line absolute, others relative
o.cursorline = true
o.signcolumn = "yes"
o.scrolloff = 5
o.termguicolors = true
o.mouse = "a"
o.wrap = true -- helix soft-wrap
o.linebreak = true
o.breakindent = true
o.list = true -- helix whitespace.render.tab = all
o.listchars = "tab:→ ,nbsp:␣"
o.tabstop = 4
o.shiftwidth = 4
o.expandtab = true
o.ignorecase = true
o.smartcase = true
o.splitright = true
o.splitbelow = true
o.confirm = true
o.updatetime = 250
o.timeoutlen = 400
o.undofile = true -- what helix lacks: undo survives restarts (~/.local/state/nvim/undo)
o.autoread = true -- what helix lacks: reload files changed on disk
o.foldlevel = 99 -- what helix lacks: folding (tree-sitter driven, zc/zo/zM/zR)
o.foldmethod = "expr"
o.foldexpr = "v:lua.vim.treesitter.foldexpr()"

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "TermClose" }, {
    command = "checktime",
})
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "json", "jsonc", "yaml" },
    callback = function() vim.bo.shiftwidth = 2 end,
})
-- 'number'/'relativenumber' are window-local; explorers (snacks picker, netrw)
-- open with them off, and a file opened into that window inherits the off state.
-- Re-assert hybrid numbers whenever a real file (buftype "") lands in a window.
vim.api.nvim_create_autocmd("BufWinEnter", {
    callback = function(ev)
        if vim.bo[ev.buf].buftype == "" then
            vim.wo.number = true
            vim.wo.relativenumber = true
        end
    end,
})

require("onedark").load()

-- ── Tree-sitter (nvim-treesitter main branch: parsers are on the runtimepath,
--    nothing to install; it just needs starting per buffer) ────────────────
vim.api.nvim_create_autocmd("FileType", {
    callback = function(ev)
        if pcall(vim.treesitter.start, ev.buf) then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
    end,
})

-- ── LSP (nvim 0.12 native; nvim-lspconfig only supplies server definitions)
local servers = {
    "nil_ls", "clangd", "rust_analyzer", "ts_ls", "pyright", "ruff", "asm_lsp",
    "sourcekit", "bashls", "marksman", "taplo", "jsonls", "cssls", "html",
}
vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
vim.lsp.enable(servers)

vim.diagnostic.config({
    virtual_text = { spacing = 2 }, -- helix shows diagnostics at end of line
    severity_sort = true,
    float = { border = "rounded" },
})

-- ── Completion ───────────────────────────────────────────────────────────
require("blink.cmp").setup({
    keymap = { preset = "default" }, -- <C-space> open, <C-y> accept, <C-n>/<C-p> move
    completion = { documentation = { auto_show = true } },
    signature = { enabled = true },
})

-- ── Pickers / explorer / indent guides / reference highlight ─────────────
require("snacks").setup({
    picker = { enabled = true },
    explorer = { enabled = true },
    indent = { enabled = true },
    words = { enabled = true },
    bigfile = { enabled = true },
})

-- ── Editing: pairs, surround, statusline (mode-colored like helix) ────────
require("mini.pairs").setup()
require("mini.surround").setup() -- sa/sd/sr (helix ms/mr/md); `s` is free in normal mode
require("mini.statusline").setup()

-- ── Format on save → dprint (same as helix languages.toml), LSP fallback ──
local dprint = { "dprint" }
require("conform").setup({
    formatters_by_ft = {
        c = dprint, cpp = dprint, nix = dprint, rust = dprint, python = dprint,
        javascript = dprint, typescript = dprint, javascriptreact = dprint,
        typescriptreact = dprint, json = dprint, jsonc = dprint, markdown = dprint,
        toml = dprint, sh = dprint, bash = dprint, swift = dprint,
    },
    format_on_save = { timeout_ms = 2000, lsp_format = "fallback" },
})

require("gitsigns").setup()

-- ── Multiple cursors (helix-style) ───────────────────────────────────────
local mc = require("multicursor-nvim")
mc.setup()
local map = vim.keymap.set
map({ "n", "x" }, "<C-Down>", function() mc.lineAddCursor(1) end, { desc = "Add cursor below (helix C)" })
map({ "n", "x" }, "<C-Up>", function() mc.lineAddCursor(-1) end, { desc = "Add cursor above (helix A-C)" })
map({ "n", "x" }, "<C-n>", function() mc.matchAddCursor(1) end, { desc = "Add cursor at next match" })
map({ "n", "x" }, "<leader>A", mc.matchAllAddCursors, { desc = "Cursor at every match" })
map("x", "s", mc.matchCursors, { desc = "Select regex in selection (helix s)" })
map("x", "S", mc.splitCursors, { desc = "Split selection on regex (helix S)" })
mc.addKeymapLayer(function(layer)
    layer({ "n", "x" }, "<left>", mc.prevCursor)
    layer({ "n", "x" }, "<right>", mc.nextCursor)
    layer({ "n", "x" }, "<leader>,", mc.clearCursors, { desc = "Keep primary cursor (helix ,)" })
    layer("n", "<esc>", function()
        if not mc.cursorsEnabled() then mc.enableCursors() else mc.clearCursors() end
    end)
end)

-- ── Keymaps (helix <space> / g menus) ────────────────────────────────────
local p = function(name) return function() Snacks.picker[name]() end end
map("n", "<leader>f", p("files"), { desc = "File picker" })
map("n", "<leader>F", function() Snacks.picker.files({ cwd = vim.fn.expand("%:p:h") }) end, { desc = "File picker (buffer dir)" })
map("n", "<leader>b", p("buffers"), { desc = "Buffer picker" })
map("n", "<leader>/", p("grep"), { desc = "Global search" })
map("n", "<leader>j", p("jumps"), { desc = "Jumplist picker" })
map("n", "<leader>'", p("resume"), { desc = "Last picker" })
map("n", "<leader>?", p("commands"), { desc = "Command palette" })
map("n", "<leader>g", p("git_status"), { desc = "Changed files picker" })
map("n", "<leader>s", p("lsp_symbols"), { desc = "Document symbols" })
map("n", "<leader>S", p("lsp_workspace_symbols"), { desc = "Workspace symbols" })
map("n", "<leader>d", p("diagnostics_buffer"), { desc = "Diagnostics (buffer)" })
map("n", "<leader>D", p("diagnostics"), { desc = "Diagnostics (workspace)" })
map("n", "<leader>e", function() Snacks.explorer() end, { desc = "File explorer" })

map("n", "<leader>r", vim.lsp.buf.rename, { desc = "Rename symbol" })
map({ "n", "x" }, "<leader>a", vim.lsp.buf.code_action, { desc = "Code action" })
map("n", "<leader>k", vim.lsp.buf.hover, { desc = "Hover docs" })
map("n", "gd", p("lsp_definitions"), { desc = "Goto definition" })
map("n", "gD", p("lsp_declarations"), { desc = "Goto declaration" })
map("n", "gy", p("lsp_type_definitions"), { desc = "Goto type definition" })
map("n", "gr", p("lsp_references"), { desc = "Goto references" })
map("n", "gi", p("lsp_implementations"), { desc = "Goto implementation" })

map({ "n", "x" }, "<leader>c", "gcc", { remap = true, desc = "Toggle comment" })
map("x", "<leader>c", "gc", { remap = true, desc = "Toggle comment" })
map({ "n", "x" }, "<C-c>", "gcc", { remap = true, desc = "Toggle comment (helix C-c)" })
map({ "n", "x" }, "<leader>y", '"+y', { desc = "Yank to clipboard" })
map({ "n", "x" }, "<leader>p", '"+p', { desc = "Paste from clipboard" })
map("n", "<leader>w", "<C-w>", { remap = true, desc = "Window" })
map("n", "<leader>q", "<cmd>confirm quit<cr>", { desc = "Quit" })
map("n", "ga", "<C-^>", { desc = "Alternate buffer" })
map("n", "gh", "0", { desc = "Line start" })
map("n", "gl", "$", { desc = "Line end" })
map("n", "U", "<C-r>", { desc = "Redo" })
map("n", "<esc>", "<cmd>nohlsearch<cr>")
-- Native, worth knowing: ]d/[d diagnostics, ]b/[b buffers, grn/gra/grr/gri
-- (0.11 LSP defaults), gcc comment, K hover, <C-o>/<C-i> jumplist, zc/zo folds.

require("which-key").setup({ preset = "helix", delay = 300 })
