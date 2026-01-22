{ ... }: {
  xdg.configFile."claude/settings.json".source = ../../configs/claude-settings.json;
  xdg.configFile."claude/CLAUDE.md".source = ../../configs/CLAUDE.md;
}
