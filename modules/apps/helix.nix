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

  programs.helix.languages = {
    language = [
      {
        name = "c";
        auto-format = true;
        formatter = {
          command = "~/.nix-profile/bin/clang-format";
          args = [ "-style=file" ];
        };
      }
      {
        name = "cpp";
        auto-format = true;
        formatter = {
          command = "~/.nix-profile/bin/clang-format";
          args = [ "-style=file" ];
        };
      }
      {
        name = "nix";
        auto-format = true;
        formatter = {
          command = "alejandra";
          args = [ "-q" ]; # quiet mode
        };
      }
      {
        name = "rust";
        auto-format = true;
        formatter = {
          command = "rustfmt";
          args = [
            "--emit"
            "files"
          ];
        };
      }
      {
        name = "python";
        auto-format = true;
        formatter = {
          command = "black";
          args = [ "-" ]; # reads from stdin
        };
      }
      {
        name = "javascript";
        auto-format = true;
        formatter = {
          command = "prettierd";
          args = [ "--stdin-filepath" ];
        };
      }
      {
        name = "typescript";
        auto-format = true;
        formatter = {
          command = "prettierd";
          args = [ "--stdin-filepath" ];
        };
      }
      {
        name = "*";
        auto-format = false;
        path = "dr-quine/**";
      }
    ];
  };

  programs.zsh.shellAliases = {
    h = "hx";
    hmhx = "hx $HM/modules/apps/helix.nix";
  };
}
