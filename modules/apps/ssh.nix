{ ... }: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [
      "~/.config/colima/ssh_config"
    ];
    matchBlocks = {
      "hetzner" = {
        hostname = "77.42.93.119";
        user = "deploy";
      };
    };
  };
}
