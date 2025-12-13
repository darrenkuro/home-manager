# --- Dependency check
REQUIRED_TOOLS=(fd fzf tr open)
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
  unset REQUIRED_TOOLS _missing_tools
  return 1 2>/dev/null || exit 1
fi

# --- Source
function search() {
  fd "$@" | fzf -0 | tr -d "\n" | xargs -0 open
}
