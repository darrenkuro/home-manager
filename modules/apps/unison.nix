# Unison — two-way sync of ~/Documents/42tirana and the Claude session state
# between the MacBook and the work iMac, over Tailscale ssh (`work`, ssh.nix).
# Manual only: `tsync` (functions/tsync.sh) runs the two profiles below; there
# is no agent. Both Macs get the package (the iMac is the ssh server side); the
# profiles are personal-profile only, since their roots name the iMac as the
# peer. Unison's archives (ar*/fp* next to the profiles in ~/.config/unison) are
# per-machine state that hm never touches. A file Unison overwrites or deletes
# is first copied to ~/.local/state/unison/backup on the side that loses it;
# UNISONBACKUPDIR wins over the backupdir preference and is read by the
# ssh-launched server too, so both Macs use the same path.
{ pkgs, lib, profile, homeDir, ... }: let
    common = ''
        links = true
        times = true
        fastcheck = true
        confirmbigdel = true
        log = true
        logfile = ${homeDir}/Library/Logs/unison.log
        sshargs = -o BatchMode=yes -o ConnectTimeout=10
        ignore = Name .DS_Store
    '';
in
{
    home.packages = [ pkgs.unison ];

    home.sessionVariables = {
        UNISON = "$HOME/.config/unison";
        UNISONBACKUPDIR = "$HOME/.local/state/unison/backup";
    };

    xdg.configFile = lib.mkIf ( profile == "personal" ) {
        # The staff folder. Build output, venvs and scratch stay local; the SQLite
        # side files are excluded because tsync checkpoints the WAL first. Backups
        # skip the bulk data (clones, exam pulls, upstream pedago) and .git internals.
        "unison/42tirana.prf".text = ''
            # managed by home-manager (modules/apps/unison.nix)
            root = ${homeDir}/Documents/42tirana
            root = ssh://work/${homeDir}/Documents/42tirana
            ${common}
            ignore = Path tmp
            ignore = Name node_modules
            ignore = Name .venv
            ignore = Name .next
            ignore = Name dist
            ignore = Name __pycache__
            ignore = Name .ruff_cache
            ignore = Name .mypy_cache
            ignore = Name *.sqlite-shm
            ignore = Name *.sqlite-wal
            ignore = Regex (.*/)?\.git/.*\.lock
            backup = Name *
            backupnot = Regex resources/data/(repos|exams)(/.*)?
            backupnot = Regex resources/pedago(/.*)?
            backupnot = Regex (.*/)?\.git(/.*)?
            backupnot = Regex (.*/)?node_modules(/.*)?
            backuplocation = central
            maxbackups = 2
        '';

        # Claude Code state that is worth having on both Macs: transcripts (UUID
        # files, written by one machine each), memory, plans, todos, file history
        # and the paste cache. history.jsonl is appended on both sides and needs a
        # merge program before it can join. No backups: nothing here is edited by
        # hand except memory/MEMORY.md, and a conflict there is resolved in tsync.
        "unison/claude.prf".text = ''
            # managed by home-manager (modules/apps/unison.nix)
            root = ${homeDir}/.config/claude
            root = ssh://work/${homeDir}/.config/claude
            ${common}
            path = projects
            path = plans
            path = todos
            path = file-history
            path = paste-cache
        '';
    };
}
