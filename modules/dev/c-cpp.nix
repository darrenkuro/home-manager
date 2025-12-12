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
          command = "~/.nix-profile/bin/clang-format";
          args = [ "-style=file" ]; # respect .clang-format if present
        };
      }
      {
        name = "cpp";
        auto-format = true;
        formatter = {
          command = "~/.nix-profile/bin/clang-format";
          args = [ "-style=file" ];
        };
      }
    ];
  };

  # programs.vscode.profiles.default.userSettings = {

  #   "C_Cpp.clang_format_path" = "${pkgs.clang-tools}/bin/clang-format";

  #   # "clangd.arguments" = [
  #   #   "--background-index"
  #   #   "--clang-tidy"
  #   #   "--completion-style=detailed"
  #   #   "--header-insertion=iwyu"
  #   # ];

  #   "[c]" = {
  #     "editor.defaultFormatter" = "ms-vscode.cpptools";
  #   };
  #   "[cpp]" = {
  #     "editor.defaultFormatter" = "ms-vscode.cpptools";
  #   };

  #   # "clang-format.style" = "file";
  # };
}
