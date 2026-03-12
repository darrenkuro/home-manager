INSTALL_TAG=(MAC)
REQUIRED_TOOLS=(security python3 curl)
_check_preamble || return 0

# --- Source

function claude-usage {
  local config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.config/claude}"
  local suffix
  suffix=$(printf '%s' "$config_dir" | python3 -c "import sys,hashlib; print(hashlib.sha256(sys.stdin.read().encode()).hexdigest()[:8])")
  local svc="Claude Code-credentials-$suffix"

  local creds
  creds=$(security find-generic-password -s "$svc" -w 2>/dev/null)
  if [ -z "$creds" ]; then
    # Fall back to old name (pre-suffix versions)
    creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
  fi

  if [ -z "$creds" ]; then
    echo "No Claude Code credentials found. Run /login in Claude Code."
    return 1
  fi

  local token
  token=$(printf '%s' "$creds" | python3 -c "import sys,json; print(json.load(sys.stdin)['claudeAiOauth']['accessToken'])" 2>/dev/null)
  if [ -z "$token" ]; then
    echo "Failed to parse token from Keychain."
    return 1
  fi

  local resp
  resp=$(curl -sf "https://api.anthropic.com/api/oauth/usage" \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20")

  if [ -z "$resp" ]; then
    echo "Token expired. Use Claude Code to refresh (any prompt will do)."
    return 1
  fi

  printf '%s' "$resp" | python3 -c "
import sys, json
from datetime import datetime, timezone

d = json.load(sys.stdin)

def fmt(label, obj):
    if not obj or obj.get('utilization') is None or not obj.get('resets_at'):
        return
    pct = obj['utilization']
    reset = datetime.fromisoformat(obj['resets_at'])
    delta = reset - datetime.now(timezone.utc)
    hours, remainder = divmod(max(0, int(delta.total_seconds())), 3600)
    mins = remainder // 60

    bar_len = 30
    filled = int(pct / 100 * bar_len)
    bar = '█' * filled + '░' * (bar_len - filled)

    print(f'  {label:<16} {bar} {pct:5.1f}%   resets in {hours}h {mins:02d}m')

print()
fmt('Session (5h)', d.get('five_hour'))
fmt('Weekly (7d)', d.get('seven_day'))
fmt('Sonnet (7d)', d.get('seven_day_sonnet'))
fmt('Opus (7d)', d.get('seven_day_opus'))
print()
"
}
