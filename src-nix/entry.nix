{ config, pkgs, tag, ... }:

{
  imports = [ ./alias.nix ];

  home.stateVersion = "25.11";
  home.packages = with pkgs; [
    # Shared packages 
    starship
    helix

    nodejs_24  
    typescript-language-server
    llvmPackages_20.clang-tools
  
    git
    gh

    rust-analyzer
    rustc
    cargo

    tokei
    eza   # ls
    fzf   
    fd    # find
    jq
    tmux
    lf
    bat
    
  ] ++ (if tag == "mac" then [
    pnpm
    alacritty
    #ghostty-bin
    #anki
  ] else if tag == "ft" then [
    
  ] else []);

  home.file = {
    ".config/starship.toml".source = ../files/starship.toml;
    ".config/helix/config.toml".source = ../files/helix-conf.toml;
    ".config/helix/languages.toml".source = ../files/helix-languages.toml;
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

    BAT_THEME = "OneDark";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  programs.zsh.enable = true;

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
  
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
      cmd q quit
      map o open-multi
      map s split
      cmd split tmux split-window -v hx "$f"
    '';
  };

  programs.bat = {
    enable = true;
    config = { theme = "OneDark"; };
  };

  programs.git = {
    enable = true;
    #user.email = if tag == "ft" then "dlu@student.42berlin.de" else "odon5ht@gmail.com";
    settings = {
      user.name = "darrenkuro";
      user.email = "odon5ht@gmail.com";
      core.editor = "hx";
      color.ui = "auto";
      init.defaultBranch = "main";
    };
  };

  home.file.".config/lf/preview.sh" = {
    text = ''
      #!/usr/bin/env bash
      bat --color=always --style=plain "$1"
    '';
    executable = true;
  };
}
