# ChatGPT really seems to believe that sourcing this in .env is very important

if [[ ${HM_TAG-} == "MAC" ]] &&
  ! command -v nix > /dev/null 2>&1 &&
  [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

if [[ ${HM_TAG-} == "FT" ]] &&
  ! command -v nix > /dev/null 2>&1 &&
  [[ -r "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
  source "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi
