{ ... }: {
    programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        includes = [ "~/.config/colima/ssh_config" ];
        settings = {
            "hetzner" = { HostName = "77.42.93.119"; User = "deploy"; };
            # work iMac via Tailscale MagicDNS — only reachable with the tailnet up
            "work" = { HostName = "darrens-imac.tail902a42.ts.net"; User = "darrenlu"; };
        };
    };
}
