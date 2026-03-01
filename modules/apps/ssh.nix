{ ... }: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [
      "~/.config/colima/ssh_config"
      "~/.ssh/config.local" # Untracked — server IPs, etc.
    ];
  };
}
