INSTALL_TAG=(MAC FT)
REQUIRED_TOOLS=(gh git)
_check_preamble || return 0

git-init() {
  local old_opts
  old_opts=$(set +o)
  set -uo pipefail
  trap 'eval "$old_opts"' RETURN

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

  gh repo create "$repo_name" "$visibility"
  git remote add origin "https://github.com/darrenkuro/$repo_name.git"
  git push -u origin main

  echo "✅ Repo $repo_name initialized and pushed! ($visibility)"
}
