# tidy — backlog / future enhancements

`tidy` lives in `functions/tidy.sh`. **Done:** merged `clean`→`tidy`, Xcode/pnpm/Nix
reclaim, `/bin/rm` safety, whitelist `$HOME` scrub, reclaimed-space report.

Remaining ideas, in priority order:

## 1. Nix store optimise + system-profile GC — `darwin.nix` (needs `sure`)
`tidy` only GCs the **user + home-manager** Nix profiles (no sudo). The root-owned
nix-darwin **system** profile is untouched. Add declaratively:

```nix
nix.gc = {
  automatic = true;
  interval = { Weekday = 0; Hour = 3; Minute = 0; };
  options = "--delete-older-than 30d";
};
nix.optimise.automatic = true;  # hardlink-dedupe /nix/store — orthogonal to GC, often frees 1–5 GB more
```

Runs weekly via launchd as root. `optimise` compresses the *surviving* store paths
(GC only removes dead ones), so the two are complementary.

## 2. Docker prune when the daemon is up — `tidy`
Add a section that runs only if the daemon is reachable:

```sh
if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
    docker system prune -f    # dangling images + build cache + stopped containers
fi
```

Never add `-a --volumes` — that would delete data. No-op when Docker is off.

## 3. Recursive `.DS_Store` sweep — `tidy` (optional)
Clear Finder litter beyond `$HOME`:

```sh
find "$DEV" "$DBOX" -name .DS_Store -type f -delete 2>/dev/null
```

Small tidiness win; low priority.
