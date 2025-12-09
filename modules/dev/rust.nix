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

        auto-format = true;
        formatter = {
          command = "rustfmt";
          args = [
            "--emit"
            "files"
          ];
        };
      }
    ];
  };

  programs.vscode = {
    profiles.default = {
      # extensions = with pkgs.vscode-extensions; [
      #   rust-lang.rust-analyzer
      # ];

      userSettings = {
        "rust-analyzer.server.path" = "${pkgs.rust-analyzer}/bin/rust-analyzer";
        "rust-analyzer.rustfmt.path" = "${pkgs.rustfmt}/bin/rustfmt";

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
