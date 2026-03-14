# PostgreSQL home-manager module — directories, env vars, aliases.
# LaunchAgents and BTM stubs are managed in darwin.nix.
{
  config,
  lib,
  pkgs,
  ...
}: let
  pg = pkgs.postgresql_17.withPackages (ps: [ps.pgvector]);
  dataDir = "${config.home.homeDirectory}/.local/share/postgresql/data";
  logDir = "${config.home.homeDirectory}/.local/state/postgresql";
  socketDir = "/tmp";
  pgPort = "5432";
  pgMajor = "17";
  backupDir = "${config.home.homeDirectory}/.local/share/postgresql/backups";
in {
  # ── Directory Setup + initdb ──
  home.activation.postgresqlInit = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p "${logDir}" "${backupDir}"

    if [ -d "${dataDir}" ]; then
      if [ -f "${dataDir}/PG_VERSION" ]; then
        CURRENT=$(cat "${dataDir}/PG_VERSION")
        if [ "$CURRENT" != "${pgMajor}" ]; then
          echo "WARNING: PostgreSQL version mismatch: data=$CURRENT, package=${pgMajor}"
          echo "  Manual pg_upgrade required. Data dir: ${dataDir}"
        fi
      fi
    else
      echo "Initializing PostgreSQL ${pgMajor} database..."
      ${pg}/bin/initdb \
        -D "${dataDir}" \
        --locale=C \
        --encoding=UTF8 \
        --auth=trust \
        --username="$(whoami)"
    fi
  '';

  # ── Environment Variables ──
  home.sessionVariables = {
    PGDATA = dataDir;
    PGHOST = socketDir;
  };

  # ── Shell Aliases ──
  programs.zsh.shellAliases = {
    pglog = "tail -f ${logDir}/postgresql-$(date +%a).log";
    pgbackuplog = "tail -f ${logDir}/backup.log";
    pgstatus = "pg_isready -h ${socketDir} -p ${pgPort}";
  };
}
