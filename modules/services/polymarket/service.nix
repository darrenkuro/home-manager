# Polymarket Data Monitor — LaunchAgent managed in darwin.nix
{ config, lib, pkgs, ... }:

let
  btm = import ../../../lib/launchd-btm.nix { inherit lib pkgs; };

  workDir = "${config.home.homeDirectory}/Documents/dev/polymarket-trading-bot";
  logDir = "/tmp/polymarket";

  wrapper = btm.mkWrapper {
    name = "PolymarketMonitor";
    runtimeInputs = [ pkgs.nodejs_22 pkgs.pnpm ];
    text = ''
      cd "${workDir}"

      # Source environment variables
      if [ -f .env ]; then
        set -a
        # shellcheck disable=SC1091
        source .env
        set +a
      fi

      # Run the monitor
      exec pnpm tsx src/scripts/data-monitor.ts
    '';
  };

in
{
  home.activation.createPolymarketLogDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${logDir}
  '';

  btm.stubs."Polymarket" = {
    src = ./Polymarket.app;
    wrappers = [{ drv = wrapper; bin = "PolymarketMonitor"; }];
  };
}
