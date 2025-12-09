{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gcc # C and C++ compiler (includes g++)
    clang-tools # Clang-based tools (clangd, clang-format, clang-tidy)
    # gdb # Debugger
    # cmake # Build system generator
    # pkg-config # Library configuration helper
  ];

  # Formatter Style
  home.file.".clang-format".text = ''
    BasedOnStyle: LLVM
    IndentWidth: 4
    TabWidth: 4
    UseTab: Never
    ColumnLimit: 100
    AlwaysBreakTemplateDeclarations: true
    BreakBeforeBraces: Attach
    AllowShortFunctionsOnASingleLine: Inline
    SpaceBeforeParens: ControlStatements
  '';

  programs.helix.languages = {
    language = [
      {
        name = "c";
        auto-format = true;
        formatter = {
          command = "${pkgs.clang-tools}/bin/clang-format";
          args = [ "-style=file" ]; # respect .clang-format if present
        };
      }
      {
        name = "cpp";
        auto-format = true;
        formatter = {
          command = "${pkgs.clang-tools}/bin/clang-format";
          args = [ "-style=file" ];
        };
      }
    ];
  };

  programs.vscode = {
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        # Keep only lightweight syntax highlighting and clang-format UI glue
        ms-vscode.cpptools # required for file associations and debug UI, not IntelliSense
        # xaver.clang-format # optional; provides VSCode integration only, uses system clang-format
        # llvm-vs-code-extensions.vscode-clangd # optional: clangd support
      ];

      userSettings = {
        "C_Cpp.clang_format_path" = "${pkgs.clang-tools}/bin/clang-format"; # use the Nix binary
        "clangd.arguments" = [
          "--background-index"
          "--clang-tidy"
          "--completion-style=detailed"
          "--header-insertion=iwyu"
        ];

        # 🧹 Formatting
        "[c]" = {
          "editor.formatOnSave" = true;
          "editor.defaultFormatter" = "ms-vscode.cpptools";
        };
        "[cpp]" = {
          "editor.formatOnSave" = true;
          "editor.defaultFormatter" = "ms-vscode.cpptools";
        };

        "clang-format.style" = "file"; # read .clang-format from repo
      };
    };
  };
}
