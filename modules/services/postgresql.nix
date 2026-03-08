# PostgreSQL server + automated backup — launchd agents for macOS
# Server: runs postgres with Nix-managed config files
# Backup: daily pg_dump with Time Machine-inspired retention
{ config, lib, pkgs, ... }:

let
  # ── Tunable Parameters ──
  pg = pkgs.postgresql_17.withPackages (ps: [ ps.pgvector ]);
  dataDir = "${config.home.homeDirectory}/.local/share/postgresql/data";
  logDir = "${config.home.homeDirectory}/.local/state/postgresql";
  socketDir = "/tmp";
  pgPort = "5432";
  pgMajor = "17";

  backupBaseDir = "${config.home.homeDirectory}/.local/share/postgresql/backups";
  # Add extra destinations here (e.g. iCloud path)
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

  # ── Backup Script ──
  pgBackupScript = pkgs.writeShellScript "postgresql-backup" ''
    set -euo pipefail

    PATH="${pg}/bin:$PATH"
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
          log "OK: $db → $DUMPFILE ($(du -h "$DUMPFILE" | cut -f1))"
        else
          log "FAIL: $db → $DUMPFILE"
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
        # Extract date from filename: dbname_YYYYMMDD_HHMMSS.dump
        DATE_STR=$(echo "$BASENAME" | grep -oE '[0-9]{8}_[0-9]{6}' | head -1)
        [ -z "$DATE_STR" ] && continue

        # Parse date (BSD date on macOS)
        FILE_TS=$(date -j -f "%Y%m%d_%H%M%S" "$DATE_STR" +%s 2>/dev/null) || continue
        AGE_DAYS=$(( (NOW - FILE_TS) / 86400 ))
        FILE_DOW=$(date -j -f "%Y%m%d_%H%M%S" "$DATE_STR" +%u 2>/dev/null) || continue
        FILE_DOM=$(date -j -f "%Y%m%d_%H%M%S" "$DATE_STR" +%d 2>/dev/null) || continue

        DELETE=0
        if [ "$AGE_DAYS" -lt 7 ]; then
          DELETE=0  # Daily tier: keep all
        elif [ "$AGE_DAYS" -lt 28 ]; then
          [ "$FILE_DOW" != "1" ] && DELETE=1  # Weekly tier: keep Mondays
        elif [ "$AGE_DAYS" -lt 365 ]; then
          [ "$FILE_DOM" != "01" ] && DELETE=1  # Monthly tier: keep 1st
        else
          DELETE=1  # Older than 1 year: delete
        fi

        if [ "$DELETE" -eq 1 ]; then
          rm -f "$f"
          log "PRUNE: $BASENAME (age=''${AGE_DAYS}d)"
        fi
      done
    done

    log "Backup run complete"
  '';

  # Compiled shim so macOS Login Items shows "postgresql-backup" instead of "sh"
  pgBackupBin = pkgs.stdenv.mkDerivation {
    name = "postgresql-backup";
    dontUnpack = true;
    buildPhase = ''
      cat > main.c << 'EOF'
      #include <unistd.h>
      int main(void) { execl("${pgBackupScript}", "postgresql-backup", (char *)0); return 1; }
      EOF
      $CC -o postgresql-backup main.c
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp postgresql-backup $out/bin/
    '';
  };
in
{
  # ── Directory Setup ──
  home.activation.postgresqlInit = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p "${logDir}" "${backupBaseDir}" ${lib.concatMapStringsSep " " (d: ''"${d}"'') backupDestinations}

    if [ -d "${dataDir}" ]; then
      # Version mismatch detection
      if [ -f "${dataDir}/PG_VERSION" ]; then
        CURRENT=$(cat "${dataDir}/PG_VERSION")
        if [ "$CURRENT" != "${pgMajor}" ]; then
          echo "⚠️  PostgreSQL version mismatch: data=''${CURRENT}, package=${pgMajor}"
          echo "   Manual pg_upgrade required. Data dir: ${dataDir}"
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

  # ── Server Agent ──
  launchd.agents.postgresql = {
    enable = true;
    config = {
      Label = "org.postgresql.server";
      ProgramArguments = [
        "${pg}/bin/postgres"
        "-D" dataDir
        "-c" "config_file=${pgConf}"
        "-c" "hba_file=${pgHba}"
        "-k" socketDir
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      StandardOutPath = "${logDir}/launchd-stdout.log";
      StandardErrorPath = "${logDir}/launchd-stderr.log";
      EnvironmentVariables = {
        PATH = "${pg}/bin:/usr/bin:/bin";
        HOME = config.home.homeDirectory;
        PGDATA = dataDir;
      };
    };
  };

  # ── Backup Agent ──
  launchd.agents.postgresql-backup = {
    enable = true;
    config = {
      Label = "org.postgresql.backup";
      ProgramArguments = [ "${pgBackupBin}/bin/postgresql-backup" ];
      StartCalendarInterval = [ backupInterval ];
      StandardOutPath = "${logDir}/backup-stdout.log";
      StandardErrorPath = "${logDir}/backup-stderr.log";
      EnvironmentVariables = {
        PATH = "${pg}/bin:/usr/bin:/bin";
        HOME = config.home.homeDirectory;
      };
    };
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
