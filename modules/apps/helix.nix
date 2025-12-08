{ ... }:
{
  programs.helix = {
    enable = true;
    defaultEditor = true;

    settings = {
      theme = "onedark";

      editor = {
        soft-wrap.enable = true;
        true-color = true;
        color-modes = true;

        whitespace = {
          render.tab = "all";
          characters.tab = "→";
        };
      };
    };
  };

  programs.zsh.shellAliases = {
    h = "hx";
    hmhx = "hx $HM/modules/apps/helix.nix";
  };
}
