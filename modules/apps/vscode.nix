{pkgs,...}: {
  programs.vscode = {
	  enable = true;

    extensions = with pkgs.vscode-extensions; [
      pkief.material-icon-theme
      github.github-vscode-theme
    ];

    userSettings = {
      "editor.minimap.enabled" = false;
      "workbench.iconTheme" = "material-icon-theme";
      "workbench.colorTheme" = "GitHub Dark";
    };
  };
}
