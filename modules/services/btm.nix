# BTM (Background Task Management) module — shared activation for launchd agents.
#
# ── How it works ──
# Service modules register their agents and app stubs via options:
#   btm.agents.<label> = plistDerivation;   (from mkPlist)
#   btm.stubs.<Name>   = { src, wrappers }  (static .app from configs/app-stubs/)
#
# This module's activation script then:
#   1. Copies app stubs from the repo, embeds wrapper binaries into Contents/MacOS/
#   2. Codesigns each stub with Apple Development identity (real Team ID for BTM)
#   3. Registers stubs with LaunchServices for bundle ID → icon resolution
#   4. Installs/updates plists whose ProgramArguments point inside the stub
#   5. Removes agents from previous generations that are no longer registered
#
# ── Why wrapper binaries go inside the .app ──
# BTM resolves icons via path containment: if ProgramArguments points to a binary
# inside a .app bundle, BTM uses that bundle's icon. Stubs are signed with the
# user's Apple Development identity (not ad-hoc) so BTM gets a real Team ID.
#
# ── Icon refresh ──
# After first setup or icon changes, a reboot (or logout/login) is needed for
# BTM to pick up the new icons. Do NOT use `sfltool resetbtm` — that wipes ALL
# login items and background items system-wide.
#
# ── Why not use HM's launchd.agents? ──
# HM wraps ProgramArguments in `/bin/sh -c "wait4path..."`, so BTM shows "sh"
# for every agent. Our mkWrapper bakes in wait4path directly, and mkPlist
# bypasses HM's mutateConfig entirely. See lib/launchd-btm.nix for details.
{ config, lib, pkgs, ... }:

let
  cfg = config.btm;
  homeDir = config.home.homeDirectory;
  dstDir = "${homeDir}/Library/LaunchAgents";

  stubType = lib.types.submodule {
    options = {
      src = lib.mkOption {
        type = lib.types.path;
        description = "Path to the .app bundle in the repo (e.g. ../../configs/app-stubs/Claude.app).";
      };
      wrappers = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            drv = lib.mkOption { type = lib.types.package; description = "mkWrapper derivation."; };
            bin = lib.mkOption { type = lib.types.str; description = "Binary name inside the wrapper's bin/."; };
          };
        });
        default = [];
        description = "Wrapper binaries to embed in Contents/MacOS/ for path-based BTM icon resolution.";
      };
    };
  };
in
{
  options.btm = {
    agents = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      default = { };
      description = "Map of launchd label to plist derivation.";
    };

    stubs = lib.mkOption {
      type = lib.types.attrsOf stubType;
      default = { };
      description = "Map of PascalCase app name to { src, wrappers }.";
    };

    stubDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/share/app-stubs";
      readOnly = true;
      description = "Directory where app stubs are installed. Used by service modules to build ProgramArguments paths.";
    };
  };

  config = lib.mkIf (cfg.agents != { }) {

    # Write current agent labels to disk so the next generation can diff
    # and clean up any agents that were removed.
    home.file.".local/share/app-stubs/.btm-labels".text =
      lib.concatStringsSep "\n" (lib.attrNames cfg.agents);

    # DAG ordering: run after HM's built-in launchd cleanup (setupLaunchAgents)
    # and after service-specific init (postgresqlInit creates data dir,
    # createPolymarketLogDir creates log dir) so everything is ready before
    # we bootstrap agents that depend on those paths.
    home.activation.btmLaunchAgents = lib.hm.dag.entryAfter [
      "writeBoundary"
      "setupLaunchAgents"
      "postgresqlInit"
      "createPolymarketLogDir"
    ] ''
      set +e

      # ── Helper: stop an agent (safe if already stopped) ──
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

      # ── Helper: install plist and start an agent ──
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

      # ── App stubs: install BEFORE bootstrapping agents ──
      # ProgramArguments points to executables inside the .app bundles, so stubs
      # must exist before launchd tries to start the agents.
      ${lib.optionalString (cfg.stubs != { }) ''
        mkdir -p "${cfg.stubDir}"

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: stubCfg: ''
          _stub_dst="${cfg.stubDir}/${name}.app"
          _stub_src="${stubCfg.src}"

          # Always reinstall (cheap, ensures wrappers are current)
          echo "  installing stub: ${name}.app"
          [ -d "$_stub_dst" ] && chmod -R u+w "$_stub_dst"
          rm -rf "$_stub_dst"
          cp -R "$_stub_src" "$_stub_dst"
          chmod -R u+w "$_stub_dst"

          # Embed wrapper binaries into Contents/MacOS/
          ${lib.concatMapStringsSep "\n" (w: ''
            cp "${w.drv}/bin/${w.bin}" "$_stub_dst/Contents/MacOS/${w.bin}"
            chmod u+wx "$_stub_dst/Contents/MacOS/${w.bin}"
          '') stubCfg.wrappers}

          # Codesign with real Apple Development identity (not ad-hoc)
          /usr/bin/codesign --force --deep -s "Apple Development: odon5ht@gmail.com (497TM5HK44)" "$_stub_dst" && \
            echo "  codesigned: ${name}.app" || \
            echo "  btm error: codesign failed for ${name}.app" >&2
        '') cfg.stubs)}

        _lsregister="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
        if [ -x "$_lsregister" ]; then
          for app in "${cfg.stubDir}"/*.app; do
            [ -d "$app" ] && "$_lsregister" -f "$app" 2>/dev/null
          done
          echo "  registered stubs with LaunchServices"
        fi
      ''}

      # ── Install / update: only touch agents whose plist actually changed ──
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (label: plistDrv: ''
        _dst="${dstDir}/${label}.plist"
        if ! cmp -s "${plistDrv}" "$_dst" 2>/dev/null; then
          echo "  updating: ${label}"
          _btm_bootout "${label}"
          _btm_bootstrap "${plistDrv}" "$_dst" "${label}"
        fi
      '') cfg.agents)}

      # ── Cleanup: remove agents from previous generation that are no longer registered ──
      _prev_labels="${cfg.stubDir}/.btm-labels"
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

      echo "BTM: done"
      set -e
    '';
  };
}
