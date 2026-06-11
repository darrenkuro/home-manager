# PostgreSQL — user half: package, data-dir init, env vars, aliases.
# The system half (launchd agents, BTM stub, postgresql.conf) is ./darwin.nix.
# Shared facts (paths, port, package) come from ./spec.nix.
#
# Mac-only: imported from the root home.nix inside the tag == "mac" list.
{ pkgs, config, lib, ... }: let
    pg = import ./spec.nix { inherit pkgs; home = config.home.homeDirectory; };
in
{
    home.packages = [ pg.pkg ]; # postgresql_17 + pgvector

    # Initialize data directory on first run; warn on major-version mismatch
    home.activation.postgresql = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "${pg.logDir}" "${pg.backupDir}"

    if [ -d "${pg.dataDir}" ]; then
      if [ -f "${pg.dataDir}/PG_VERSION" ]; then
        CURRENT=$(cat "${pg.dataDir}/PG_VERSION")
        if [ "$CURRENT" != "${pg.major}" ]; then
          echo "WARNING: PostgreSQL version mismatch: data=$CURRENT, package=${pg.major}"
          echo "  Manual pg_upgrade required. Data dir: ${pg.dataDir}"
        fi
      fi
    else
      echo "Initializing PostgreSQL ${pg.major} database..."
      ${pg.pkg}/bin/initdb \
        -D "${pg.dataDir}" \
        --locale=C \
        --encoding=UTF8 \
        --auth=trust \
        --username="$(whoami)"
    fi
  '';

    home.sessionVariables = { PGDATA = pg.dataDir; PGHOST = pg.socket; };

    programs.zsh.shellAliases = {
        pglog = "tail -f ${pg.logDir}/postgresql-$(date +%a).log";
        pgbackuplog = "tail -f ${pg.logDir}/backup.log";
        pgstatus = "pg_isready -h ${pg.socket} -p ${pg.port}";
    };
}
