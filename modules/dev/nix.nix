{pkgs, ...}: {
    home.packages = with pkgs; [ alejandra ];
  programs.helix.languages = {
      language = [
        {
          name = "nix";
          auto-format = true;
          formatter = {
            command = "alejandra";
            args = ["-q"]; # quiet mode
          };
        }
      ];
  };
  programs.vscode = {
  userSettings = {
    # Disable automatic extension-based formatting
    "editor.defaultFormatter" = null;

    # Format .nix files on save using the CLI binary
    "[nix]" = {
      "editor.formatOnSave" = true;
    };

    # Tell VS Code how to format Nix files manually
    "nix.formatterPath" = "alejandra";
    "nix.formatterArgs" = [ "-q" ]; # optional

    # # Optional global behavior
    # "editor.formatOnSaveMode" = "file";
  };
};
}