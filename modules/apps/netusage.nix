# netusage — per-process network usage TUI (live + cumulative panels)
#
# Source is pulled as a `flake = false` input from
# github:darrenkuro/netusage; this wraps its `netusage.py` in a tiny
# shell launcher so `netusage` ends up on $PATH.
#
# macOS-only — depends on Apple's `nettop`. Imported conditionally
# from home.nix on `tag == "mac"`.
{
  pkgs,
  netusage,
  ...
}: {
  home.packages = [
    (pkgs.writeShellScriptBin "netusage" ''
      exec ${pkgs.python3}/bin/python3 ${netusage}/netusage.py "$@"
    '')
  ];
}
