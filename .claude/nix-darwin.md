# nix-darwin Best Practices

Guidelines for working with nix-darwin configuration in this repo.

## Key Files

- `darwin.nix` — thin root: homebrew, system.defaults, GUI env, service imports (comment out to disable)
- `modules/services/<name>/darwin.nix` — per-service launchd daemons/agents + BTM stubs
- `lib/launchd-btm.nix` — shared BTM helpers (`mkWrapper`, `mkStubInstall`)
- `flake.nix` — `darwinConfigurations.mac` entry point
- `home.nix` — home-manager config (embedded in darwin via `home-manager.darwinModules`)

## launchd Services

### Daemons vs Agents

- `launchd.daemons.*` — System-level, runs as root, goes to `/Library/LaunchDaemons/`
- `launchd.user.agents.*` — User-level, runs as user, goes to `~/Library/LaunchAgents/`

### nix-darwin Does NOT Wrap Commands

Unlike home-manager's `launchd.agents`, nix-darwin passes `ProgramArguments` directly without `/bin/sh -c` wrapper. This is important for BTM (Login Items) naming.

### Required for User Options

```nix
system.primaryUser = "darrenlu";  # Required for launchd.user.agents, system.defaults.dock, etc.
```

### Example Agent

```nix
launchd.user.agents.my-service = {
  serviceConfig = {
    Label = "com.user.my-service";
    ProgramArguments = [ "/path/to/executable" ];
    RunAtLoad = true;
    KeepAlive = true;
    StandardOutPath = "/path/to/stdout.log";
    StandardErrorPath = "/path/to/stderr.log";
    EnvironmentVariables = {
      HOME = "/Users/darrenlu";
    };
  };
};
```

### BTM Icon Grouping

For agents to show grouped under an app icon in Login Items:

1. Executable must be inside `.app` bundle
2. Plist needs `AssociatedBundleIdentifiers` key (nix-darwin doesn't add this automatically)

## Homebrew Management

```nix
homebrew = {
  enable = true;
  onActivation = {
    cleanup = "zap";      # Remove unlisted packages
    autoUpdate = false;   # Keep false for idempotent rebuilds
    upgrade = false;      # Apps self-update or `brew upgrade` manually (deliberate, see dc0a34a)
  };
  brews = [
    "tmux"
    { name = "some-formula"; args = ["HEAD"]; }
  ];
  casks = [ "visual-studio-code" "obsidian" ];
  masApps = {
    "Xcode" = 497799835;
    "Final Cut Pro" = 424389933;
  };
};
```

**Guideline:** Prefer nixpkgs when available. Use Homebrew mainly for:

- GUI apps (casks) not in nixpkgs
- Formulae needing specific versions (HEAD, etc.)

**PATH Order:** Nix comes before Homebrew:

```
~/.nix-profile/bin           # 1. Nix user packages
/nix/var/nix/profiles/...    # 2. Nix system packages
/opt/homebrew/bin            # 3. Homebrew
```

To use a Homebrew version instead of Nix, use an alias:

```nix
programs.zsh.shellAliases.tmux = "/opt/homebrew/bin/tmux";
```

## system.defaults

Declarative macOS settings:

```nix
system.defaults = {
  dock.show-recents = false;
  finder.FXPreferredViewStyle = "clmv";
  NSGlobalDomain.AppleShowAllExtensions = true;
};
```

**Note:** Not all `defaults write` keys have nix-darwin options. Use activation script for unsupported ones:

```nix
system.activationScripts.postActivation.text = ''
  /usr/bin/defaults write -g NSRecentDocumentsLimit 0
'';
```

## Environment Variables for GUI Apps

```nix
launchd.user.envVariables = {
  CLAUDE_CONFIG_DIR = "/Users/darrenlu/.config/claude";
  XDG_CONFIG_HOME = "/Users/darrenlu/.config";
};
```

These are set in the launchd domain so GUI apps (launched from Dock/Spotlight) inherit them.
