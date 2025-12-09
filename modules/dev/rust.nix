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

  programs.vscode.profiles.default.userSettings = {
    "[rust]" = {
      "editor.defaultFormatter" = "rust-lang.rust-analyzer";
    };

    "rust-analyzer.cargo.autoreload" = true;
    "rust-analyzer.procMacro.enable" = true;
    "rust-analyzer.check.command" = "clippy";

    "rust-analyzer.inlayHints.typeHints.enable" = false;
    # "rust-analyzer.inlayHints.parameterHints.enable" = false;
  };
}
