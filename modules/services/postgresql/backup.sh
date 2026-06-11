# PostgreSQL backup — runs nightly via the PostgresBackup launchd agent.
# Inputs (exported by the wrapper in ./darwin.nix):
#   PG_SOCKET, PG_PORT, PG_LOG_DIR, PG_BACKUP_DIR
set -euo pipefail
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="$PG_LOG_DIR/backup.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

if ! pg_isready -h "$PG_SOCKET" -p "$PG_PORT" -q 2>/dev/null; then
  log "ERROR: PostgreSQL not running, skipping backup"
  exit 1
fi

DBS=$(psql -h "$PG_SOCKET" -p "$PG_PORT" -At -c \
  "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';" postgres)

if [ -z "$DBS" ]; then
  log "No user databases found, skipping backup"
  exit 0
fi

for db in $DBS; do
  mkdir -p "$PG_BACKUP_DIR"
  DUMPFILE="$PG_BACKUP_DIR/${db}_${TIMESTAMP}.dump"
  if pg_dump -h "$PG_SOCKET" -p "$PG_PORT" --format=custom "$db" > "$DUMPFILE" 2>>"$LOG"; then
    log "OK: $db -> $DUMPFILE ($(du -h "$DUMPFILE" | cut -f1))"
  else
    log "FAIL: $db -> $DUMPFILE"
    rm -f "$DUMPFILE"
  fi
done

# Retention: 7 daily, 4 weekly (Mon), 12 monthly (1st)
NOW=$(date +%s)
for f in "$PG_BACKUP_DIR"/*.dump; do
  [ -f "$f" ] || continue
  BASENAME=$(basename "$f")
  DATE_STR=$(echo "$BASENAME" | grep -oE '[0-9]{8}_[0-9]{6}' | head -1)
  [ -z "$DATE_STR" ] && continue
  FILE_TS=$(date -j -f "%Y%m%d_%H%M%S" "$DATE_STR" +%s 2>/dev/null) || continue
  AGE_DAYS=$(( (NOW - FILE_TS) / 86400 ))
  FILE_DOW=$(date -j -f "%Y%m%d_%H%M%S" "$DATE_STR" +%u 2>/dev/null) || continue
  FILE_DOM=$(date -j -f "%Y%m%d_%H%M%S" "$DATE_STR" +%d 2>/dev/null) || continue
  DELETE=0
  if [ "$AGE_DAYS" -lt 7 ]; then DELETE=0
  elif [ "$AGE_DAYS" -lt 28 ]; then [ "$FILE_DOW" != "1" ] && DELETE=1
  elif [ "$AGE_DAYS" -lt 365 ]; then [ "$FILE_DOM" != "01" ] && DELETE=1
  else DELETE=1; fi
  if [ "$DELETE" -eq 1 ]; then
    rm -f "$f"
    log "PRUNE: $BASENAME (age=${AGE_DAYS}d)"
  fi
done
log "Backup run complete"
