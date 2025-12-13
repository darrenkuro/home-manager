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

unset REQUIRED_TOOLS _missing_tools _SCRIPT_NAME

# --- Source

# Apply an ImageMagick -modulate transformation to every size of an ICNS image.
#
#   $1 - path to the ICNS to transform
#   $2 - argument for the ImageMagick `-modulate` flag
#

function modulate_icns()
{
    icns_path="$1"
    modulate_arg="$2"

    # Get the filename, filename before extension
    # https://stackoverflow.com/a/965072/1558022
    filename=$(basename "$icns_path")
    icon_name="${filename%.*}"

    iconset_path="$icon_name.iconset"
    out_path="$icon_name-$modulate_arg.icns"

    # Unpack the ICNS as individual images
    iconutil --convert iconset --output "$iconset_path" "$icns_path"

    # Apply the -modulate transformation to every individual image
    find "$iconset_path" -type f -exec magick '{}' -modulate "$modulate_arg" '{}' \;

    # Join the images back together into a single ICNS file
    iconutil --convert icns --output "$out_path" "$iconset_path"

    # Delete the unpacked folder
    rm -r "$iconset_path"
}


function negate_icns() {
    icns_path="$1"

    filename=$(basename "$icns_path")
    icon_name="${filename%.*}"

    iconset_path="$icon_name.iconset"
    out_path="$icon_name-negate.icns"

    iconutil --convert iconset --output "$iconset_path" "$icns_path"
    find "$iconset_path" -type f -exec magick '{}' -channel RGB -negate '{}' \;
    iconutil --convert icns --output "$out_path" "$iconset_path"
    rm -r "$iconset_path"
}
