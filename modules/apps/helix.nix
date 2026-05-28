{...}: let
  indent4 = { tab-width = 4; unit = "    "; };
  indent2 = { tab-width = 2; unit = "  "; };
  fmt = ext: {
    command = "dprint";
    args = ["fmt" "--stdin" "file.${ext}"];
  };
in {
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

  programs.helix.languages = {
    language = [
      { name = "c"; auto-format = true; indent = indent4; formatter = fmt "c"; }
      { name = "cpp"; auto-format = true; indent = indent4; formatter = fmt "cpp"; }
      { name = "nix"; auto-format = true; indent = indent4; formatter = fmt "nix"; }
      { name = "rust"; auto-format = true; indent = indent4; formatter = fmt "rs"; }
      { name = "python"; auto-format = true; indent = indent4; formatter = fmt "py"; }
      { name = "javascript"; auto-format = true; indent = indent4; formatter = fmt "js"; }
      { name = "typescript"; auto-format = true; indent = indent4; formatter = fmt "ts"; }
      { name = "json"; auto-format = true; indent = indent2; formatter = fmt "json"; }
      { name = "markdown"; auto-format = true; indent = indent4; formatter = fmt "md"; }
      { name = "toml"; auto-format = true; indent = indent4; formatter = fmt "toml"; }
      { name = "bash"; auto-format = true; indent = indent4; formatter = fmt "sh"; }
      { name = "swift"; auto-format = true; indent = indent4; formatter = fmt "swift"; }
    ];
  };

  programs.zsh.shellAliases = {
    h = "hx";
    hmhx = "hx $HM/modules/apps/helix.nix";
  };
}
