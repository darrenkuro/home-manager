{ config, pkgs, tag, ... }:

{
  imports = [
    ./alias.nix
   ];

  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    starship
    helix
    typescript-language-server
    llvmPackages_20.clang-tools
    
    #pyright
    
    git
    gh

    rust-analyzer
    rustc
    cargo

    nodejs_24
    pnpm
    
    tokei
    #trash

    eza   # ls
    fzf   
    fd    # find
    jq
    tmux
    lf
    bat
    # exiftool, ffuf
    # cmake
    # yarn, wget, yt-dlp, tor
    

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;
    ".config/starship.toml".source = ./starship.toml;
    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  home.sessionVariables = {
    # Home Directory Hygenie
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";

    DROPBOX = "/Users/darrenlu/Dropbox";
    DEV = "$HOME/Documents/dev";
    NIX = "$HOME/.config/home-manager";
    
    EDITOR = "hx";
    VISUAL = "hx";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  programs.zsh.enable = true;
  # Starship
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # Helix
  xdg.configFile."helix/config.toml".text = ''
    theme = "onedark"
    [editor]
    soft-wrap.enable = true
  '';
  xdg.configFile."helix/languages.toml".text = ''
    [[language]]
    name = "typescript"
    language-servers = ["typescript-language-server"]

    [[language]]
    name = "python"
    language-servers = ["pylsp"]

    [[language]]
    name = "rust"
    language-servers = ["rust-analyzer"]

    [[language]]
    name = "c"
    language-servers = ["clangd"]

    [[language]]
    name = "cpp"
    language-servers = ["clangd"]
  '';

  programs.lf = {
    enable = true;
    settings = {
      icons = true;
      preview = true;
      previewer = "~/.config/lf/preview.sh";
    };

    extraConfig = ''
      cmd open $${EDITOR:-hx} "$f"
      cmd open-multi $${EDITOR:-hx} "$fx"

      map <enter> open
      map o open-multi
      map s split
      cmd split tmux split-window -v hx "$f"
    '';
  };

  home.file.".config/lf/preview.sh".text = ''
    #!/usr/bin/env bash
    bat --color=always --style=plain "$1"
  '';

}
