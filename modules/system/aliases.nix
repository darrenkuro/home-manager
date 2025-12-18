{ tag, ... }:
{
  programs.zsh.shellAliases = {
    a = "hx $HM/modules/system/aliases.nix"; # Aliases (shared)
    p =
      if tag == "mac" then "hx $HM/modules/system/macos.nix" else "hx $HM/modules/system/linux-ft.nix";
    hm = if tag == "mac" then "code $HM" else "cd $HM";
    dev = "cd $DEV";

    ncg = "nix-collect-garbage -d";

    # lss = "eza --icons --ignore-glob='*.log|.git|node_modules|.DS_Store'";
    ls = "eza";
    objdump = "objdump --disassembler-options=intel";

    clean = "rm -rf $HOME/.npm $HOME/.zcompdump $HOME/.cache $HOME/.lesshst";
    # Copy
    ijs = "echo '![JavaScript](https://img.shields.io/badge/-JavaScript-f7df1e?style=flat-square&logo=JavaScript&logoColor=black)' | pbcopy";
  };
}
