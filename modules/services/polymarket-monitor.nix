# Polymarket Data Monitor — BTM-friendly launchd agent for macOS
#
# Runs the data monitor script in the background with auto-restart.
{ config, lib, pkgs, ... }:

let
  btm = import ../../lib/launchd-btm.nix { inherit lib pkgs; };

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

  plist = btm.mkPlist {
    Label = "com.polymarket.data-monitor";
    BundleProgram = "Contents/MacOS/PolymarketMonitor";
    WorkingDirectory = workDir;
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 10;
    StandardOutPath = "${logDir}/monitor.log";
    StandardErrorPath = "${logDir}/monitor.err";
    EnvironmentVariables = {
      PATH = "${pkgs.nodejs_22}/bin:${pkgs.pnpm}/bin:/usr/bin:/bin";
      HOME = config.home.homeDirectory;
    };
  };

in
{
  home.activation.createPolymarketLogDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${logDir}
  '';

  btm.stubs."Polymarket" = {
    src = ../../app-stubs/Polymarket.app;
    wrappers = [{ drv = wrapper; bin = "PolymarketMonitor"; }];
    agents = { "com.polymarket.data-monitor" = plist; };
  };
}
