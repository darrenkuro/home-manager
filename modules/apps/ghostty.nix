{...}: {
  # Writes ~/.config/ghostty/config (one of Ghostty's default search paths).
  # We only manage the config file, not the binary — Ghostty.app is installed
  # separately in /Applications, so no `programs.ghostty` (which would pull the
  # Nix package). Read-only symlink into the store; edit configs/ghostty/config
  # then `re` to apply.
  xdg.configFile."ghostty/config".source = ../../configs/ghostty/config;

  programs.zsh.shellAliases = {
    hmghost = "hx $HM/configs/ghostty/config";
  };
}
