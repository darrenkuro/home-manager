# mdserve — serve a single markdown file as a styled, textbook-like local
# page (blocks in the foreground; single instance — starting it again closes
# the previous session; edit the md and refresh).
#
# Source lives in ./mdserve: a zero-dep Node script plus browser shell assets
# (marked.min.js vendored). The script resolves its assets relative to itself,
# so for quick hacking without a rebuild, run the working tree directly:
#   node $HM/modules/apps/mdserve/mdserve.mjs <file.md>
#
# macOS-only — uses `open` to launch the browser. Imported conditionally
# from home.nix on `tag == "mac"`.
{ pkgs, ... }: {
    home.packages = [
        # nodejs_22 matches the pin in home.nix (24/25 uncached or broken on aarch64-darwin)
        ( pkgs.writeShellScriptBin "mdserve" ''
                exec ${pkgs.nodejs_22}/bin/node ${./mdserve}/mdserve.mjs "$@"
            '' )
    ];
}
