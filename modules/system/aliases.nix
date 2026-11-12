{ tag, profile, machine, lib, ... }: let
    # Before a rebuild: pull --rebase, bump my own flake inputs (claude-config,
    # bocal) to their pushed HEAD, commit flake.lock, push — scripts/bump-own.sh.
    # Keeps the two Macs' lock commits in one line instead of racing. Fail-soft
    # except Ctrl-C (130). Ends in `&& `: the rebuild runs only if this passed.
    bumpOwn = "$HM/scripts/bump-own.sh && ";
in
{
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
                re = "ssh-add --apple-load-keychain -q 2>/dev/null; " + bumpOwn +
                "nix run home-manager -- switch --flake $HM#${machine} && exec zsh"; # HM only (no brew, system.defaults, launchd)
                # full system rebuild; the BTM patch step is personal-only (the
                # work profile runs stock nix-darwin daemons, no stubs to patch).
                # Root borrows the user's ssh agent (SSH_AUTH_SOCK) so it can
                # fetch the private claude-config input after a bump — root has
                # no GitHub key of its own (README: work Mac bootstrap). The
                # agent empties on every login, so reload keychain-stored keys
                # first (no-op when none are stored; `ssh-add --apple-use-keychain
                # ~/.ssh/<key>` once to store).
                sure = "ssh-add --apple-load-keychain -q 2>/dev/null; " + bumpOwn +
                "sudo env SSH_AUTH_SOCK=\"$SSH_AUTH_SOCK\" darwin-rebuild switch --flake $HM#${machine}" +
                lib.optionalString ( profile == "personal" )
                " && sudo $HM/scripts/btm-patch-nix.sh" + " && exec zsh";

                dbox = "cd $DBOX";
                hide = "chflags hidden";
                unhide = "chflags nohidden";
                # `sync-local`/`sync-cloud` (iCloud) moved to functions/icloud-sync.sh
                rm = "echo \"☠️$YELLOW DANGEROUS CMD: using trash instread!$RESET\" && trash";
                # Personal expense ledger: serve the dashboard live with in-browser editing
                spending = "python3 $DEV/finance/serve.py";
                # Campus Slack bot (42admin skill, from bocal): `slack lookup <login>`,
                # `slack send --to <login> --text - < msg.txt [--dry-run]`
                slack = "$HOME/.config/claude/skills/42admin/scripts/slack";
                # `mdserve` is installed as a real binary via modules/apps/mdserve.nix
                # `netusage` is installed as a real binary via modules/apps/netusage.nix
                nu = "netusage"; # short form
                # `awake` moved to functions/awake.sh (backgrounds caffeinate, toggles)
                remoteon = "sudo systemsetup -setremotelogin on";
                remoteoff = "sudo systemsetup -setremotelogin off";
                ytd = "yt-dlp -t mp4 --cookies-from-browser brave";
                kotr = "nix-shell -p whisper-cpp --run 'whisper-stream -m $HOME/.local/share/whisper-cpp/ggml-large-v3-turbo.bin -l ko -tr'";
            } )

        # ---- linux-only aliases (ft + hetzner)
        (
            lib.mkIf ( tag == "linux" ) {
                re = "home-manager switch --flake $HM#${machine} && exec zsh";
            } )

        # ---- ft-only quirks (42 school box)
        (
            lib.mkIf ( machine == "ft" ) {
                p = "hx $HM/modules/system/linux-ft.nix"; # ft platform file (placeholder)
                hm = "code --no-sandbox $HM";

                code = "code --no-sandbox"; # VSCode requires --no-sandbox to run in nix env on 42
            } )
    ];

    imports = [ ./aliases-cp.nix ];
}
