# Project Initialization (Shared)

These steps apply to ALL new projects regardless of language. Language-specific skills reference this file for the shared setup.

## Directory

Create all projects in `$DEV` (defaults to `~/Documents/dev/`).

## Git & GitHub

1. `git init`
2. `gh repo create <name> --public --source .` (or `--private` if specified)
3. Set remote: `git remote add origin <url>` (if not done by gh)

## LICENSE

MIT License. Generate with:
- Year: output of `date +%Y`
- Copyright holder: "Darren Kuro"

## README

Use the `/readme-style` skill for structure and formatting.

For personal-use projects (Obsidian plugins, private tools), add near the top:

```markdown
> **Note:** This project is built for personal use.
```

## .gitignore

A global gitignore is configured via home-manager covering common patterns (node_modules, dist, build, __pycache__, target/, .DS_Store, editor configs, etc.).

Only create a per-repo `.gitignore` if the project has **repo-specific** ignores not covered by the global config (e.g., generated files, platform-specific build artifacts).

## CI

All projects use GitHub Actions. Workflow file: `.github/workflows/ci.yml`.

## Repo Audit

After initial commit and push, run `/gh-repo-style` to verify:
- README.md exists and follows style
- LICENSE has no placeholders
- .gitignore has no redundancy with global gitignore
- GitHub description and topics are set
