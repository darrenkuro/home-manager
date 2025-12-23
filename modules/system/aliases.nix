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
    }

    # ---- mac-only aliases
    (lib.mkIf (tag == "mac") {
      p = "hx $HM/modules/system/macos.nix";
      hm = "code $HM";
      re = "home-manager switch --flake ~/.config/home-manager#mac && exec zsh";

      dbox = "cd $DBOX";
      hide = "chflags hidden";
      unhide = "chflags nohidden";
      rm = "echo \"☠️$YELLOW DANGEROUS CMD: using trash instread!$RESET\" && trash";
    })

    # ---- ft-only aliases
    (lib.mkIf (tag == "ft") {
      p = "hx $HM/modules/system/linux-ft.nix";
      hm = "cd $HM";
      re = "home-manager switch --flake ~/.config/home-manager#ft && exec zsh";
    })
  ];

  imports = [ ./aliases-cp.nix ];
}
