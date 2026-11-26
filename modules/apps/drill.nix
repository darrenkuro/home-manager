# drill — coding-drill runner (darrenkuro/drill, a flake input like bocal): stubs a
# problem, opens $EDITOR, runs its JSON test cases, grades, and records the attempt
# through the `logbook` CLI. `logbook` itself runs from the local checkout
# ($DEV/logbook: native better-sqlite3 + the data dir, so not a store input) —
# macOS only, where that checkout lives.
{ pkgs, lib, tag, drill, ... }: {
    home.packages = [
        # nodejs_22 matches the pin in home.nix (24/25 uncached or broken on aarch64-darwin)
        ( pkgs.writeShellScriptBin "drill" ''
                exec ${pkgs.nodejs_22}/bin/node --experimental-strip-types ${drill}/src/cli.ts "$@"
            '' )
    ] ++ lib.optionals ( tag == "mac" ) [
        ( pkgs.writeShellScriptBin "logbook" ''
                exec ${pkgs.nodejs_22}/bin/node "''${DEV:-$HOME/Documents/dev}/logbook/src/cli.ts" "$@"
            '' )
    ];
}
