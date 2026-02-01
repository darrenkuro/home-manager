{ config, ... }: {
  xdg.configFile."claude/settings.json".source = ../../configs/claude-settings.json;
  xdg.configFile."claude/CLAUDE.md".source = ../../configs/CLAUDE.md;

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
  };
}
