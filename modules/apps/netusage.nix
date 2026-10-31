# netusage — per-process network usage TUI (live + cumulative panels)
#
# Source lives in ./netusage (moved in from the github:darrenkuro/netusage
# flake input, 2026-10-31); this wraps `netusage.py` in a tiny shell
# launcher so `netusage` ends up on $PATH. Hack without a rebuild:
#   python3 $HM/modules/apps/netusage/netusage.py
#
# macOS-only — depends on Apple's `nettop`. Imported conditionally
# from home.nix on `tag == "mac"`.
{ pkgs, ... }: {
    home.packages = [
        ( pkgs.writeShellScriptBin "netusage" ''
      exec ${pkgs.python3}/bin/python3 ${./netusage}/netusage.py "$@"
    '' )
    ];
}
