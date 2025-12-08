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

      # disables pop-ups and notifications recommending extensions
      "extensions.showRecommendationsOnlyOnDemand" = true;
      "extensions.ignoreRecommendations" = true;

      # also disable Workspace / File-based suggestions
      "extensions.ignoreWorkspaceRecommendations" = true;
      "extensions.ignoreExtensionRecommendations" = true;

      # optional: removes extension suggestions from status bar
      "extensions.autoCheckUpdates" = false;
      "extensions.autoUpdate" = false;
    };
  };

  programs.zsh.shellAliases = {
    hmvs = "hx $HM/modules/apps/vscode.nix";
  };
}
