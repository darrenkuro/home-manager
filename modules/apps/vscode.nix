{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;

    profiles.default.extensions = with pkgs.vscode-extensions; [
      pkief.material-icon-theme
      github.github-vscode-theme
    ];

    profiles.default.userSettings = {
      "editor.fontFamily" = "Hack Nerd Font Mono, monospace";
      "workbench.iconTheme" = "material-icon-theme";
      "workbench.colorTheme" = "GitHub Dark";

      "editor.fontSize" = 14;
      "editor.tabSize" = 4;
      "editor.minimap.enabled" = false;
      "editor.detectIndentation" = false;

      "files.trimTrailingWhitespace" = true;
      "files.insertFinalNewline" = true;
      "security.workspace.trust.enabled" = true;
      "security.workspace.trust.startupPrompt" = "never";
      "security.workspace.trust.trustedFolders" = [
        "~/Documents/dev"
        "~/.config/home-manager"
      ];
    };
  };

  programs.zsh.shellAliases = {
    hmvs = "hx $HM/modules/apps/vscode.nix";
  };
}
