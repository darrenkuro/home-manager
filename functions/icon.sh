# Disabled: requires ImageMagick (magick) which is not in the nix package list
INSTALL_TAG=()

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
REQUIRED_TOOLS=(iconutil magick)
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

unset REQUIRED_TOOLS _missing_tools _SCRIPT_NAME INSTALL_TAG install

# --- Source

# Apply an ImageMagick -modulate transformation to every size of an ICNS image.
#   $1 - path to the ICNS to transform
#   $2 - argument for the ImageMagick -modulate flag
function modulate_icns {
  local icns_path="$1"
  local modulate_arg="$2"
  local filename icon_name iconset_path out_path

  filename=$(basename "$icns_path")
  icon_name="${filename%.*}"
  iconset_path="$icon_name.iconset"
  out_path="$icon_name-$modulate_arg.icns"

  iconutil --convert iconset --output "$iconset_path" "$icns_path"
  find "$iconset_path" -type f -exec magick '{}' -modulate "$modulate_arg" '{}' \;
  iconutil --convert icns --output "$out_path" "$iconset_path"
  rm -r "$iconset_path"
}

# Invert (negate) the RGB channels of every size in an ICNS image.
#   $1 - path to the ICNS to negate
function negate_icns {
  local icns_path="$1"
  local filename icon_name iconset_path out_path

  filename=$(basename "$icns_path")
  icon_name="${filename%.*}"
  iconset_path="$icon_name.iconset"
  out_path="$icon_name-negate.icns"

  iconutil --convert iconset --output "$iconset_path" "$icns_path"
  find "$iconset_path" -type f -exec magick '{}' -channel RGB -negate '{}' \;
  iconutil --convert icns --output "$out_path" "$iconset_path"
  rm -r "$iconset_path"
}
