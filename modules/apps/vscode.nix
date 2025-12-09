{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;

    # Extension is NOT mergable
    profiles.default.extensions = with pkgs.vscode-extensions; [
      pkief.material-icon-theme
      github.github-vscode-theme

      ms-python.python # main Python extension
      ms-python.vscode-pylance # language server (Pylance)
      ms-toolsai.jupyter # notebook support

      ms-vscode.cpptools # required for file associations and debug UI, not IntelliSense
      esbenp.prettier-vscode # Prettier formatter

      jnoortheen.nix-ide
      rust-lang.rust-analyzer

      ms-vscode.makefile-tools
      foxundermoon.shell-format # optional formatter frontend for shfmt
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
      "editor.insertSpaces" = true; # Use space for whitespaces
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
