{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python311
    python311Packages.pip
    python311Packages.virtualenv

    # Common libs
    python311Packages.numpy
    python311Packages.matplotlib
    python311Packages.pandas

    python311Packages.black # formatter
    python311Packages.flake8 # linter
    python311Packages.isort # import sorter
    python311Packages.mypy # type checker
  ];

  programs.helix.languages = {
    language = [
      {
        name = "python";
        auto-format = true;
        formatter = {
          command = "black";
          args = [ "-" ]; # reads from stdin
        };
      }
    ];
  };

  programs.vscode.profiles.default.userSettings = {
    "[python]" = {
      "editor.defaultFormatter" = "ms-python.python";
    };

    # Linting / formatting settings
    "python.formatting.provider" = "black";
    "python.formatting.blackPath" = "${pkgs.python311Packages.black}/bin/black";
    "python.linting.enabled" = true;
    "python.linting.flake8Enabled" = true;
    "python.analysis.typeCheckingMode" = "basic";
    "python.defaultInterpreterPath" = "${pkgs.python311}/bin/python3";
  };
}
