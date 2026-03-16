{...}: {
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
          command = "dprint";
          args = ["fmt" "--stdin" "file.c"];
        };
      }
      {
        name = "cpp";
        auto-format = true;
        formatter = {
          command = "dprint";
          args = ["fmt" "--stdin" "file.cpp"];
        };
      }
      {
        name = "nix";
        auto-format = true;
        formatter = {
          command = "dprint";
          args = ["fmt" "--stdin" "file.nix"];
        };
      }
      {
        name = "rust";
        auto-format = true;
        formatter = {
          command = "dprint";
          args = ["fmt" "--stdin" "file.rs"];
        };
      }
      {
        name = "python";
        auto-format = true;
        formatter = {
          command = "dprint";
          args = ["fmt" "--stdin" "file.py"];
        };
      }
      {
        name = "javascript";
        auto-format = true;
        formatter = {
          command = "dprint";
          args = ["fmt" "--stdin" "file.js"];
        };
      }
      {
        name = "typescript";
        auto-format = true;
        formatter = {
          command = "dprint";
          args = ["fmt" "--stdin" "file.ts"];
        };
      }
      {
        name = "json";
        auto-format = true;
        formatter = {
          command = "dprint";
          args = ["fmt" "--stdin" "file.json"];
        };
      }
      {
        name = "markdown";
        auto-format = true;
        formatter = {
          command = "dprint";
          args = ["fmt" "--stdin" "file.md"];
        };
      }
      {
        name = "toml";
        auto-format = true;
        formatter = {
          command = "dprint";
          args = ["fmt" "--stdin" "file.toml"];
        };
      }
      {
        name = "bash";
        auto-format = true;
        formatter = {
          command = "dprint";
          args = ["fmt" "--stdin" "file.sh"];
        };
      }
    ];
  };

  programs.zsh.shellAliases = {
    h = "hx";
    hmhx = "hx $HM/modules/apps/helix.nix";
  };
}
