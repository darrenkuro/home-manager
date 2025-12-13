{ tag, ... }:
{
  programs.zsh.shellAliases = {

    a = "hx $HM/modules/system/aliases.nix"; # Aliases (shared)
    p =
      if tag == "mac" then "hx $HM/modules/system/macos.nix" else "hx $HM/modules/system/linux-ft.nix";
    hm = "cd $HM";
    dev = "cd $DEV";

    ncg = "nix-collect-garbage -d";

    lss = "eza --icons --ignore-glob='*.log|.git|node_modules|.DS_Store'";
    objdump = "objdump --disassembler-options=intel";

    # Copy
    ijs = "echo '![JavaScript](https://img.shields.io/badge/-JavaScript-f7df1e?style=flat-square&logo=JavaScript&logoColor=black)' | pbcopy";
  };
}
