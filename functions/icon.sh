# Disabled: requires ImageMagick (magick) which is not in the nix package list
INSTALL_TAG=()
REQUIRED_TOOLS=(iconutil magick)
_check_preamble || return 0

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
