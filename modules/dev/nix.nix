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
        auto-format = true;
        formatter = {
          command = "alejandra";
          args = [ "-q" ]; # quiet mode
        };
      }
    ];
  };

  programs.vscode.profiles.default.userSettings = {
    "nix.enableLanguageServer" = true;
    "nix.serverPath" = "nil";

    "[nix]" = {
      "editor.defaultFormatter" = null;
    };

    "nix.formatterPath" = "alejandra";
  };
}
