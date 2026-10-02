{ pkgs, ... }: # Neovim configured to match what Helix ships out of the box (LSP, tree-sitter,
# pickers, multi-cursor, surround, pairs, format-on-save via dprint, git gutter).
# Plugins are pinned by nixpkgs — no lazy.nvim, no network at startup.
# Language servers are the same PATH binaries Helix uses (see home.nix);
# the few Helix lacks an LSP for are added here via extraPackages.
# Lua lives in configs/nvim/init.lua (not dprint-formatted: no Lua plugin).
{
    programs.neovim = {
        enable = true;
        defaultEditor = false; # Helix keeps $EDITOR until nvim earns it
        vimAlias = false; # system vim stays `vim` (see home.nix vimrc)
        # No remote-plugin hosts: nothing here uses them, and they bloat the closure
        withPython3 = false;
        withRuby = false;
        withNodeJs = false;

        initLua = builtins.readFile ../../configs/nvim/init.lua;

        plugins = with pkgs.vimPlugins;
        [
            nvim-treesitter.withAllGrammars # highlight / indent / folds; parsers prebuilt by nix
            nvim-lspconfig # server definitions only; nvim 0.12 vim.lsp.enable() does the rest
            blink-cmp # completion (rust fuzzy matcher, prebuilt by nix)
            snacks-nvim # pickers w/ preview, file explorer, indent guides, words
            mini-nvim # pairs, surround, statusline (mode-colored like Helix color-modes)
            conform-nvim # format-on-save → dprint, LSP fallback
            gitsigns-nvim # git gutter + hunk nav
            which-key-nvim # Helix-style key menus on <space>, g, ], [
            onedark-nvim
        ];

        extraPackages = with pkgs;
        [
            ripgrep # snacks grep / helix-style global search
            bash-language-server
            marksman # markdown
            taplo # toml
            vscode-langservers-extracted # json / css / html
        ];
    };

    programs.zsh.shellAliases = { v = "nvim"; hmnv = "nvim $HM/configs/nvim/init.lua"; };
}
