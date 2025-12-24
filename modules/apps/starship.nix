{...}: {
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    configPath = "$HM/configs/starship.toml"; #faster change
  };
  xdg.configFile."starship.toml".source = ../../configs/starship.toml;
  programs.zsh.shellAliases = {
    hmss = "hx $HM/modules/apps/starship.nix";
  };
}
