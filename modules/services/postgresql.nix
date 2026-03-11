# PostgreSQL server + automated backup — BTM-friendly launchd agents for macOS
#
# Uses the BTM module (btm.nix) instead of launchd.agents to avoid
# the /bin/sh wrapper that makes BTM show "sh" as the process name.
#
# Creates:
#   - PostgresServer wrapper     → named binary for the server agent
#   - PostgresBackup wrapper     → named binary for the backup agent
#   - Postgres.app stub          → shared BTM icon for both agents
#   - Two launchd plists via btm.agents (bypassing HM's mutateConfig)
{ config, lib, pkgs, ... }:

let
  btm = import ../../lib/launchd-btm.nix { inherit lib pkgs; };

  # ── Tunable Parameters ──
  pg = pkgs.postgresql_17.withPackages (ps: [ ps.pgvector ]);
  dataDir = "${config.home.homeDirectory}/.local/share/postgresql/data";
  logDir = "${config.home.homeDirectory}/.local/state/postgresql";
  socketDir = "/tmp";
  pgPort = "5432";
  pgMajor = "17";

  backupBaseDir = "${config.home.homeDirectory}/.local/share/postgresql/backups";
  backupDestinations = [ backupBaseDir ];
  backupInterval = { Hour = 3; Minute = 0; };

  # ── Generated Configs ──
  pgConf = pkgs.writeText "postgresql.conf" ''
    # Connection
    listen_addresses = 'localhost'
    port = ${pgPort}
    unix_socket_directories = '${socketDir}'
    max_connections = 50

    # Memory
    shared_buffers = 256MB
    work_mem = 16MB
    effective_cache_size = 1GB

    # Logging
    logging_collector = on
    log_directory = '${logDir}'
    log_filename = 'postgresql-%a.log'
    log_rotation_age = 1d
    log_rotation_size = 0
    log_truncate_on_rotation = on
    log_min_duration_statement = 1000

    # Extensions
    shared_preload_libraries = 'vector'

    # Locale safety (macOS)
    lc_messages = 'C'
  '';

  pgHba = ../../configs/postgresql/pg_hba.conf;

  # ── Named Wrappers ──
  # These become the Program in the plist — BTM shows "PostgresServer" / "PostgresBackup"
  serverWrapper = btm.mkWrapper {
    name = "PostgresServer";
    runtimeInputs = [ pg ];
    text = ''
      exec postgres \
        -D "${dataDir}" \
        -c "config_file=${pgConf}" \
        -c "hba_file=${pgHba}" \
        -k "${socketDir}"
    '';
  };

  backupWrapper = btm.mkWrapper {
    name = "PostgresBackup";
    runtimeInputs = [ pg ];
    excludeShellChecks = [ "SC2043" ];
    text = ''
      set -euo pipefail

      TIMESTAMP=$(date +%Y%m%d_%H%M%S)
      LOG="${logDir}/backup.log"

      log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

      # Wait for server to be ready
      if ! pg_isready -h ${socketDir} -p ${pgPort} -q 2>/dev/null; then
        log "ERROR: PostgreSQL not running, skipping backup"
        exit 1
      fi

      # Get all user databases
      DBS=$(psql -h ${socketDir} -p ${pgPort} -At -c \
        "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';" postgres)

      if [ -z "$DBS" ]; then
        log "No user databases found, skipping backup"
        exit 0
      fi

      # Dump each database to each destination
      for db in $DBS; do
        for dest in ${lib.concatStringsSep " " backupDestinations}; do
          mkdir -p "$dest"
          DUMPFILE="$dest/''${db}_''${TIMESTAMP}.dump"
          if pg_dump -h ${socketDir} -p ${pgPort} --format=custom "$db" > "$DUMPFILE" 2>>"$LOG"; then
            log "OK: $db -> $DUMPFILE ($(du -h "$DUMPFILE" | cut -f1))"
          else
            log "FAIL: $db -> $DUMPFILE"
            rm -f "$DUMPFILE"
          fi
        done
      done

      # ── Retention Cleanup ──
      # Daily: keep 7 days | Weekly (Monday): keep 4 weeks | Monthly (1st): keep 12 months
      NOW=$(date +%s)

      for dest in ${lib.concatStringsSep " " backupDestinations}; do
        for f in "$dest"/*.dump; do
          [ -f "$f" ] || continue
          BASENAME=$(basename "$f")
          DATE_STR=$(echo "$BASENAME" | grep -oE '[0-9]{8}_[0-9]{6}' | head -1)
          [ -z "$DATE_STR" ] && continue

          FILE_TS=$(date -j -f "%Y%m%d_%H%M%S" "$DATE_STR" +%s 2>/dev/null) || continue
          AGE_DAYS=$(( (NOW - FILE_TS) / 86400 ))
          FILE_DOW=$(date -j -f "%Y%m%d_%H%M%S" "$DATE_STR" +%u 2>/dev/null) || continue
          FILE_DOM=$(date -j -f "%Y%m%d_%H%M%S" "$DATE_STR" +%d 2>/dev/null) || continue

          DELETE=0
          if [ "$AGE_DAYS" -lt 7 ]; then
            DELETE=0
          elif [ "$AGE_DAYS" -lt 28 ]; then
            [ "$FILE_DOW" != "1" ] && DELETE=1
          elif [ "$AGE_DAYS" -lt 365 ]; then
            [ "$FILE_DOM" != "01" ] && DELETE=1
          else
            DELETE=1
          fi

          if [ "$DELETE" -eq 1 ]; then
            rm -f "$f"
            log "PRUNE: $BASENAME (age=''${AGE_DAYS}d)"
          fi
        done
      done

      log "Backup run complete"
    '';
  };

  # ── App Stub (shared icon for both server + backup) ──
  postgresStub = btm.mkAppStub {
    name = "Postgres";
    bundleId = "com.local.postgres.stub";
    icon = ../../configs/icons/Postgre.icns;
  };

  # ── Launchd Plists ──
  serverPlist = btm.mkPlist {
    Label = "org.postgresql.server";
    ProgramArguments = [ "${serverWrapper}/bin/PostgresServer" ];
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 10;
    StandardOutPath = "${logDir}/launchd-stdout.log";
    StandardErrorPath = "${logDir}/launchd-stderr.log";
    AssociatedBundleIdentifiers = [ "com.local.postgres.stub" ];
    EnvironmentVariables = {
      PATH = "${pg}/bin:/usr/bin:/bin";
      HOME = config.home.homeDirectory;
      PGDATA = dataDir;
    };
  };

  backupPlist = btm.mkPlist {
    Label = "org.postgresql.backup";
    ProgramArguments = [ "${backupWrapper}/bin/PostgresBackup" ];
    StartCalendarInterval = [ backupInterval ];
    StandardOutPath = "${logDir}/backup-stdout.log";
    StandardErrorPath = "${logDir}/backup-stderr.log";
    AssociatedBundleIdentifiers = [ "com.local.postgres.stub" ];
    EnvironmentVariables = {
      PATH = "${pg}/bin:/usr/bin:/bin";
      HOME = config.home.homeDirectory;
    };
  };

in
{
  # ── Directory Setup ──
  home.activation.postgresqlInit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${logDir}" "${backupBaseDir}" ${lib.concatMapStringsSep " " (d: ''"${d}"'') backupDestinations}

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

  # ── Register with BTM module ──
  btm.agents = {
    "org.postgresql.server" = serverPlist;
    "org.postgresql.backup" = backupPlist;
  };

  btm.stubs = {
    "Postgres" = postgresStub;
  };

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
