{ tag, lib, ... }: {
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

            # DSA practice drill (open template in editor, run tests, diff vs canonical)
            practice = "$DEV/dsa-collection/practice/practice";

            ncg = "nix-collect-garbage -d";
            # `clean` moved to functions/clean.sh

            hmpsh = "git -C $HM add . && git -C $HM commit -m 'Auto-push' && git -C $HM push";
            hmpll = "git -C $HM pull";
        }

        # ---- mac-only aliases
        (
            lib.mkIf ( tag == "mac" ) {
                p = "hx $HM/darwin.nix";
                hm = "code $HM";
                re = "nix run home-manager -- switch --flake $HM#mac && exec zsh"; # HM only (no brew, system.defaults, launchd)
                sure = "sudo darwin-rebuild switch --flake $HM#mac && sudo $HM/scripts/btm-patch-nix.sh && exec zsh"; # full system + BTM

                dbox = "cd $DBOX";
                hide = "chflags hidden";
                unhide = "chflags nohidden";
                # `sync-local`/`sync-cloud` (iCloud) moved to functions/icloud-sync.sh
                rm = "echo \"☠️$YELLOW DANGEROUS CMD: using trash instread!$RESET\" && trash";
                ytd = "yt-dlp -t mp4 --cookies-from-browser brave";
                # `mdserve` is installed as a real binary via modules/apps/mdserve.nix
                # `netusage` is installed as a real binary via modules/apps/netusage.nix
                nu = "netusage"; # short form
                kotr = "nix-shell -p whisper-cpp --run 'whisper-stream -m $HOME/.local/share/whisper-cpp/ggml-large-v3-turbo.bin -l ko -tr'";
                remoteon = "sudo systemsetup -setremotelogin on";
                remoteoff = "sudo systemsetup -setremotelogin off";
                # brew tmux (stable 3.7) fixes the Claude Code rendering issue.
                # Keep this alias until pinned nixpkgs ships tmux >=3.7, then drop it and the brew entry for nix-managed tmux.
                tmux = "/opt/homebrew/bin/tmux";
            } )

        # ---- ft-only aliases
        (
            lib.mkIf ( tag == "ft" ) {
                p = "hx $HM/modules/system/linux-ft.nix"; # ft platform file (placeholder)
                hm = "code --no-sandbox $HM";
                re = "home-manager switch --flake $HM#ft && exec zsh";

                code = "code --no-sandbox"; # VSCode requires --no-sandbox to run in nix env on 42
            } )
    ];

    imports = [ ./aliases-cp.nix ./aliases-man.nix ];
}
