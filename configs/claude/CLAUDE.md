# Global CLAUDE.md

This file: `~/.config/home-manager/configs/claude/CLAUDE.md` (edit, then `re` to deploy)

## Environment

**Package manager**: pnpm (not npm)

**Tool installation**: Never install tools without permission. Use `nix-shell -p <pkg>` or `nix run nixpkgs#<pkg>` for one-off needs.

**Python**: System Python is Nix-managed. Always use `python3 -m venv /tmp/<name>_env`.

**Apple code signing**: Always use real identity, never ad-hoc.
- `codesign -fs "Apple Development: odon5ht@gmail.com (497TM5HK44)"`

**Git**: Global gitignore at `~/.config/git/ignore` covers common patterns. Don't create per-repo `.gitignore` unless project-specific ignores are needed.

**Skills**: Live in `~/Documents/dev/claude-config`. Edit there, commit/push, then `nix flake update claude-config && re` in hm.

**hm** (home-manager): `~/.config/home-manager` — when editing, load its CLAUDE.md first (has commit-after-change rule).

## Behavior

### Project Context
- When entering a repo, check for CLAUDE.md (or `.claude/CLAUDE.md`) first — it contains project-specific instructions
- When editing files in a repo that isn't cwd, load that repo's CLAUDE.md first

### Project-Local Files
Keep plans, tasks, lessons **local to the project** in `.claude/`:
- `.claude/lessons.md` — learnings
- `.claude/todo.md` — task list
- `.claude/architecture-*.md` — plans
- `.claude/settings.local.json` — local settings (if needed)

Use global `~/.config/claude/` only when not in a project context.

### Core Principles
- **Simplicity**: Minimal code, minimal changes
- **No laziness**: Find root causes, no temporary fixes
- **Research before guessing**: Verify uncertain claims online

### Workflow
- **Plan first**: Enter plan mode for non-trivial tasks (3+ steps)
- **Use subagents**: Offload research/exploration to keep context clean
- **Self-improve**: After corrections, update `.claude/lessons.md`
- **Verify before done**: Prove it works — run tests, check logs
- **Autonomous**: Fix bugs and failing CI without hand-holding

### Process Management
Verify processes are killed before restarting. `kill` may not kill child processes — check with `ps aux | grep <pattern>`.

### Refactoring
Make ALL changes in a single atomic pass — move files, update imports, verify compilation before reporting done.

### Pull Requests
- Read repo README and `.github/` for PR templates
- Show full PR title, body, and diff to user before pushing
- Never push without explicit approval

### New Project Init
- Create in `~/Documents/dev/`
- `git init && gh repo create --private`
- Add LICENSE (MIT, "Darren Kuro") and README (use `/readme-style`)

### Docker
Create .dockerignore, use pnpm hoisted layout, test `docker build` before reporting done.
