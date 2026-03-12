# Common preamble for functions/*.sh
#
# Checks INSTALL_TAG against $HM_TAG, then verifies REQUIRED_TOOLS
# are installed. Prints a warning and returns 1 on failure.
# Both arrays are unset after the check regardless of outcome.
#
# Naming: the underscore prefix serves two purposes:
#   1. Visually marks this as infrastructure, not a user-facing function
#   2. Prevents glob conflicts — source.sh sources this file explicitly
#      before iterating functions/*.sh and skips it in the loop
#
# Why not rely on glob sort order? Glob expansion sorts by LC_COLLATE.
# In the C locale, _ (0x5F) sorts before lowercase letters (0x61+).
# But in en_US.UTF-8 and other locales, collation rules may place
# punctuation after letters, breaking the assumed ordering.
# Explicit sourcing in source.sh avoids this locale dependency.
#
# Usage in each function file:
#   INSTALL_TAG=(MAC FT)
#   REQUIRED_TOOLS=(gh git)
#   _check_preamble || return 0
_check_preamble() {
  local _script_name="${BASH_SOURCE[1]:-${(%):-%x}}"
  _script_name="${_script_name##*/}"

  # --- Tag check
  local _matched=false
  local _tag
  for _tag in "${INSTALL_TAG[@]}"; do
    if [ "$_tag" = "$HM_TAG" ]; then
      _matched=true
      break
    fi
  done
  unset INSTALL_TAG

  if ! $_matched; then
    unset REQUIRED_TOOLS
    return 1
  fi

  # --- Dependency check
  local _missing=()
  local _cmd
  for _cmd in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$_cmd" > /dev/null 2>&1; then
      _missing+=("$_cmd")
    fi
  done
  unset REQUIRED_TOOLS

  if [ ${#_missing[@]} -gt 0 ]; then
    printf '⚠️ Skipping sourcing of %s — missing required tools: %s\n' \
      "$_script_name" "${_missing[*]}" >&2
    return 1
  fi

  return 0
}
