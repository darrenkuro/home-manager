{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gnumake
    bash-language-server
    shfmt
  ];

  programs.helix.languages.language = [
    {
      name = "make";
      scope = "source.makefile";
      language-servers.command = "${pkgs.bash-language-server}/bin/bash-language-server";
      language-servers.args = [ "start" ];
      auto-format = true;
      formatter = {
        command = "${pkgs.shfmt}/bin/shfmt";
        args = [
          "-i"
          "4"
          "-bn"
          "-ci"
        ]; # indent, binary ops, case indent
      };
    }
  ];

  programs.vscode.profiles.default.userSettings = {
    "[makefile]" = {
      "editor.formatOnSave" = true;
      "editor.defaultFormatter" = "foxundermoon.shell-format";
    };
    "makefile.makePath" = "${pkgs.gnumake}/bin/make";
  };
}
