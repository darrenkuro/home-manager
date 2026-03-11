# Polymarket Data Monitor — BTM-friendly launchd agent for macOS
#
# Uses the BTM module (btm.nix) instead of launchd.agents to avoid
# the /bin/sh wrapper that makes BTM show "sh" as the process name.
#
# Creates:
#   - PolymarketMonitor wrapper → named binary for BTM/ps display
#   - ScriptEditor.app stub    → BTM icon (uses Script_Editor.icns)
#   - Launchd plist via btm.agents (bypassing HM's mutateConfig)
{ config, lib, pkgs, ... }:

let
  btm = import ../../lib/launchd-btm.nix { inherit lib pkgs; };

  workDir = "/Users/darrenlu/Documents/dev/polymarket-trading-bot";
  logDir = "/tmp/polymarket";

  # ── Named Wrapper ──
  monitorWrapper = btm.mkWrapper {
    name = "PolymarketMonitor";
    runtimeInputs = [ pkgs.nodejs pkgs.pnpm ];
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

  # ── App Stub ──
  monitorStub = btm.mkAppStub {
    name = "Polymarket";
    bundleId = "com.local.polymarket-monitor.stub";
    icon = ../../configs/icons/Script_Editor.icns;
  };

  # ── Launchd Plist ──
  monitorPlist = btm.mkPlist {
    Label = "com.polymarket.data-monitor";
    ProgramArguments = [ "${monitorWrapper}/bin/PolymarketMonitor" ];
    WorkingDirectory = workDir;
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 10;
    StandardOutPath = "${logDir}/monitor.log";
    StandardErrorPath = "${logDir}/monitor.err";
    AssociatedBundleIdentifiers = [ "com.local.polymarket-monitor.stub" ];
    EnvironmentVariables = {
      PATH = "${pkgs.nodejs}/bin:${pkgs.pnpm}/bin:/usr/bin:/bin";
      HOME = config.home.homeDirectory;
    };
  };

in
{
  # ── Directory Setup ──
  home.activation.createPolymarketLogDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${logDir}
  '';

  # ── BTM Registration ──
  btm.agents."com.polymarket.data-monitor" = monitorPlist;
  btm.stubs."Polymarket" = monitorStub;
}
