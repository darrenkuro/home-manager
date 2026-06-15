{...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [
      "~/.config/colima/ssh_config"
    ];
    settings = {
      "hetzner" = {
        HostName = "77.42.93.119";
        User = "deploy";
      };
    };
  };
}
