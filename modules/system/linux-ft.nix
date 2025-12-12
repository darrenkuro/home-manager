{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Only add as needed!
    # rustc
    # nodejs_latest
    # typescript
    # nodePackages.typescript-language-server

    # python311
    # python311Packages.pip
    # python311Packages.virtualenv
  ];

  # Set faster keyboard repeat rate (only on X11)
  programs.zsh.initContent = ''
    if command -v xset >/dev/null 2>&1 && [ -n "$DISPLAY" ]; then
      xset r rate 200 60 2>/dev/null || true
    fi
  '';

  programs.zsh.shellAliases = {
    re = "home-manager switch --flake ~/.config/home-manager#ft";
  };
}
