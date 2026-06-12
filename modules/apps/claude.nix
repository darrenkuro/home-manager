# Claude Code configuration — skills, hooks, CLAUDE.md
#
# Cross-platform: imported on both macOS and Linux.
{ config, lib, pkgs, claude-plugins-official, obsidian-skills, claude-config, ... }: let
    claudeConfigDir = ../../configs/claude;

    # Plugins extracted as hm-managed skills (disable these in Claude Code)
    hmManagedPlugins = [
        "frontend-design"
        "claude-code-setup"
        "claude-md-management"
        "commit-commands"
        "skill-creator"
    ];

    # Plugins with skills/ dirs to copy directly
    skillPlugins = [ "frontend-design" "claude-code-setup" "claude-md-management" "skill-creator" ];

    # Plugins with commands/ dirs to convert to skills format
    commandPlugins = [ "claude-md-management" "commit-commands" ];

    # Required plugins that must remain installed via Claude Code
    requiredPlugins = [
        "typescript-lsp"
        "swift-lsp"
        "rust-analyzer-lsp"
        "clangd-lsp"
        "pyright-lsp"
        "context7"
        "explanatory-output-style"
        "learning-output-style"
    ];

    # Extract skill-only plugins from the official repo into a flat skills directory
    officialSkills = pkgs.runCommand "claude-official-skills" { } ''
    mkdir -p $out

    # Copy skills/ directories
    ${lib.concatMapStringsSep "\n"
    ( p: "cp -r ${claude-plugins-official}/plugins/${p}/skills/* $out/" ) skillPlugins}

    # Convert commands to skills format (commands/*.md → <name>/SKILL.md)
    ${lib.concatMapStringsSep "\n" ( p: ''
        for cmd in ${claude-plugins-official}/plugins/${p}/commands/*.md; do
          name=$(basename "$cmd" .md)
          mkdir -p "$out/$name"
          cp "$cmd" "$out/$name/SKILL.md"
        done
      '' ) commandPlugins}
  '';

    mergedSkills = pkgs.symlinkJoin {
        name = "claude-config-skills-merged";
        paths = [ ( claude-config + "/skills" ) officialSkills ( obsidian-skills + "/skills" ) ];
    };
in
{
    # Claude Code binary — native install, self-updating, deliberately outside Nix
    # (~/.local/bin/claude + ~/.local/share/claude). Bootstraps once if missing;
    # the binary handles its own updates afterwards.
    home.activation.claudeInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ ! -x "$HOME/.local/bin/claude" ]]; then
      echo "Installing Claude Code (native installer)..."
      PATH="${lib.makeBinPath [ pkgs.curl pkgs.bash ]}:$PATH" ${pkgs.bash}/bin/bash -c \
        'curl -fsSL https://claude.ai/install.sh | bash' \
        || echo "⚠ Claude Code install failed — run manually: curl -fsSL https://claude.ai/install.sh | bash"
    fi
  '';

    xdg.configFile = {
        "claude/CLAUDE.md".source = claudeConfigDir + "/CLAUDE.md";
        "claude/skills".source = mergedSkills;
        "claude/hooks".source = claude-config + "/hooks";
    };

    # settings.json — owned by Claude Code (writable, never symlinked); hm only
    # injects the hooks key via an idempotent jq merge that preserves all other keys.
    home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="${config.xdg.configHome}/claude/settings.json"
    # Remove old hm symlink if present
    if [[ -L "$settings" ]]; then
      rm "$settings"
    fi
    # Seed with empty object if missing
    if [[ ! -f "$settings" ]]; then
      echo '{}' > "$settings"
    fi
    ${pkgs.jq}/bin/jq '. * {"hooks":{"PreToolUse":[{"matcher":"Read|Edit|Write|MultiEdit|Bash","hooks":[{"type":"command","command":"~/.config/claude/hooks/protect-env.sh"}]}]}}' \
      "$settings" > "$settings.tmp" \
      && mv "$settings.tmp" "$settings"
    chmod u+w "$settings"
  '';

    # Validate Claude Code plugin configuration
    home.activation.claudePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.config/claude/settings.json"
    if [ -f "$settings" ]; then
      # Plugins now managed as hm skills — warn if still enabled
      dupes=""
      for plugin in ${lib.concatStringsSep " " hmManagedPlugins}; do
        if ${pkgs.gnugrep}/bin/grep -q "\"$plugin@claude-plugins-official\": true" "$settings" 2>/dev/null; then
          dupes="$dupes  - $plugin@claude-plugins-official\n"
        fi
      done
      if [ -n "$dupes" ]; then
        echo ""
        echo "⚠ Claude: these plugins are now managed as hm skills and should be disabled:"
        printf "$dupes"
        echo "  Run: claude /plugin disable <name>"
        echo ""
      fi

      # Required plugins — warn if missing or disabled
      missing=""
      for plugin in ${lib.concatStringsSep " " requiredPlugins}; do
        if ! ${pkgs.gnugrep}/bin/grep -q "\"$plugin@claude-plugins-official\": true" "$settings" 2>/dev/null; then
          missing="$missing  - $plugin@claude-plugins-official\n"
        fi
      done
      if [ -n "$missing" ]; then
        echo ""
        echo "⚠ Claude: these required plugins are missing or disabled:"
        printf "$missing"
        echo "  Run: claude /plugin install <name>@claude-plugins-official"
        echo ""
      fi
    fi
  '';

    # cc = claude code
    programs.zsh.shellAliases = {
        ccd = "claude --dangerously-skip-permissions";
        clauded = "claude --dangerously-skip-permissions";
        ccu = "claude-usage";
    };
}
