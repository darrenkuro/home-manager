{ config, ... }:
let
  claudeConfigDir = ../../configs/claude;
in
{
  xdg.configFile = {
    "claude/CLAUDE.md".source = claudeConfigDir + "/CLAUDE.md";
    "claude/skills".source = claudeConfigDir + "/skills";
    "claude/hooks".source = claudeConfigDir + "/hooks";
  };

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
  };

  programs.zsh.shellAliases = {
    clauded = "claude --dangerously-skip-permissions";
  };
}
