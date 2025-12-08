{ pkgs, ... }:
{
  home.packages = with pkgs; [
    rustc # Compiler
    cargo # Package manager & Build tool
    rust-analyzer # LSP
    rustfmt # Formatter

    clippy
  ];

  programs.helix.languages = {
    language = [
      {
        name = "rust";

        language-server = {
          command = "rust-analyzer";
        };

        auto-format = true;
        formatter = {
          command = "rustfmt";
          args = [
            "--emit"
            "files"
          ]; # rewrite files in place
        };
      }
    ];
  };

  programs.vscode = {
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        rust-lang.rust-analyzer
      ];

      userSettings = {
        "rust-analyzer.server.path" = "rust-analyzer";

        "[rust]" = {
          "editor.formatOnSave" = true;
          "editor.defaultFormatter" = "rust-lang.rust-analyzer";
        };

        "rust-analyzer.cargo.autoreload" = true;
        "rust-analyzer.procMacro.enable" = true;
        "rust-analyzer.checkOnSave.command" = "clippy";

        "rust-analyzer.inlayHints.typeHints.enable" = false;
        # "rust-analyzer.inlayHints.parameterHints.enable" = false;
      };
    };
  };
}
