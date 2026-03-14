# Polymarket home-manager module — log directory setup.
# LaunchAgent and BTM stub are managed in darwin.nix.
{lib, ...}: let
  logDir = "/tmp/polymarket";
in {
  home.activation.createPolymarketLogDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ${logDir}
  '';
}
