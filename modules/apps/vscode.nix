# VS Code — settings.json is copied in place by scripts/copy-files.sh (writable,
# VS Code owns it at runtime). This module owns the extension baseline: the list
# below is the source of truth, activation installs what's missing and warns
# about anything installed that isn't tracked here (same warn-not-remove policy
# as claude.nix's plugin check). ~/.vscode/extensions stays VS Code's.
{ lib, pkgs, tag, profile, ... }: let
    isWork = profile == "work";

    requiredExtensions = [
        "anthropic.claude-code"
        "dprint.dprint"
        "emeraldwalk.runonsave"
        "github.github-vscode-theme" # workbench.colorTheme
        "jnoortheen.nix-ide"
        "liviuschera.noctis"
        "mikestead.dotenv"
        "ms-python.debugpy"
        "ms-python.python"
        "ms-python.vscode-pylance"
        "ms-python.vscode-python-envs"
        "pkief.material-icon-theme" # workbench.iconTheme
        "tamasfe.even-better-toml"
        "wakatime.vscode-wakatime"
        "zokugun.explicit-folding"
    ] ++
    lib.optionals ( !isWork ) [
        # Specialist toolchains stay on the personal target (see home.nix packages)
        "13xforever.language-x86-64-assembly"
        "dan-c-underwood.arm"
        "haxogames.x86-assembly-syntax"
        "kube.42header"
        "ms-vscode.cpptools"
        "rust-lang.rust-analyzer"
    ];
in
{
    home.activation.vscodeExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Activation PATH lacks /opt/homebrew/bin; fall back to the app bundle CLI
    code=""
    for c in "$(command -v code 2>/dev/null)" /opt/homebrew/bin/code \
             "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"; do
      if [ -n "$c" ] && [ -x "$c" ]; then code="$c"; break; fi
    done

    if [ -z "$code" ]; then
      echo "⚠ VS Code: 'code' CLI not found — extensions not reconciled${lib.optionalString
    ( tag == "mac" ) " (run 'sure' to install the cask first)"}"
    else
      installed="$("$code" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"

      # Install missing (idempotent; only hits the network for absent IDs)
      for ext in ${lib.concatStringsSep " " requiredExtensions}; do
        if ! printf '%s\n' "$installed" | ${pkgs.gnugrep}/bin/grep -qx "$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"; then
          echo "Installing VS Code extension: $ext"
          "$code" --install-extension "$ext" >/dev/null 2>&1 \
            || echo "⚠ VS Code: failed to install $ext — run manually: code --install-extension $ext"
        fi
      done

      # Installed extensions unknown to vscode.nix — warn, never remove
      unknown=""
      for ext in $installed; do
        case " ${lib.toLower ( lib.concatStringsSep " " requiredExtensions )} " in
          *" $ext "*) ;;
          *) unknown="$unknown  - $ext\n" ;;
        esac
      done
      if [ -n "$unknown" ]; then
        echo ""
        echo "⚠ VS Code: these installed extensions are not tracked in vscode.nix (add to requiredExtensions or uninstall):"
        printf "$unknown"
        echo ""
      fi
    fi
  '';
}
