# Polymarket Data Monitor - launchd agent for macOS
# Runs the data monitor script in the background with auto-restart
{ config, lib, pkgs, ... }:

let
  workDir = "/Users/darrenlu/Documents/dev/polymarket-trading-bot";
  logDir = "/tmp/polymarket";

  # Wrapper script that sources .env and runs the monitor
  runScript = pkgs.writeShellScript "polymarket-monitor" ''
    cd ${workDir}

    # Source environment variables
    if [ -f .env ]; then
      set -a
      source .env
      set +a
    fi

    # Run the monitor
    exec ${pkgs.pnpm}/bin/pnpm tsx src/scripts/data-monitor.ts
  '';
in
{
  # Create log directory
  home.activation.createPolymarketLogDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ${logDir}
  '';

  launchd.agents.polymarket-monitor = {
    enable = true;
    config = {
      Label = "com.polymarket.data-monitor";
      ProgramArguments = [ "${runScript}" ];
      WorkingDirectory = workDir;
      RunAtLoad = true;
      KeepAlive = {
        SuccessfulExit = false;  # Restart if exits with non-zero
        Crashed = true;          # Restart if crashes
      };
      StandardOutPath = "${logDir}/monitor.log";
      StandardErrorPath = "${logDir}/monitor.err";
      ThrottleInterval = 10;  # Wait 10s between restarts
      EnvironmentVariables = {
        PATH = "/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin:${pkgs.nodejs}/bin:${pkgs.pnpm}/bin";
        HOME = "/Users/darrenlu";
      };
    };
  };
}
