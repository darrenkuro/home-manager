# BTM (Background Task Management) module — app stubs + grouped agent registration.
#
# ── How it works ──
# Service modules register stubs with optional agents:
#   btm.stubs.<Name> = { src, wrappers, agents }
#
# This module's activation script:
#   1. Copies app stubs from repo, embeds wrappers into Contents/MacOS/
#   2. Codesigns each stub with Apple Development identity
#   3. Opens each stub to register it as a BTM parent (enables grouping)
#   4. Installs agent plists via launchctl with AssociatedBundleIdentifiers
#      pointing to the stub's bundle ID → agents appear grouped under the stub
#
# For stubs without agents (e.g. Nix), only BTM parent registration is done.
#
# ── Grouping ──
# `open Foo.app` registers the stub as a type 0x2 parent entry in BTM.
# Agent plists include AssociatedBundleIdentifiers referencing the stub's
# CFBundleIdentifier. BTM then shows "Postgres — 2 items" in Login Items.
#
# ── Icon refresh ──
# After first setup or icon changes, a reboot (or logout/login) is needed for
# BTM to pick up the new icons. Do NOT use `sfltool resetbtm`.
{ config, lib, pkgs, ... }:

let
  cfg = config.btm;
  homeDir = config.home.homeDirectory;
  agentDir = "${homeDir}/Library/LaunchAgents";

  # Collect all agent labels across all stubs (for stale agent cleanup)
  allAgentLabels = lib.concatLists (lib.mapAttrsToList
    (_: stubCfg: lib.attrNames stubCfg.agents)
    cfg.stubs);

  stubType = lib.types.submodule {
    options = {
      src = lib.mkOption {
        type = lib.types.path;
        description = "Path to the .app bundle in the repo.";
      };
      wrappers = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            drv = lib.mkOption { type = lib.types.package; description = "mkWrapper derivation."; };
            bin = lib.mkOption { type = lib.types.str; description = "Binary name inside the wrapper's bin/."; };
          };
        });
        default = [];
        description = "Wrapper binaries to embed in Contents/MacOS/.";
      };
      agents = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        default = { };
        description = "Map of launchd label to plist derivation (from mkPlist with BundleProgram).";
      };
    };
  };
in
{
  options.btm = {
    stubs = lib.mkOption {
      type = lib.types.attrsOf stubType;
      default = { };
      description = "Map of PascalCase app name to { src, wrappers, agents }.";
    };

    stubDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/share/app-stubs";
      readOnly = true;
      description = "Directory where app stubs are installed.";
    };
  };

  config = lib.mkIf (cfg.stubs != { }) {

    # DAG ordering: run after HM's built-in launchd cleanup and after
    # service-specific init steps so everything is ready before we register agents.
    home.activation.btmLaunchAgents = lib.hm.dag.entryAfter [
      "writeBoundary"
      "setupLaunchAgents"
      "postgresqlInit"
      "createPolymarketLogDir"
    ] ''
      set +e

      echo "BTM: syncing stubs and agents..."
      mkdir -p "${cfg.stubDir}"

      # ── Install stubs ──
      ${lib.concatStringsSep "\n\n" (lib.mapAttrsToList (name: stubCfg: ''
        # ── ${name} ──
        _stub_dst="${cfg.stubDir}/${name}.app"
        _stub_src="${stubCfg.src}"

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

        # No-op Stub binary — `open` launches it to register the app in BTM
        printf '#!/bin/sh\nexit 0\n' > "$_stub_dst/Contents/MacOS/Stub"
        chmod u+x "$_stub_dst/Contents/MacOS/Stub"

        # Codesign with real Apple Development identity
        /usr/bin/codesign --force --deep \
          -s "Apple Development: odon5ht@gmail.com (497TM5HK44)" \
          "$_stub_dst" && \
          echo "  codesigned: ${name}.app" || \
          echo "  btm error: codesign failed for ${name}.app" >&2
      '') cfg.stubs)}

      # ── Open stubs to register as BTM parent apps ──
      for app in "${cfg.stubDir}"/*.app; do
        [ -d "$app" ] && /usr/bin/open "$app" 2>/dev/null
      done
      sleep 1

      # ── Install / update agents via launchctl ──
      # Converts BundleProgram → ProgramArguments and adds AssociatedBundleIdentifiers
      # for grouping under the parent stub.
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: stubCfg:
        lib.concatStringsSep "\n" (lib.mapAttrsToList (label: plistDrv: ''
          _dst="${agentDir}/${label}.plist"
          _stub_path="${cfg.stubDir}/${name}.app"
          _need_install=0

          if ! /bin/launchctl print "gui/$UID/${label}" &>/dev/null; then
            _need_install=1
          elif ! cmp -s "${plistDrv}" "${cfg.stubDir}/.plist-src-${label}" 2>/dev/null; then
            # Plist source changed (e.g. Nix store paths updated) — reinstall
            _need_install=1
            /bin/launchctl bootout "gui/$UID/${label}" 2>/dev/null
            sleep 1
          fi

          if [ "$_need_install" -eq 1 ]; then
            echo "  installing: ${label}"

            # Convert BundleProgram → ProgramArguments for launchctl
            _bp=$(/usr/libexec/PlistBuddy -c "Print :BundleProgram" "${plistDrv}" 2>/dev/null)
            if [ -n "$_bp" ]; then
              cp "${plistDrv}" "$_dst"
              chmod u+w "$_dst"
              /usr/libexec/PlistBuddy \
                -c "Delete :BundleProgram" \
                -c "Add :ProgramArguments array" \
                -c "Add :ProgramArguments:0 string $_stub_path/$_bp" \
                "$_dst" 2>/dev/null
              _bid=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$_stub_path/Contents/Info.plist" 2>/dev/null)
              if [ -n "$_bid" ]; then
                /usr/libexec/PlistBuddy \
                  -c "Add :AssociatedBundleIdentifiers array" \
                  -c "Add :AssociatedBundleIdentifiers:0 string $_bid" \
                  "$_dst" 2>/dev/null
              fi
            else
              install -Dm444 "${plistDrv}" "$_dst"
            fi

            /bin/launchctl bootstrap "gui/$UID" "$_dst" 2>&1 || \
              echo "  btm error: bootstrap ${label} failed" >&2

            # Cache plist source for change detection
            cp "${plistDrv}" "${cfg.stubDir}/.plist-src-${label}"
          fi
        '') stubCfg.agents)
      ) cfg.stubs)}

      # ── Cleanup stale agents (removed from config but still loaded) ──
      for _cached in "${cfg.stubDir}"/.plist-src-*; do
        [ -f "$_cached" ] || continue
        _label=$(basename "$_cached" | /usr/bin/sed 's/^\.plist-src-//')

        # Skip if label matches a current agent
        _found=0
        for _current in ${lib.concatStringsSep " " allAgentLabels}; do
          if [ "$_label" = "$_current" ]; then
            _found=1
            break
          fi
        done

        if [ "$_found" -eq 0 ]; then
          echo "  removing stale agent: $_label"
          /bin/launchctl bootout "gui/$UID/$_label" 2>/dev/null
          rm -f "${agentDir}/$_label.plist"
          rm -f "$_cached"
        fi
      done

      echo "BTM: done"
      set -e
    '';
  };
}
