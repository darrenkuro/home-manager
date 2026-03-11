# lib/launchd-btm.nix — Pure helper functions for BTM-friendly launchd agents.
#
# Usage in service modules:
#   let btm = import ../lib/launchd-btm.nix { inherit lib pkgs; };
#
# Provides:
#   btm.mkAppStub   { name, icon, bundleId }  → derivation with <name>.app/
#   btm.mkWrapper    { name, text, ... }       → writeShellApplication drv
#   btm.mkPlist      attrset                   → plist file derivation
{ lib, pkgs }:

let
  inherit (lib.generators) toPlist;
in
{
  # ── mkAppStub ──────────────────────────────────────────────────────────
  # Builds a minimal .app bundle in the Nix store.
  # The activation script copies it to ~/.local/share/app-stubs/<Name>.app
  #
  # name     – PascalCase app name (e.g. "PostgresServer")
  # icon     – path to an .icns file (or null for no icon)
  # bundleId – reverse-DNS identifier (e.g. "org.postgresql.server.stub")
  mkAppStub =
    { name
    , icon ? null
    , bundleId
    }:
    let
      infoPlist = {
        CFBundleName = name;
        CFBundleIdentifier = bundleId;
        CFBundleVersion = "1.0";
        CFBundlePackageType = "APPL";
        CFBundleSignature = "????";
        LSUIElement = true;
      } // lib.optionalAttrs (icon != null) {
        CFBundleIconFile = "icon";
      };

      plistContent = toPlist { escape = true; } infoPlist;
    in
    pkgs.runCommand "${name}-app-stub" { } (''
      mkdir -p "$out/${name}.app/Contents/MacOS"
      mkdir -p "$out/${name}.app/Contents/Resources"

      cat > "$out/${name}.app/Contents/Info.plist" << 'PLIST'
      ${plistContent}
      PLIST

      echo -n "APPL????" > "$out/${name}.app/Contents/PkgInfo"

      # Minimal executable stub (required for a valid .app bundle)
      cat > "$out/${name}.app/Contents/MacOS/${name}" << 'STUB'
      #!/bin/sh
      exit 0
      STUB
      chmod +x "$out/${name}.app/Contents/MacOS/${name}"
    '' + lib.optionalString (icon != null) ''
      cp "${icon}" "$out/${name}.app/Contents/Resources/icon.icns"
    '');

  # ── mkWrapper ──────────────────────────────────────────────────────────
  # Creates a named executable via writeShellApplication.
  # Bakes in /bin/wait4path so the HM launchd module's /bin/sh wrap is unnecessary.
  # BTM and `ps` show the wrapper name instead of "sh".
  mkWrapper =
    { name
    , text
    , runtimeInputs ? []
    , excludeShellChecks ? []
    }:
    pkgs.writeShellApplication {
      inherit name runtimeInputs excludeShellChecks;
      text = ''
        /bin/wait4path /nix/store &>/dev/null
        ${text}
      '';
    };

  # ── mkPlist ────────────────────────────────────────────────────────────
  # Generates a launchd plist file in the Nix store from an attribute set.
  # The attrset should be a complete launchd.plist(5) config.
  mkPlist = config:
    pkgs.writeText "${config.Label}.plist" (toPlist { escape = true; } config);
}
