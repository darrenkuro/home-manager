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
REQUIRED_TOOLS=(gh git)
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
  return 1 2> /dev/null || exit 1 # Context-aware exit
fi

unset REQUIRED_TOOLS _missing_tools _SCRIPT_NAME

# --- Source
function git-init() {
  set -uo pipefail

  local dir="${1:-.}"
  local public_flag="${2:-}"
  local visibility="--private"
  [[ "$public_flag" == "--public" ]] && visibility="--public"

  mkdir -p "$dir"
  cd "$dir" || return 1
  local repo_name="$(basename "$(pwd)")"

  if gh repo view "darrenkuro/$repo_name" > /dev/null 2>&1; then
    echo "🚫 Repository darrenkuro/$repo_name already exists on GitHub."
    return 1
  fi

  if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "❌ Already inside a git repository!" >&2
    return 1
  fi

  if find . -type d -name ".git" -mindepth 2 -print -quit | grep -q .; then
    echo "🚫 Found existing Git repos inside subdirectories. Aborting." >&2
    return 1
  fi

  # Generate LICENSE from GitHub API
  gh api /licenses/mit --jq '.body' \
    | sed "s/\[year\]/$(date +%Y)/g; s/\[fullname\]/Darren Kuro/g" > LICENSE

  # Empty README
  touch README.md

  git init
  git add LICENSE README.md
  git commit -m "Initial commit"

  gh repo create "$repo_name" $visibility
  git remote add origin "https://github.com/darrenkuro/$repo_name.git"
  git push -u origin main

  echo "✅ Repo $repo_name initialized and pushed! ($visibility)"
}
