INSTALL_TAG=(MAC FT)
REQUIRED_TOOLS=()
_check_preamble || return 0

# Remove regenerable caches and stray dotfiles that tools scatter in $HOME.
# Uses /bin/rm (not `rm`) — on mac, `rm` is aliased to trash.
clean() {
  # Caches (safe, all regenerate)
  /bin/rm -rf "$HOME/.cache" "$HOME/.npm" "$HOME/.matplotlib"
  # Shell artifacts
  /bin/rm -rf "$HOME/.zcompdump" "$HOME/.lesshst"
  # .NET (not in use, regenerates on dotnet run)
  /bin/rm -rf "$HOME/.aspnet" "$HOME/.dotnet" "$HOME/.nuget" "$HOME/.templateengine"
  # Docker (redundant, DOCKER_CONFIG already points to $XDG_CONFIG_HOME/docker)
  /bin/rm -rf "$HOME/.docker"
  # macOS junk
  /bin/rm -f "$HOME/.DS_Store"
  echo "clean: done"
}
