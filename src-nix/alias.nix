{ config, pkgs, tag, ... }: {
  programs.zsh.shellAliases = {
    # Shared
    h = "hx";

    gpa = "git add -A && git commit -m \"Update\" && git push";
    gm = "git commit -m";
    gma = "git add -A && git commit -m";
    gch = "git checkout";
    gs = "git status";
    gp = "git push";
    ga = "git add -A";
    gpl = "git push --force-with-lease";
    gchp = "gh pr checkout";

    sscfg = "hx ~/.config/home-manager/starship.toml";
    

    ncg = "nix-collect-garbage -d";
  }
  //
  (if tag == "mac" then {
    re = "home-manager switch --flake ~/.config/home-manager#mac";

    hide = "chflags hidden";
    unhide = "chflags nohidden";
      
  } else if tag == "ft" then {
    re = "home-manager switch --flake ~/.config/home-manager#ft";
    
  }
  else {});
}
