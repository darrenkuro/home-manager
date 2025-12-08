{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;

    profiles.default.extensions = with pkgs.vscode-extensions; [
      pkief.material-icon-theme
      github.github-vscode-theme
    ];

    profiles.default.userSettings = {
      "editor.fontFamily" = "FiraCode Nerd Font Mono, Menlo, Monaco, 'Courier New', monospace";
      "workbench.iconTheme" = "material-icon-theme";
      "workbench.colorTheme" = "GitHub Dark";

      "editor.fontSize" = 13;
      "editor.tabSize" = 4;
      "editor.minimap.enabled" = false;
      "editor.detectIndentation" = false;

      "files.trimTrailingWhitespace" = true;
      "files.insertFinalNewline" = true;
        "security.workspace.trust.enabled" = true;
  "security.workspace.trust.startupPrompt" = "never";
  "security.workspace.trust.trustedFolders" = ["~/Documents/dev"];
    };
  };
}
