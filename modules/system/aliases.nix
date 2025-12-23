{ tag, lib, ... }:
{
    programs.zsh.shellAliases = lib.mkMerge [
    # ---- common aliases (always enabled)
    {
      ls = "eza --icons --ignore-glob='.DS_Store'";
      cloc = "tokei";

      a = "hx $HM/modules/system/aliases.nix"; # Aliases (shared)

      dev = "cd $DEV";

      ncg = "nix-collect-garbage -d";
      objdump = "objdump --disassembler-options=intel";
      clean = "rm -rf $HOME/.npm $HOME/.zcompdump $HOME/.cache $HOME/.lesshst";

      tpll= "git -C $XDG_DATA_HOME/task pull";
      tpsh = "git -C $XDG_DATA_HOME/task add . && git -C $XDG_DATA_HOME/task commit -m 'Auto-sync' && git -C $XDG_DATA_HOME/task push";
    }

    # ---- mac-only aliases
    (lib.mkIf (tag == "mac") {
      p = "hx $HM/modules/system/macos.nix";
      hm = "code $HM";
      re = "home-manager switch --flake $HM#mac && exec zsh";

      dbox = "cd $DBOX";
      hide = "chflags hidden";
      unhide = "chflags nohidden";
      rm = "echo \"☠️$YELLOW DANGEROUS CMD: using trash instread!$RESET\" && trash";
    })

    # ---- ft-only aliases
    (lib.mkIf (tag == "ft") {
      p = "hx $HM/modules/system/linux-ft.nix";
      hm = "cd $HM";
      re = "home-manager switch --flake $HM#ft && exec zsh";
    })
  ];

  imports = [ ./aliases-cp.nix ];
}
