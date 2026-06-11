# lib/launchd-btm.nix — BTM (Background Task Management) helpers.
#
# BTM groups Login Items by .app bundle; these helpers give launchd
# daemons/agents a named binary inside an .app stub so System Settings
# shows a real name + icon instead of a generic "sh".
#
#   mkWrapper     — named wrapper binary for ProgramArguments.
#   stubDir       — where stubs are installed; ProgramArguments point inside.
#   mkStubInstall — activation-script bash: installs one stub idempotently
#                   (manifest-checked, so unchanged stubs are never rewritten
#                   and BTM stays quiet) and patches the stub's launchd user
#                   agents with AssociatedBundleIdentifiers for icon grouping.
#
# Codesigning is NOT done here — scripts/btm-patch-nix.sh signs all stubs
# with the real Apple Development identity (runs via `sure`).
{ lib, pkgs }: rec {
    stubDir = "/Users/darrenlu/.local/share/app-stubs";
    agentDir = "/Users/darrenlu/Library/LaunchAgents";

    # useSystemBash — for pre-mount scripts (darwin-store) that run before /nix exists.
    mkWrapper = {
        name,
        text,
        runtimeInputs ? [ ],
        excludeShellChecks ? [ ],
        useSystemBash ? false,
    }:
        if useSystemBash
        then
            pkgs.writeTextFile {
                inherit name;
                destination = "/bin/${name}";
                executable = true;
                text = ''
                    #!/bin/bash
                    set -euo pipefail
                    ${text}
                '';
            }
        else
            pkgs.writeShellApplication {
                inherit name runtimeInputs excludeShellChecks;
                text = ''
                    /bin/wait4path /nix/store &>/dev/null
                    ${text}
                '';
            };

    # One self-contained activation snippet per stub. Runs as root during
    # darwin-rebuild, so ownership is fixed up via SUDO_USER.
    #   name     — stub name; installs to ${stubDir}/<name>.app
    #   app      — path to the source .app bundle in this repo
    #   wrappers — [ { drv; bin; } ] binaries embedded in Contents/MacOS
    #   agents   — launchd user-agent labels to patch (plists in ${agentDir})
    mkStubInstall = {
        name,
        app,
        wrappers,
        agents ? [ ],
    }: let
        # Manifest = stub identity. If it matches, the stub is up to date and
        # left untouched (rewriting would invalidate the codesignature and
        # re-trigger BTM notifications).
        manifest = lib.concatStringsSep "\\n"
        ( [ "src=${app}" ] ++ map ( w: "wrapper=${w.bin}:${w.drv}" ) wrappers );

        patchAgent = label: ''
            _plist="${agentDir}/${label}.plist"
            if [[ -f "$_plist" ]] && [[ -d "$_stub_dst" ]]; then
              _bid=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$_stub_dst/Contents/Info.plist" 2>/dev/null)
              if [[ -n "$_bid" ]]; then
                _existing=$(/usr/libexec/PlistBuddy -c "Print :AssociatedBundleIdentifiers:0" "$_plist" 2>/dev/null || true)
                if [[ "$_existing" != "$_bid" ]]; then
                  /usr/libexec/PlistBuddy \
                    -c "Delete :AssociatedBundleIdentifiers" "$_plist" 2>/dev/null || true
                  /usr/libexec/PlistBuddy \
                    -c "Add :AssociatedBundleIdentifiers array" \
                    -c "Add :AssociatedBundleIdentifiers:0 string $_bid" \
                    "$_plist" 2>/dev/null && echo "BTM: patched ${label} -> ${name}"
                fi
              fi
            fi
        '';
    in ''
        # ── BTM stub: ${name}.app ──
        _stub_dst="${stubDir}/${name}.app"
        _manifest="${stubDir}/.stub-manifest-${name}"
        _expected="$(printf '${manifest}\n')"
        _real_user="''${SUDO_USER:-$(whoami)}"

        mkdir -p "${stubDir}"
        chown "$_real_user:staff" "${stubDir}"

        if [ -f "$_manifest" ] && [ "$(cat "$_manifest")" = "$_expected" ] && [ -d "$_stub_dst" ]; then
          echo "BTM: stub unchanged: ${name}.app"
        else
          echo "BTM: installing stub: ${name}.app"
          [ -d "$_stub_dst" ] && chmod -R u+w "$_stub_dst"
          rm -rf "$_stub_dst"
          cp -R "${app}" "$_stub_dst"
          chmod -R u+w "$_stub_dst"
          mkdir -p "$_stub_dst/Contents/MacOS"

          ${lib.concatMapStringsSep "\n" ( w: ''
            cp "${w.drv}/bin/${w.bin}" "$_stub_dst/Contents/MacOS/${w.bin}"
            chmod u+wx "$_stub_dst/Contents/MacOS/${w.bin}"
        '' ) wrappers}

          printf '#!/bin/sh\nexit 0\n' > "$_stub_dst/Contents/MacOS/Stub"
          chmod u+x "$_stub_dst/Contents/MacOS/Stub"

          # Ownership only — codesigning happens in btm-patch-nix.sh (via `sure`)
          chown -R "$_real_user:staff" "$_stub_dst"
          printf '%s\n' "$_expected" > "$_manifest"
          chown "$_real_user:staff" "$_manifest"
        fi

        ${lib.concatStringsSep "\n" ( map patchAgent agents )}
    '';
}
