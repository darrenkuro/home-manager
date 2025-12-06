
  home.packages = with pkgs; [

    git
    gh


    # lf
    # bat



  home.file = {
    #".config/starship.toml".source = ../dotfiles/starship.toml;
    ".config/helix/config.toml".source = ../dotfiles/helix-conf.toml;
    ".config/helix/languages.toml".source = ../dotfiles/helix-languages.toml;
  }
  // (if tag == "mac" then {
    ".config/tmux/tmux.conf".source = ../dotfiles/tmux.mac.conf;
  } else {});

