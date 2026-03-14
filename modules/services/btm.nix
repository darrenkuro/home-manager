# BTM (Background Task Management) module — app stubs for icon grouping.
#
# Service modules register: btm.stubs.<Name> = { src, wrappers }
# Activation: copies stubs, embeds wrappers, codesigns, opens to register.
# LaunchAgents managed in darwin.nix; BTM patching adds AssociatedBundleIdentifiers.
{ config, lib, ... }:

let
  cfg = config.btm;

  stubType = lib.types.submodule {
    options = {
      src = lib.mkOption {
        type = lib.types.path;
        description = "Path to .app bundle in repo.";
      };
      wrappers = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            drv = lib.mkOption { type = lib.types.package; };
            bin = lib.mkOption { type = lib.types.str; };
          };
        });
        default = [];
      };
    };
  };
in
{
  options.btm = {
    stubs = lib.mkOption {
      type = lib.types.attrsOf stubType;
      default = { };
    };

    stubDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/share/app-stubs";
      readOnly = true;
    };
  };

  config = lib.mkIf (cfg.stubs != { }) {
    home.activation.btmStubs = lib.hm.dag.entryAfter [
      "writeBoundary"
      "postgresqlInit"
      "createPolymarketLogDir"
    ] ''
      set +e
      echo "BTM: syncing stubs..."
      mkdir -p "${cfg.stubDir}"

      ${lib.concatStringsSep "\n\n" (lib.mapAttrsToList (name: stubCfg: let
        manifestLines = [ "src=${stubCfg.src}" ]
          ++ map (w: "wrapper=${w.bin}:${w.drv}") stubCfg.wrappers;
        expectedManifest = lib.concatStringsSep "\\n" manifestLines;
      in ''
        _stub_dst="${cfg.stubDir}/${name}.app"
        _manifest="${cfg.stubDir}/.stub-manifest-${name}"
        _expected="$(printf '${expectedManifest}\n')"

        if [ -f "$_manifest" ] && [ "$(cat "$_manifest")" = "$_expected" ] && [ -d "$_stub_dst" ]; then
          echo "  stub unchanged: ${name}.app"
        else
          echo "  installing stub: ${name}.app"
          [ -d "$_stub_dst" ] && chmod -R u+w "$_stub_dst"
          rm -rf "$_stub_dst"
          cp -R "${stubCfg.src}" "$_stub_dst"
          chmod -R u+w "$_stub_dst"
          mkdir -p "$_stub_dst/Contents/MacOS"

          ${lib.concatMapStringsSep "\n" (w: ''
            cp "${w.drv}/bin/${w.bin}" "$_stub_dst/Contents/MacOS/${w.bin}"
            chmod u+wx "$_stub_dst/Contents/MacOS/${w.bin}"
          '') stubCfg.wrappers}

          printf '#!/bin/sh\nexit 0\n' > "$_stub_dst/Contents/MacOS/Stub"
          chmod u+x "$_stub_dst/Contents/MacOS/Stub"

          /usr/bin/codesign --force --deep \
            -s "Apple Development: odon5ht@gmail.com (497TM5HK44)" \
            "$_stub_dst" && \
            echo "  codesigned: ${name}.app" || \
            echo "  btm error: codesign failed for ${name}.app" >&2

          /usr/bin/open "$_stub_dst" 2>/dev/null
          sleep 1
          printf '%s\n' "$_expected" > "$_manifest"
        fi
      '') cfg.stubs)}

      echo "BTM: done"
      set -e
    '';
  };
}
