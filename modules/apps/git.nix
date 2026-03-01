{ pkgs, ... }: {
  home.packages = with pkgs; [ git gh ];

  programs.git = {
    enable = true;
    ignores = [
      # Env
      ".env"
      ".env.*"
      "!.env.example"

      # macOS
      ".DS_Store"
      "Icon?"
      "._*"
      ".AppleDouble"
      ".LSOverride"
      ".Spotlight-V100"
      ".Trashes"

      # Editors / IDEs
      ".idea/*"
      "!.idea/codeStyles/"
      "!.idea/runConfigurations/"
      ".vscode/*"
      "!.vscode/launch.json"
      "!.vscode/tasks.json"
      "!.vscode/settings.json"

      # Backup files
      "*.bak"
      "*.swp"
      "*.swo"
      "*~"

      # Obsidian
      ".obsidian/workspace"

      # Claude Code
      "**/.claude/settings.local.json"

      # GitHub (keep workflows/templates)
      ".github/*"
      "!.github/workflows/"
      "!.github/ISSUE_TEMPLATE/"
      "!.github/PULL_REQUEST_TEMPLATE.md"

      # Node
      "node_modules/"
      "dist/"
      "build/"
      "*.log"

      # Python
      "__pycache__/"
      "*.py[cod]"
      "*.egg-info/"
      ".venv/"

      # Rust
      "target/"

      # Nix
      "result/"

      # C / C++
      "*.o"
      "*.d"
      "*.a"
      "*.so"
      "*.out"
    ];

    settings = {
      user.name = "darrenkuro";
      user.email = "odon5ht@gmail.com";
      user.signingKey = "~/.ssh/id_rsa.pub";
      gpg.format = "ssh";
      commit.gpgsign = "true";
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
