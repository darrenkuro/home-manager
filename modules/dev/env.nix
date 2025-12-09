{ pkgs, ... }:
{
  home.packages = with pkgs; [
    dotenv-linter # Checks for malformed or duplicated entries
  ];

  programs.helix.languages.language = [
    {
      name = "dotenv";
      scope = "source.env";
      auto-format = false; # no formatter, just lint support
      # No official LSP for .env, but we can hook dotenv-linter as formatter-like checker
      formatter = {
        command = "${pkgs.dotenv-linter}/bin/dotenv-linter";
        args = [ "." ];
      };
    }
  ];

  programs.vscode = {
    profiles.default = {

      userSettings = {
        "[dotenv]" = {
          "editor.formatOnSave" = true;
          "editor.defaultFormatter" = "mikestead.dotenv";
        };

        "files.associations" = {
          "*.env" = "dotenv";
          ".env.*" = "dotenv";
        };
      };
    };
  };
}
