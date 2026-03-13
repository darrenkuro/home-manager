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
      clean = builtins.concatStringsSep " && " [
        # Caches (safe, all regenerate)
        "rm -rf $HOME/.cache $HOME/.npm $HOME/.matplotlib"
        # Shell artifacts
        "rm -rf $HOME/.zcompdump $HOME/.lesshst"
        # .NET (not in use, regenerates on dotnet run)
        "rm -rf $HOME/.aspnet $HOME/.dotnet $HOME/.nuget $HOME/.templateengine"
        # Docker (redundant, DOCKER_CONFIG already points to $XDG_CONFIG_HOME/docker)
        "rm -rf $HOME/.docker"
        # macOS junk
        "rm -f $HOME/.DS_Store"
        ''echo "clean: done"''
      ];

      hmpsh = "git -C $HM add . && git -C $HM commit -m 'Auto-push' && git -C $HM push";
      hmpll = "git -C $HM pull";
    }

    # ---- mac-only aliases
    (lib.mkIf (tag == "mac") {
      p = "hx $HM/modules/system/macos.nix";
      hm = "code $HM";
      re = "sudo -v && sudo darwin-rebuild switch --flake $HM#mac && sudo $HM/scripts/btm-patch-nix.sh && exec zsh";

      dbox = "cd $DBOX";
      hide = "chflags hidden";
      unhide = "chflags nohidden";
      rm = "echo \"☠️$YELLOW DANGEROUS CMD: using trash instread!$RESET\" && trash";
      ytd = "yt-dlp -t mp4 --cookies-from-browser brave";
      kotr = "nix-shell -p whisper-cpp --run 'whisper-stream -m $HOME/.local/share/whisper-cpp/ggml-medium.bin -l ko -tr'";
      remoteon = "sudo systemsetup -setremotelogin on";
      remoteoff = "sudo systemsetup -setremotelogin off";
      # brew install tmux --HEAD (next-tmux 3.7) fixes Claude Code rendering issue.
      # Delete this alias and move back to nix-managed tmux once officially released.
      tmux = "/opt/homebrew/bin/tmux";
    })

    # ---- ft-only aliases
    (lib.mkIf (tag == "ft") {
      p = "hx $HM/modules/system/linux-ft.nix";
      hm = "code --no-sandbox $HM";
      re = "home-manager switch --flake $HM#ft && exec zsh";

      code = "code --no-sandbox"; # VSCode requires --no-sandbox to run in nix env on 42
    })
  ];

  imports = [
    ./aliases-cp.nix
    ./aliases-man.nix
     ];
}
