INSTALL_TAG=(MAC)

# --- Installation check
install=false
for tag in "${INSTALL_TAG[@]}"; do
  if [ "$tag" = "$HM_TAG" ]; then
    install=true
    break
  fi
done

$install || {
  unset INSTALL_TAG install
  return 0 2>/dev/null || exit 0 # Context-aware exit
}

# --- Dependency check
REQUIRED_TOOLS=(brew)
_missing_tools=()

# Determine script name (works in both bash and zsh)
_SCRIPT_NAME=${BASH_SOURCE[0]:-${(%):-%N}}
_SCRIPT_NAME=${_SCRIPT_NAME##*/}

for cmd in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    _missing_tools+=("$cmd")
  fi
done

if [ ${#_missing_tools[@]} -gt 0 ]; then
  printf '⚠️ Skipping sourcing of %s — missing required tools: %s\n' \
    "$_SCRIPT_NAME" "${_missing_tools[*]}" >&2
  unset REQUIRED_TOOLS _missing_tools _SCRIPT_NAME
  return 1 2>/dev/null || exit 1
fi

unset REQUIRED_TOOLS _missing_tools _SCRIPT_NAME

# --- Source
function tidy() {
  # Colors and formatting
  local CYAN='\033[0;36m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local DIM='\033[2m'
  local RESET='\033[0m'
  local BOLD='\033[1m'

  # Output helpers
  _header() { printf '\n%b━━━%b %b%s%b\n' "$CYAN" "$RESET" "$BOLD" "$1" "$RESET"; }
  _task() { printf '  %b○%b %s' "$DIM" "$RESET" "$1"; }
  _done() { printf '\r  %b●%b %s\n' "$GREEN" "$RESET" "$1"; }
  _skip() { printf '\r  %b○%b %s %b(skipped)%b\n' "$YELLOW" "$RESET" "$1" "$DIM" "$RESET"; }
  _item() { printf '    %b→%b %s\n' "$DIM" "$RESET" "$1"; }

  local dry_run=false
  [[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]] && dry_run=true

  # ─────────────────────────────────────────────────────────────────────────────
  # 1. Clear caches
  # ─────────────────────────────────────────────────────────────────────────────
  _header "Clearing caches"

  local cache_dirs=(
    "$HOME/Library/Caches"
    "$HOME/.cache"
    "$HOME/.npm/_cacache"
  )

  local total_freed=0
  local size
  for dir in "${cache_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      size=$(du -sk "$dir" 2>/dev/null | cut -f1)
      _task "$dir"
      if $dry_run; then
        _item "would clear ~$((size / 1024))MB"
      else
        rm -rf "${dir:?}"/* 2>/dev/null
        total_freed=$((total_freed + size))
        _done "$dir (${DIM}~$((size / 1024))MB${RESET})"
      fi
    fi
  done

  # Clear Xcode derived data if present
  local xcode_derived="$HOME/Library/Developer/Xcode/DerivedData"
  if [[ -d "$xcode_derived" ]]; then
    size=$(du -sk "$xcode_derived" 2>/dev/null | cut -f1)
    _task "Xcode DerivedData"
    if $dry_run; then
      _item "would clear ~$((size / 1024))MB"
    else
      rm -rf "${xcode_derived:?}"/* 2>/dev/null
      total_freed=$((total_freed + size))
      _done "Xcode DerivedData (${DIM}~$((size / 1024))MB${RESET})"
    fi
  fi

  printf '  %bTotal freed: ~%dMB%b\n' "$DIM" "$((total_freed / 1024))" "$RESET"

  # ─────────────────────────────────────────────────────────────────────────────
  # 2. Hide special folders in user spaces
  # ─────────────────────────────────────────────────────────────────────────────
  _header "Hiding special folders"

  local hide_patterns=(
    "_archive"
    "_processing"
    "_old"
    "_backup"
    "_temp"
    "_wip"
  )

  local hidden_count=0
  local flags
  for pattern in "${hide_patterns[@]}"; do
    # Search in common user directories
    while IFS= read -r -d '' folder; do
      # Check if already hidden using stat
      flags=$(stat -f "%Xf" "$folder" 2>/dev/null)
      if [[ $((flags & 0x8000)) -eq 0 ]]; then
        _task "Hiding $folder"
        if $dry_run; then
          _item "would hide"
        else
          chflags hidden "$folder" 2>/dev/null && {
            _done "Hidden: $folder"
            ((hidden_count++))
          }
        fi
      fi
    done < <(find "$HOME" -maxdepth 4 -type d -name "$pattern" -print0 2>/dev/null)
  done

  if [[ $hidden_count -eq 0 ]]; then
    printf '  %bNo new folders to hide%b\n' "$DIM" "$RESET"
  else
    printf '  %bHidden %d folders%b\n' "$DIM" "$hidden_count" "$RESET"
  fi

  # ─────────────────────────────────────────────────────────────────────────────
  # 3. Homebrew update
  # ─────────────────────────────────────────────────────────────────────────────
  _header "Updating Homebrew"

  if $dry_run; then
    _item "would run: brew update && brew upgrade && brew cleanup"
  else
    _task "Updating formulae..."
    brew update --quiet && _done "Formulae updated"

    _task "Upgrading packages..."
    local outdated
    outdated=$(brew outdated --quiet)
    if [[ -n "$outdated" ]]; then
      brew upgrade --quiet
      _done "Packages upgraded"
      printf '  %bUpgraded:%b\n' "$DIM" "$RESET"
      echo "$outdated" | while read -r pkg; do
        _item "$pkg"
      done
    else
      _skip "All packages up to date"
    fi

    _task "Cleaning up..."
    brew cleanup --quiet && _done "Cleanup complete"
  fi

  # ─────────────────────────────────────────────────────────────────────────────
  # Summary
  # ─────────────────────────────────────────────────────────────────────────────
  printf '\n%b✓%b %bTidy complete%b\n\n' "$GREEN" "$RESET" "$BOLD" "$RESET"
}
