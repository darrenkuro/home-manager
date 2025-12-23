{
  tag,
  lib,
  ...
}: {
  programs.zsh.shellAliases = lib.mkMerge [
    # ---- common aliases (always enabled)
    {
      objdump = "objdump --disassembler-options=intel";
      ls = "eza --icons --ignore-glob='.DS_Store'";
      cloc = "tokei";

      a = "hx $HM/modules/system/aliases.nix"; # Aliases (shared)

      # Faster navigation
      devg = "cd $DEV"; # dev go
      hmg = "cd $HM"; # hm go


      ncg = "nix-collect-garbage -d";
      clean = "rm -rf $HOME/.npm $HOME/.zcompdump $HOME/.cache $HOME/.lesshst";

      tpll = "git -C $XDG_DATA_HOME/task pull";
      tpsh = "git -C $XDG_DATA_HOME/task add . && git -C $XDG_DATA_HOME/task commit -m 'Auto-sync' && git -C $XDG_DATA_HOME/task push";

      hmpsh = "git -C $HM add . && git -C $HM commit -m 'Auto-push' && git -C $HM push";
      hmpll = "git -C $HM pull";
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
      hm = "code --no-sandbox $HM";
      re = "home-manager switch --flake $HM#ft && exec zsh";

      code = "code --no-sandbox"; # VSCode requires --no-sandbox to run in nix env on 42
    })
  ];

  imports = [./aliases-cp.nix];
}
