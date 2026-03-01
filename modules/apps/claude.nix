{ config, ... }: {
  xdg.configFile."claude/settings.json".source = ../../configs/claude-settings.json;
  xdg.configFile."claude/CLAUDE.md".source = ../../configs/CLAUDE.md;

  # Set env CLAUDE_CONFIG_DIR at login so it will be found everywhere
  launchd.agents.set-claude-config-dir = {
    enable = true;
    config = {
      Label = "com.user.set-claude-config-dir";
      ProgramArguments = [
        "/bin/launchctl"
        "setenv"
        "CLAUDE_CONFIG_DIR"
        "${config.home.homeDirectory}/.config/claude"
      ];
      RunAtLoad = true;
    };

  programs.zsh.shellAliases = {
    clauded = "claude --dangerously-skip-permissions";
  };
  };
}
