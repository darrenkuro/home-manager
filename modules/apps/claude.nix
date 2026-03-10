{ config, lib, pkgs, claude-plugins-official, obsidian-skills, ... }:
let
  claudeConfigDir = ../../configs/claude;

  # Extract skill-only plugins from the official repo into a flat skills directory
  officialSkills = pkgs.runCommand "claude-official-skills" {} ''
    mkdir -p $out

    # Plugins with skills/ directories — copy skill dirs directly
    cp -r ${claude-plugins-official}/plugins/frontend-design/skills/* $out/
    cp -r ${claude-plugins-official}/plugins/claude-code-setup/skills/* $out/
    cp -r ${claude-plugins-official}/plugins/claude-md-management/skills/* $out/
    cp -r ${claude-plugins-official}/plugins/skill-creator/skills/* $out/

    # Convert commands to skills format (commands/*.md → skills/<name>/SKILL.md)
    for cmd in ${claude-plugins-official}/plugins/claude-md-management/commands/*.md; do
      name=$(basename "$cmd" .md)
      mkdir -p "$out/$name"
      cp "$cmd" "$out/$name/SKILL.md"
    done
    for cmd in ${claude-plugins-official}/plugins/commit-commands/commands/*.md; do
      name=$(basename "$cmd" .md)
      mkdir -p "$out/$name"
      cp "$cmd" "$out/$name/SKILL.md"
    done
  '';

  mergedSkills = pkgs.symlinkJoin {
    name = "claude-skills-merged";
    paths = [
      (claudeConfigDir + "/skills")
      officialSkills
      (obsidian-skills + "/skills")
    ];
  };
in
{
  xdg.configFile = {
    "claude/CLAUDE.md".source = claudeConfigDir + "/CLAUDE.md";
    "claude/skills".source = mergedSkills;
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

  # Post-activation check: warn if skill-only plugins are still enabled
  home.activation.checkClaudePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.config/claude/settings.json"
    if [ -f "$settings" ]; then
      dupes=""
      for plugin in frontend-design claude-code-setup claude-md-management commit-commands skill-creator; do
        if ${pkgs.gnugrep}/bin/grep -q "\"$plugin@claude-plugins-official\": true" "$settings" 2>/dev/null; then
          dupes="$dupes  - $plugin@claude-plugins-official\n"
        fi
      done
      if [ -n "$dupes" ]; then
        echo ""
        echo "⚠ Claude: these plugins are now managed as hm skills and should be disabled:"
        printf "$dupes"
        echo "Run: claude /plugin disable <name> — or set to false in settings.json"
        echo ""
      fi
    fi
  '';

  programs.zsh.shellAliases = {
    clauded = "claude --dangerously-skip-permissions";
  };
}
