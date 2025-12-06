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
    a = "hx ${hm}/src-nix/alias.nix"; # Aliases
    p = "hx ${hm}/src-nix/entry.nix"; # Packages
    hm = "cd ${hm}";
    dev = "cd ${dev}";
    
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
    hcfg = "hx ${dotfile}/helix-conf.toml";

    ncg = "nix-collect-garbage -d";

    lss = "eza --icons --ignore-glob='*.log|.git|node_modules|.DS_Store'";
    objdump = "objdump --disassembler-options=intel";
  }
  //
  (if tag == "mac" then {
    dbox = "cd ${dp}";
    
    re = "home-manager switch --flake ~/.config/home-manager#mac";

    hide = "chflags hidden";
    unhide = "chflags nohidden";
    #rm = "echo \"$YELLOW DANGEROUS CMD: using trash instread!$RESET" && trash";
      
  } else if tag == "ft" then {
    re = "home-manager switch --flake ~/.config/home-manager#ft";
    
  }
  else {});
}
