# BTM (Background Task Management) module — shared activation for launchd agents.
#
# Service modules register their agents and app stubs via:
#   btm.agents.<label> = plistDerivation;
#   btm.stubs.<Name>   = appStubDerivation;
#
# This module handles:
#   - bootout/bootstrap lifecycle for all registered agents
#   - Installing app stubs to ~/.local/share/app-stubs/
#   - lsregister for BTM icon resolution
#   - Cleanup of removed agents between generations
{ config, lib, pkgs, ... }:

let
  cfg = config.btm;
  homeDir = config.home.homeDirectory;
  dstDir = "${homeDir}/Library/LaunchAgents";
  stubDir = "${homeDir}/.local/share/app-stubs";
in
{
  options.btm = {
    agents = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      default = { };
      description = "Map of launchd label to plist derivation. Managed by the BTM activation script.";
    };

    stubs = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      default = { };
      description = "Map of PascalCase app name to app stub derivation. Installed to ~/.local/share/app-stubs/.";
    };
  };

  config = lib.mkIf (cfg.agents != { }) {
    # Store current labels so the next generation can detect removals
    home.file.".local/share/app-stubs/.btm-labels".text =
      lib.concatStringsSep "\n" (lib.attrNames cfg.agents);

    # Run after writeBoundary + setupLaunchAgents (HM's built-in launchd cleanup)
    # and after service init steps so dirs/data exist before bootstrap.
    # Missing DAG names are silently ignored (safe if a service isn't imported).
    home.activation.btmLaunchAgents = lib.hm.dag.entryAfter [
      "writeBoundary"
      "setupLaunchAgents"
      "postgresqlInit"
      "createPolymarketLogDir"
    ] ''
      set +e

      _btm_bootout() {
        local label="$1"
        local out
        out=$(/bin/launchctl bootout "gui/$UID/$label" 2>&1) || {
          if [[ "$out" != *"No such process"* && "$out" != *"Could not find"* ]]; then
            echo "  btm warn: bootout $label: $out" >&2
          fi
        }
        sleep 1
      }

      _btm_bootstrap() {
        local src="$1" dst="$2" label="$3"
        install -Dm444 "$src" "$dst"
        local out
        out=$(/bin/launchctl bootstrap "gui/$UID" "$dst" 2>&1) || {
          echo "  btm error: bootstrap $label: $out" >&2
          return 1
        }
      }

      echo "BTM: syncing launch agents..."
      mkdir -p "${dstDir}"

      # ── Install / update agents ──
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (label: plistDrv: ''
        _dst="${dstDir}/${label}.plist"
        if ! cmp -s "${plistDrv}" "$_dst" 2>/dev/null; then
          echo "  updating: ${label}"
          _btm_bootout "${label}"
          _btm_bootstrap "${plistDrv}" "$_dst" "${label}"
        fi
      '') cfg.agents)}

      # ── Clean up removed agents ──
      _prev_labels="${stubDir}/.btm-labels"
      if [ -f "$_prev_labels" ]; then
        while IFS= read -r label; do
          [ -z "$label" ] && continue
          case "$label" in
            ${lib.concatStringsSep "|" (lib.attrNames cfg.agents)}) ;;  # still active
            *)
              echo "  removing: $label"
              _btm_bootout "$label"
              rm -f "${dstDir}/$label.plist"
              ;;
          esac
        done < "$_prev_labels"
      fi

      # ── Install app stubs + lsregister ──
      ${lib.optionalString (cfg.stubs != { }) ''
        mkdir -p "${stubDir}"

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: stubDrv: ''
          _stub_dst="${stubDir}/${name}.app"
          _stub_src="${stubDrv}/${name}.app"
          if [ ! -d "$_stub_dst" ] || ! diff -rq "$_stub_src" "$_stub_dst" &>/dev/null; then
            echo "  installing stub: ${name}.app"
            rm -rf "$_stub_dst"
            cp -R "$_stub_src" "$_stub_dst"
          fi
        '') cfg.stubs)}

        _lsregister="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
        if [ -x "$_lsregister" ]; then
          for app in "${stubDir}"/*.app; do
            [ -d "$app" ] && "$_lsregister" -f "$app" 2>/dev/null
          done
          echo "  registered stubs with LaunchServices"
        fi
      ''}

      echo "BTM: done"
      set -e
    '';
  };
}
