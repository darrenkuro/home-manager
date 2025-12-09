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

      set-option -g -a terminal-overrides ",xterm-256color:RGB" # ",xterm*:Tc"
      set-option -g -w mode-keys vi
      set-option -g -w pane-base-index 1
      set-option -g base-index 1
      set-option -g focus-events on

      set-option -g pane-active-border-style fg=#fb4934
      set-option -g pane-base-index 1
      set-option -g pane-border-format "#{?pane_active,#[fg=#000000 bg=#fb4934] #{pane_index}-#{pane_current_command} #[fg=#fb4934 bg=default], #{pane_index}-#{pane_current_command} }"
      set-option -g pane-border-status 'top'
      set-option -g pane-border-style fg=#fb4934
      set-option -g renumber-windows on
      set-option -g set-titles on
      set-option -g status-interval 1
      set-option -g status-left "#[bg=#fb4934,fg=#000000]  #{session_name} #[bg=#fe8019,fg=#fb4943]#[bg=#504945,fg=#fe8019]"
      set-option -g status-left-length 20
      set-option -g status-right "#[fg=#aaaaaa]#(2>/dev/null pomo && 2>/dev/null pomo | grep -Fq -- '-' && 2>/dev/null 1>&2 paplay '/home/tsi/Music/pomo-sound.mp3') #(set /proc/[0123456789]*;echo $# procs) #{pane_current_path} #[fg=#504945]#[bg=#504945,fg=#aaaaaa] #{user} #[bg=#504945,fg=#a89984] #[bg=#a89984,fg=#000000] #{host} 󰍹  #[bg=#a89984,fg=#fe8019]#[bg=#fe8019,fg=#fb4934]#[bg=#fb4934,fg=#000000] %H:%M:%S "
      set-option -g status-right-length 500
      set-option -g status-style bg=#3c3836,fg=#a89984
      set-option -g window-status-current-format "#[bg=#a89984,fg=#504945]#[fg=#282828] #{window_index}-#{window_name} #[bg=#504945,fg=#a89984]#{?#{==:#{window_index},#{session_windows}},#[bg=#3c3836],}"
      set-option -g window-status-format "#[bg=#504945,fg=#aaaaaa] #{window_index}-#{window_name} #{?#{==:#{window_index},#{session_windows}},#[bg=#3c3836 fg=#504945],}"
      set-option -g window-status-separator ""
    '';
  };

  programs.zsh.shellAliases = {
    hmtmux = "hx $HM/modules/apps/tmux.nix";
  };
}
