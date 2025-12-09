{
  pkgs,
  inputs,
  ...
}:
{
  home.packages = [
    pkgs.git
    pkgs.gh
    inputs.darren-nix-pkgs.packages.${pkgs.system}.git-init
  ];
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

  programs.zsh.shellAliases = {
    hmgit = "hx $HM/modules/apps/git.nix";

    gi = "git-init";
    gpa = "git add -A && git commit -m \"Update\" && git push";
    gm = "git commit -m";
    gma = "git add -A && git commit -m";
    gch = "git checkout";
    gs = "git status";
    gp = "git push";
    ga = "git add -A";
    gpl = "git push --force-with-lease";
    gchp = "gh pr checkout";
  };
}
