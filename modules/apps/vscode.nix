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
      "material-icon-theme.activeIconPack" = "react";
      "material-icon-theme.opacity" = 0.8;
      "material-icon-theme.saturation" = 0.8;
      "material-icon-theme.folders.associations" = {
        "modals" = "interface";
        "commands" = "functions";
        "component" = "react-components";
        "to-process" = "error";
        "data-fetching" = "Api";
        "data-models" = "database";
        "entry-model" = "database";
        "experiment" = "project";
      };
      "material-icon-theme.files.associations" = {
        "svg.tsx" = "svgr";
        "constants.ts" = "tsconfig";
        "playground.ts" = "test-ts";
      };

      "workbench.colorTheme" = "GitHub Dark";

      "editor.fontSize" = 14;
      "editor.tabSize" = 4;
      "editor.insertSpaces" = false; # Use space for whitespaces
      "editor.minimap.enabled" = false;
      "editor.detectIndentation" = false;
      "editor.formatOnSave" = true;
      "editor.inlineSuggest.enabled" = true;

      "diffEditor.ignoreTrimWhitespace" = false;
      "editor.acceptSuggestionOnCommitCharacter" = false;
      "editor.suggestOnTriggerCharacters" = false;

      "files.trimTrailingWhitespace" = true;
      "files.insertFinalNewline" = true;
      "security.workspace.trust.enabled" = true;
      "security.workspace.trust.startupPrompt" = "never";
      "security.workspace.trust.trustedFolders" = [
        "~/Documents/dev"
        "~/.config/home-manager"
      ];

      "extensions.ignoreRecommendations" = true; # Ignore pop-up window
      "extensions.autoCheckUpdates" = false;
      "extensions.autoUpdate" = false;

      "explorer.confirmDragAndDrop" = false;
      "explorer.confirmDelete" = false;

      "git.enabled" = true;
      "git.autofetch" = true;
      "git.confirmSync" = false;
      "git.decorations.enabled" = true; # Show git status (M, U, D, etc.)
      "explorer.decorations.badges" = true;
      "explorer.decorations.colors" = true; # Dim files in gitignore
    };
  };

  programs.zsh.shellAliases = {
    hmvs = "hx $HM/modules/apps/vscode.nix";
  };
}
