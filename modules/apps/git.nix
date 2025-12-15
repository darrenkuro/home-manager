{
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.git
    pkgs.gh
    #inputs.darren-nix-pkgs.packages.${pkgs.system}.git-init
  ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "darrenkuro";
      user.email = "odon5ht@gmail.com";
      user.signingKey = "~/.ssh/id_rsa";
      gpg.format = "ssh";
      # signing = {
      #   key = "~/.ssh/id_rsa";
      #   format = "ssh";
      #   signByDefault = true;
      # };
      core.editor = "hx";
      color.ui = "auto";
      init.defaultBranch = "main";
    };
  };

  programs.zsh.shellAliases = {
    hmgit = "hx $HM/modules/apps/git.nix";

    gi = "git-init";
    gpa = "git add -A && git commit -m \"Update\" && git push";
    gm = "git commit -m";
    gd = "git diff";
    gma = "git add -A && git commit -m";
    gch = "git checkout";
    gs = "git status";
    gp = "git push";
    ga = "git add -A";
    gpl = "git push --force-with-lease";
    gcl = "git clone";
    gchp = "gh pr checkout";
  };
}
