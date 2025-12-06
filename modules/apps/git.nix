 { config, lib, pkgs, ... }: {
	programs.git = {
    enable = true;
    #user.email = if tag == "ft" then "dlu@student.42berlin.de" else "odon5ht@gmail.com";
    settings = {
      user.name = "darrenkuro";
      user.email = "odon5ht@gmail.com";
      core.editor = "hx";
      color.ui = "auto";
      init.defaultBranch = "main";
    };
  };
}
