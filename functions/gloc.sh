INSTALL_TAG=(MAC FT)

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
  return 0 2> /dev/null || exit 0 # Context-aware exit
}

# --- Dependency check
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]:-$0}")"
REQUIRED_TOOLS=(git tokei)
_missing_tools=()

for cmd in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$cmd" > /dev/null 2>&1; then
    _missing_tools+=("$cmd")
  fi
done

if [ ${#_missing_tools[@]} -gt 0 ]; then
  printf '⚠️ Skipping sourcing of %s — missing required tools: %s\n' \
    "$_SCRIPT_NAME" "${_missing_tools[*]}" >&2
  unset REQUIRED_TOOLS _missing_tools _SCRIPT_NAME
  return 1 2> /dev/null || exit 1
fi

unset REQUIRED_TOOLS _missing_tools _SCRIPT_NAME

# --- Source

function normalize_repo_url() {
  local input="$1"
  input="${input#"${input%%[![:space:]]*}"}" # trim leading space
  input="${input%"${input##*[![:space:]]}"}" # trim trailing space

  if [[ "$input" == https://github.com/* || "$input" == git@github.com:* ]]; then
    echo "$input"
  else
    input="${input#/}"    # trim leading slash
    input="${input%.git}" # trim .git suffix
    echo "https://github.com/$input"
  fi
}

function gloc() {
  local old_opts
  old_opts=$(set +o)
  set -uo pipefail
  trap 'eval "$old_opts"' RETURN

  if [[ $# -lt 1 ]]; then
    echo "Usage: gloc <repo_url|user/repo>" >&2
    return 1
  fi

  local input="$1"
  local repo_url
  repo_url="$(normalize_repo_url "$input")"

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap '/bin/rm -rf "$tmp_dir"; eval "$old_opts"' RETURN

  echo "📥 Cloning ${repo_url}..."
  if ! git clone --depth 1 "$repo_url" "$tmp_dir" > /dev/null 2>&1; then
    echo "❌ git clone failed for $repo_url" >&2
    return 1
  fi

  echo "📊 Running tokei..."
  if ! tokei "$tmp_dir"; then
    echo "❌ tokei failed" >&2
    return 1
  fi

  /bin/rm -rf "$tmp_dir"
  echo "🧹 Cleaned up $tmp_dir"
}
