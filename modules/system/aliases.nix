{ tag, ... }: {
  programs.zsh.shellAliases = {
    h = "hx";
    cloc = "tokei";

    #a = "hx $HM/${paths.sys}/alias.nix"; # Aliases (shared)
    #p = if tag == "mac" then "hx $HM/${paths.sys}/macos.nix" else "hx $HM/${paths.sys}/linux-ft.nix";
    hm = "cd $HM";
    dev = "cd $DEV";

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

    # sscfg = "hx ${dotfile}/starship.toml";
    # hcfg = "hx ${dotfile}/helix-conf.toml";

    ncg = "nix-collect-garbage -d";

    lss = "eza --icons --ignore-glob='*.log|.git|node_modules|.DS_Store'";
    objdump = "objdump --disassembler-options=intel";
  };
}
