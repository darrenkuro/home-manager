# Alfred — the preferences bundle is the private git repo darrenkuro/alfred-workflows
# and lives at ~/.config/alfred/Alfred.alfredpreferences on every Mac. hm owns the
# location, not the contents: the bundle is live state Alfred writes to, so it is
# never a store symlink. Activation clones the repo when it is missing (moving an
# old ~/Documents clone if there is one) and points Alfred at it through the
# `current` key of ~/Library/Application Support/Alfred/prefs.json, the only
# pointer Alfred has. Both steps are skipped with a warning while Alfred is
# running, because Alfred holds the folder open and rewrites prefs.json itself.
# Between Macs the bundle syncs by git inside `tsync` (functions/tsync.sh):
# commit, pull --rebase, push on both Macs. `doctor` warns on drift.
{ config, lib, pkgs, homeDir, ... }: let
    alfredDir = "${config.xdg.configHome}/alfred/Alfred.alfredpreferences";
    oldDir = "${homeDir}/Documents/Alfred.alfredpreferences";
    prefsJson = "${homeDir}/Library/Application Support/Alfred/prefs.json";
    repo = "git@github.com:darrenkuro/alfred-workflows.git";
    # Alfred keeps a per-major-version history of chosen sync folders, home-relative
    syncFolder = lib.replaceStrings [ homeDir ] [ "~" ] ( dirOf alfredDir );
    jq = "${pkgs.jq}/bin/jq";
    git = "${pkgs.git}/bin/git";
in
{
    home.activation.alfredPrefs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      (
        set -e
        dir="${alfredDir}"; old="${oldDir}"; prefs="${prefsJson}"
        running=false; /usr/bin/pgrep -xq Alfred && running=true

        if [ ! -d "$dir/.git" ]; then
          if [ -d "$old/.git" ]; then
            if $running; then
              echo "⚠ Alfred: quit Alfred and run re again — the prefs bundle is still in ~/Documents"
              exit 0
            fi
            run mkdir -p "$(dirname "$dir")"
            run mv "$old" "$dir"
          else
            run mkdir -p "$(dirname "$dir")"
            run ${git} clone -q ${repo} "$dir"
          fi
        fi

        current=$(${jq} -r '.current // empty' "$prefs" 2>/dev/null || true)
        if [ "$current" != "$dir" ]; then
          if $running; then
            echo "⚠ Alfred: quit Alfred and run re again — prefs.json points at ''${current:-the default folder}"
            exit 0
          fi
          if [ -n "''${DRY_RUN+1}" ]; then
            echo "would point $prefs at $dir"
          else
            mkdir -p "$(dirname "$prefs")"
            if [ -f "$prefs" ]; then
              ${jq} --arg c "$dir" --arg p "${syncFolder}" \
                '.current = $c | .syncfolders["5"] = $p' "$prefs" > "$prefs.tmp"
            else
              ${jq} -n --arg c "$dir" --arg p "${syncFolder}" \
                '{ current: $c, syncfolders: { "5": $p } }' > "$prefs.tmp"
            fi
            mv "$prefs.tmp" "$prefs"
          fi
        fi
      ) || echo "⚠ Alfred prefs step failed — continuing"
    '';
}
