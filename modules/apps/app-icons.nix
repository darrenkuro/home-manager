# Declaratively stamp custom Finder icons onto apps that ship without one
# (or whose bundle icon you'd rather override). Reapplied on every `re`.
#
# Mechanism: NSWorkspace.setIcon via scripts/set-app-icon.js (system osascript,
# no deps). Idempotent + self-healing — an entry is re-stamped only when its
# icns changed OR the app lost its custom-icon marker (which is exactly what an
# app update does), so a no-op `re` stays a no-op but a wiped icon is recovered.
{ pkgs, config, lib, ... }: let
    setter = ./../../scripts/set-app-icon.js;

    # ── The one thing you own: app bundle → vendored icns ──────────────
    # Key   = absolute path to the .app (must be user-writable under non-sudo `re`;
    #         ~/Applications is fine, /Applications generally needs `sure`).
    # Value = icns in ./icons/ (vendored into git → hermetic via the nix store).
    iconMap = {
        "${config.home.homeDirectory}/Applications/Claude Code URL Handler.app" = ./icons/claude-code-url-handler.icns;
    };

    # Emit one reconcile block per entry. Paths are quoted for spaces.
    toBlock = appPath: icns: ''
    reconcile_icon "${appPath}" "${icns}"
  '';
    blocks = lib.concatStringsSep "\n" ( lib.mapAttrsToList toBlock iconMap );
in
{
    home.activation.appIcons = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    STATE="$HOME/.local/state/app-icons"
    run mkdir -p "$STATE"
    icons_changed=0

    reconcile_icon() {
      local app="$1" icns="$2"
      if [ ! -e "$app" ]; then
        warnEcho "app-icons: skipping missing app: $app"
        return 0
      fi

      # Identity = the icns store path (content-addressed, so it changes iff the
      # icon changes). Slug the app path for a per-app state file.
      local slug want have
      slug=$(echo "$app" | ${pkgs.coreutils}/bin/sha256sum | cut -c1-16)
      want="$icns"
      have=$(cat "$STATE/$slug" 2>/dev/null || true)

      # The custom-icon marker: Finder stores it in an "Icon\r" file in the bundle.
      # If it's gone (app was updated/replaced), re-stamp regardless of the hash.
      local marker
      marker=$(printf '%s/Icon\r' "$app")

      if [ "$have" = "$want" ] && [ -f "$marker" ]; then
        return 0  # already converged — no churn
      fi

      if run /usr/bin/osascript -l JavaScript ${setter} "$app" "$icns"; then
        echo "$want" > "$STATE/$slug"
        icons_changed=1
        verboseEcho "app-icons: stamped $app"
      else
        warnEcho "app-icons: failed to set icon for $app (permissions? try under \`sure\`)"
      fi
    }

    ${blocks}

    # Only nudge the launcher when something actually changed — the launcher
    # (Launchpad and its successors) caches icons aggressively.
    if [ "$icons_changed" = 1 ]; then
      run /usr/bin/killall Dock 2>/dev/null || true
    fi
  '';
}
