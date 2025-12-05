{ config, pkgs, tag, ... }:
let
  dp = "$HOME/Dropbox";
  dev = "$HOME/Documents/dev";
  hm = "$HOME/.config/home-manager";
  dotfile = "$HOME/.config/home-manager/dotfiles";
in {
  home.sessionVariables = {
    DBOX = dp;
    HM = hm;
    DEV = dev;
    DOTFILE = dotfile;
  };
  
  programs.zsh.shellAliases = {
    ### Shared

    # 
    h = "hx";
    cloc = "tokei";

    # Fast access
    dbox = "cd ${dp}";
    dev = "cd ${dev}";
    a = "hx ${hm}/src-nix/alias.nix";

    # Git
    gi = "gitinit";
    gpa = "git add -A && git commit -m \"Update\" && git push";
    gm = "git commit -m";
    gma = "git add -A && git commit -m";
    gch = "git checkout";
    gs = "git status";
    gp = "git push";
    ga = "git add -A";
    gpl = "git push --force-with-lease";
    gchp = "gh pr checkout";

    sscfg = "hx ${dotfile}/starship.toml";

    ncg = "nix-collect-garbage -d";

    lss = "eza --icons --ignore-glob='*.log|.git|node_modules|.DS_Store'";
    objdump = "objdump --disassembler-options=intel";
  }
  //
  (if tag == "mac" then {
    re = "home-manager switch --flake ~/.config/home-manager#mac";

    hide = "chflags hidden";
    unhide = "chflags nohidden";
    rm = "echo "
      
  } else if tag == "ft" then {
    re = "home-manager switch --flake ~/.config/home-manager#ft";
    
  }
  else {});
}
