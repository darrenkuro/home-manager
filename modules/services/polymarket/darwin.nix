# Polymarket data-monitor — system half: launchd agent + BTM stub.
# Runs the trading bot's data collector from its dev checkout.
#
# Currently DISABLED — its import in the root darwin.nix is commented out.
# To enable: uncomment that import, then `sure`.
{ lib, pkgs, ... }: let
    homeDir = "/Users/darrenlu";
    btm = import ../../../lib/launchd-btm.nix { inherit lib pkgs; };
    workDir = "${homeDir}/Documents/dev/polymarket-trading-bot";

    polymarketWrapper = btm.mkWrapper {
        name = "PolymarketMonitor";
        runtimeInputs = [ pkgs.nodejs_22 pkgs.pnpm ];
        text = ''
      cd "${workDir}"
      if [ -f .env ]; then
        set -a
        # shellcheck disable=SC1091
        source .env
        set +a
      fi
      exec pnpm tsx src/scripts/data-monitor.ts
    '';
    };
in
{
    launchd.user.agents.polymarket-monitor = {
        serviceConfig = {
            Label = "com.polymarket.data-monitor";
            ProgramArguments = [ "${btm.stubDir}/Polymarket.app/Contents/MacOS/PolymarketMonitor" ];
            WorkingDirectory = workDir;
            RunAtLoad = true;
            KeepAlive = true;
            ThrottleInterval = 10;
            StandardOutPath = "/tmp/polymarket/monitor.log";
            StandardErrorPath = "/tmp/polymarket/monitor.err";
            EnvironmentVariables = { HOME = homeDir; };
        };
    };

    system.activationScripts.postActivation.text = ''
        # Polymarket: log dir for the agent's stdout/stderr
        mkdir -p /tmp/polymarket

        ${btm.mkStubInstall {
        name = "Polymarket";
        app = ./Polymarket.app;
        wrappers = [ { drv = polymarketWrapper; bin = "PolymarketMonitor"; } ];
        agents = [ "com.polymarket.data-monitor" ];
    }}
    '';
}
