# Ambience — the background tracks `noise` plays (functions/noise.sh, Alfred
# keyword `noise`). Audio is not in the repo: the copy that plays lives in
# ~/.local/share/audio (local, so Dropbox can't offload it mid-loop), the backup
# in Dropbox audio/ambience (laptop only; the work iMac has no Dropbox and gets
# them through `tsync`, profile `ambience` in unison.nix). Each track is
# <name>.m4a plus an optional icons/<name>.png. Activation only checks: it warns
# about listed tracks missing on either side and local tracks not listed here.
{ lib, homeDir, ... }: let
    tracks = [
        "ambience-noise"
        "cowboy-bebop-rain-jazz"
        "expedition33-lofi"
        "expedition33-lofi-2"
        "ghibli-jazz-cafe"
        "japanese-chill-lofi"
        "jpop-anime-ost"
        "lofi-tokyo-night"
        "one-piece-lofi"
        "persona5-jazz-cafe"
    ];
    dir = "${homeDir}/.local/share/audio";
    backup = "${homeDir}/Dropbox/audio/ambience";
    names = lib.concatStringsSep " " tracks;
in
{
    home.activation.ambienceCheck = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      (
        dir="${dir}"; backup="${backup}"
        run mkdir -p "$dir"
        # The work iMac has no Dropbox: nothing to back up to, tsync brings the tracks
        dropbox=false; [ -d "$(dirname "$(dirname "$backup")")" ] && dropbox=true
        missing=""; unbacked=""; unlisted=""
        for t in ${names}; do
          [ -f "$dir/$t.m4a" ] || missing="$missing $t"
          $dropbox && { [ -f "$backup/$t.m4a" ] || unbacked="$unbacked $t"; }
        done
        for f in "$dir"/*.m4a; do
          [ -e "$f" ] || continue
          t=$(basename "$f" .m4a)
          case " ${names} " in *" $t "*) ;; *) unlisted="$unlisted $t" ;; esac
        done
        if [ -n "$missing" ]; then
          echo "⚠ Ambience: missing in ~/.local/share/audio:$missing"
          if $dropbox; then
            echo "  copy them in: cp -Rn ~/Dropbox/audio/ambience/. ~/.local/share/audio/"
          else
            echo "  run tsync on the laptop to copy them over"
          fi
        fi
        if [ -n "$unbacked" ]; then
          echo "⚠ Ambience: not backed up in Dropbox:$unbacked"
          echo "  back them up: mkdir -p ~/Dropbox/audio/ambience && cp -Rn ~/.local/share/audio/. ~/Dropbox/audio/ambience/"
        fi
        if [ -n "$unlisted" ]; then
          echo "⚠ Ambience: local tracks not listed in modules/apps/ambience.nix:$unlisted"
        fi
      )
    '';
}
