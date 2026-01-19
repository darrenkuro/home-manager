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
REQUIRED_TOOLS=(make)
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
function make-init() {
  local tmpl_dir="$HM/templates"
  local tmpl_file="$tmpl_dir/Makefile"
  local target_file="./Makefile"
  local repo_name="$(basename "$(pwd)")"

  if [[ ! -f "$tmpl_file" ]]; then
    echo "❌ Template Makefile not found at: $tmpl_file" >&2
    return 1
  fi

  if [[ -f "$target_file" ]]; then
    echo "⚠️ Makefile already exists in this directory. Aborting." >&2
    return 1
  fi

  cp "$tmpl_file" "$target_file"

  # Replace placeholders, with portable version for both gnu and bsd sed
  sed -i'' -e 's/{{REPO_NAME}}/$repo_name/g' "$target_file" 2> /dev/null || true

}
