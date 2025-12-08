{ pkgs, ... }:
{
  home.packages = with pkgs; [
    alejandra # Formatter
    nil # LS
  ];

  programs.helix.languages = {
    language = [
      {
        name = "nix";
        language-servers = [
          {
            command = "nil";
          }
        ];
        auto-format = true;
        formatter = {
          command = "alejandra";
          args = [ "-q" ]; # quiet mode
        };
      }
    ];
  };

  programs.vscode = {
    profiles.default.extensions = with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
    ];

    profiles.default.userSettings = {
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = "nil";

      "[nix]" = {
        "editor.defaultFormatter" = null;
        "editor.formatOnSave" = true;
      };

      "nix.formatterPath" = "alejandra";
      "nix.formatterArgs" = [ "-q" ]; # quiet mode
    };
  };
}
