{ pkgs, config, tag, lib, ... }: {
    # ----------- Base Settings
    home.username = if tag == "mac"
    then
        "darrenlu"
    else if tag == "ft"
    then
        "dlu"
    else
        throw "Unknown tag: ${tag}";
    home.homeDirectory = if tag == "mac"
    then
        "/Users/darrenlu"
    else if tag == "ft"
    then
        "/home/dlu"
    else
        throw "Unknown tag: ${tag}";
    home.stateVersion = "25.11"; # Version when started using

    home.packages = with pkgs;
    [
        tokei
        eza
        fd
        jq
        fzf
        rename
        bat
        gettext # envsubst
        wakatime-cli
        clang-tools # C, CPP
        dprint # Unified formatter (nix, ts, json, md, toml, python, c/cpp, shell, rust, swift)
        nil # Nix LSP
        shfmt
        shellcheck
        cargo
        rust-analyzer
        rustfmt
        clippy
        asm-lsp
        asmfmt

        # Ensure Consistency
        openssl # Apple ships LibreSSL
        gnused # Apple ships BSD-sed
        cmake
        # nerd-fonts.hack — not cached for aarch64-darwin
        # cachix — not currently needed
    ] ++
    lib.optionals ( tag == "mac" ) [
        rustc
        nodejs_22 # LTS; nodejs_latest (v25) fails to build, nodejs_24 not cached for aarch64-darwin
        typescript
        typescript-language-server

        python313Packages.flake8

        python313
        python313Packages.pip
        python313Packages.virtualenv

        darwin.trash # Replace rm (safer)
        ffmpeg
        poppler-utils # PDF tools
        yt-dlp # Youtube download

        pnpm
        bun

        # Docker (via Colima)
        colima # Docker replacement
        docker-client
        docker-compose
        docker-buildx

        pandoc
        # typst — not currently needed
    ];

    # ── Activation Scripts ──
    home.activation = {
        # Create XDG state/cache directories for shell history, sessions, etc.
        xdgStateDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p \
          "$HOME/.local/state/zsh" \
          "$HOME/.local/state/bash" \
          "$HOME/.local/state/less" \
          "$HOME/.local/state/sessions" \
          "$HOME/.local/state/wakatime" \
          "$HOME/.cache/zsh"
      '';

        # Copy writable configs (VSCode, tmux; alacritty + tmux-nix on ft)
        writableConfigs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        HM="${config.home.homeDirectory}/.config/home-manager"
        XDG_CONFIG_HOME="${config.xdg.configHome}"
        HM_TAG="${lib.toUpper tag}"

        ${builtins.readFile ./scripts/copy-files.sh}
      '';
    };

    programs.home-manager.enable = true;
    programs.bash = {
        enable = true;
        historyFile = "${config.home.homeDirectory}/.local/state/bash/history";
        historySize = 100000;
        historyFileSize = 100000;
    };
    programs.zsh = {
        enable = true;
        dotDir = "${config.home.homeDirectory}/.config";
        history = {
            path = "${config.home.homeDirectory}/.local/state/zsh/history";
            size = 100000;
            save = 100000;
            ignoreDups = true; # Ignore when same cmd twice in a row
            share = true; # Share across terminal
            extended = true;
        };
        envExtra = builtins.readFile ./scripts/load-nix.sh;
        profileExtra = builtins.readFile ./scripts/nix-prepend-path.sh;
        initContent = lib.concatStringsSep "\n"
        (
            [
                ( builtins.readFile ./scripts/source.sh )
                ( builtins.readFile ./scripts/hygiene.sh )
            ] ++
            lib.optionals ( tag == "mac" ) [ ( builtins.readFile ./scripts/ssh-keychain.sh ) ] ++
            lib.optionals ( tag == "ft" ) [ ( builtins.readFile ./scripts/repeat-rate.sh ) ] );
    };
    programs.direnv = { enable = true; nix-direnv.enable = true; };

    fonts.fontconfig.enable = true;

    xdg.configFile."dprint/dprint.json".source = ./configs/dprint.json;

    imports = [
        ./modules/system/aliases.nix
        ./modules/system/env.nix

        ./modules/apps/starship.nix
        ./modules/apps/git.nix
        ./modules/apps/helix.nix
        ./modules/apps/claude.nix
        ./modules/apps/ssh.nix
    ] ++ lib.optionals ( tag == "mac" ) [
        ./modules/apps/netusage.nix

        # ── Services (user half; each also has a darwin.nix imported from darwin.nix) ──
        ./modules/services/postgresql/home.nix
    ];
}
