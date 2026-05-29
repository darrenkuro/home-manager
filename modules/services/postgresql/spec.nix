# Shared facts for the PostgreSQL service — imported by both
# `home.nix` (HM scope) and `darwin.nix` (nix-darwin scope) so that paths,
# port, and the pg derivation are defined exactly once.
#
# Pure function of { pkgs, home } — no module args, no `config`. Safe to
# import from either scope.
{ pkgs, home }: rec {
    major = "17";
    port = "5432";
    socket = "/tmp";
    dataDir = "${home}/.local/share/postgresql/data";
    logDir = "${home}/.local/state/postgresql";
    backupDir = "${home}/.local/share/postgresql/backups";

    pkg = pkgs.postgresql_17.withPackages ( ps: [ ps.pgvector ] );
}
