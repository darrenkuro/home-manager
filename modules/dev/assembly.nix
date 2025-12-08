{ pkgs, ... }:
{
  home.packages = with pkgs; [
    asm-lsp # LSP for Assembly (x86/x86_64)
    asmfmt # Formatter
  ];

  programs.helix.languages.language = [
    {
      name = "asm";
      scope = "source.asm";
      language-servers.command = "${pkgs.asm-lsp}/bin/asm-lsp";
      auto-format = true;
      formatter = {
        command = "${pkgs.asmfmt}/bin/asmfmt";
        args = [ ];
      };
    }
  ];

  programs.vscode = {
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        xforever.language-asm # syntax highlighting for .s/.asm/.S
      ];

      userSettings = {
        "[asm]" = {
          "editor.formatOnSave" = true;
          "editor.defaultFormatter" = "13xforever.language-asm";
        };
      };
    };
  };
}
