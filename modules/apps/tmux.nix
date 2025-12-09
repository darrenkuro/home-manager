{ ... }:
{
  programs.tmux = {
    enable = true;

    mouse = true;
    historyLimit = 100000;
    terminal = "xterm-256color";
    escapeTime = 10;
    extraConfig = ''
      unbind C-b
      set-option -g prefix C-Space
    '';
  };

  programs.zsh.shellAliases = {
    hmtmux = "hx $HM/modules/apps/tmux.nix";
  };
}
