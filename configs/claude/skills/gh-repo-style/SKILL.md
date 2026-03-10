---
name: gh-repo-style
description: Audits, reviews, or checks a GitHub repo for hygiene. Ensures required files exist (README.md, LICENSE), LICENSE has no placeholders, repo .gitignore has no redundancy with global gitignore, .npmrc has no unnecessary settings (e.g. shamefully-hoist in non-Docker projects), and GitHub metadata (description, topics) is set.
---

# GitHub Repo Style Audit

Audit a repo for hygiene and completeness. Run checks below and report findings as a checklist.

## Checks

### 1. Required Files

- `README.md` must exist and comply with `/readme-style`. Load and apply that skill to audit/fix it.
- `LICENSE` must exist.

### 2. LICENSE Validation

LICENSE must not contain unfilled placeholders. Flag any of:
- `[year]`, `[fullname]`, `[full name]`, `[name]`
- `{{YEAR}}`, `{{NAME}}`, `{{AUTHOR}}`
- The literal strings `<year>` or `<name>`

The correct values are: year from `date +%Y`, copyright holder "Darren Kuro".

### 3. Gitignore Redundancy

Compare the repo's `.gitignore` against the global gitignore patterns (managed by home-manager in `git.nix`). The global gitignore already covers:

```
# Env
.env, .env.*, !.env.example

# macOS
.DS_Store, Icon?, ._, .AppleDouble, .LSOverride, .Spotlight-V100, .Trashes

# Editors / IDEs
.idea/*, !.idea/codeStyles/, !.idea/runConfigurations/
.vscode/*, !.vscode/launch.json, !.vscode/tasks.json, !.vscode/settings.json

# Backup files
*.bak, *.swp, *.swo, *~

# Obsidian
.obsidian/workspace

# Claude Code
**/.claude/settings.local.json

# GitHub
.github/*, !.github/workflows/, !.github/ISSUE_TEMPLATE/, !.github/PULL_REQUEST_TEMPLATE.md

# Node
node_modules/, dist/, build/, *.log

# Python
__pycache__/, *.py[cod], *.egg-info/, .venv/

# Rust
target/

# Nix
result/

# C / C++
*.o, *.d, *.a, *.so, *.out
```

Rules:
- If repo `.gitignore` is identical to or a subset of the global → **delete it**
- If repo `.gitignore` has lines already in the global → **remove those lines**
- Only keep lines that are project-specific and not in the global

### 4. Makefile Compliance (if present)

If a `Makefile` exists in the repo root, audit it against the `/makefile-c` skill style. Load that skill and check for:
- Tab-aligned `:=` assignments with comment section headers
- Standard sections: Project Metadata, Directories, Files, Toolchain & Flags, Build Settings, Colors & Format, Rules & Targets
- `PAD`/`PAD2` for aligned output
- `DEBUG=1` flag support
- `-MMD -MP` for dependency tracking
- Colorized `log`/`logok` output macros
- `.DELETE_ON_ERROR` and `-include $(OBJ:.o=.d)`
- `.PHONY` declarations for all non-file targets

If non-compliant, offer to regenerate using `/makefile-c`.

### 5. .npmrc Audit (if present)

If `.npmrc` exists, check whether its contents are actually needed for this project. The most common unnecessary setting is `shamefully-hoist=true`, which flattens pnpm's strict `node_modules` layout.

**When `shamefully-hoist=true` IS needed:**
- Docker-based projects (symlinks break in container builds)
- Obsidian plugins (esbuild needs flat resolution to bundle `obsidian` peer dep)
- Projects with dependencies that don't declare their own deps properly (check for known offenders)

**When it is NOT needed:**
- Standalone libraries/packages
- CLI tools
- Anything without Docker or bundler-specific constraints

To determine: check for `Dockerfile`, `docker-compose.yml`, `esbuild.config.*` with obsidian imports, or similar indicators. If none are found and `.npmrc` only contains `shamefully-hoist=true`, **delete it** — pnpm's strict default is preferred because it catches undeclared dependency usage at dev time.

If `.npmrc` has other settings beyond `shamefully-hoist`, only remove the `shamefully-hoist` line and keep the rest.

### 6. GitHub Metadata

Check via `gh repo view` (or the repo's GitHub page):
- **Description** must be set (not empty)
- **Topics** should have at least one tag

If missing, suggest values based on the repo content and offer to set them:
```bash
gh repo edit --description "..."
gh repo edit --add-topic "topic1" --add-topic "topic2"
```

### 7. Language/Project-Type Compliance

Identify the repo's language or project type from its files, then load the corresponding skill to verify tooling and structure match the standard:

| Indicator | Skill |
|---|---|
| `package.json` with `publishConfig` or `@darrenkuro/` scope | `/npm-package` |
| `Package.swift` or `project.yml` (XcodeGen) | `/swift-project` |
| `Cargo.toml` | `/rust-project` |
| `manifest.json` with Obsidian `minAppVersion` | `/obsidian-plugin` |
| `Makefile` with C/C++ targets | `/makefile-c` |

Check the loaded skill's scaffold structure, required config files, and key conventions against what the repo actually has. Flag deviations (missing CI workflow, wrong tsconfig settings, missing clippy lints, etc.) and offer to fix.

If no skill matches, skip this check.

## Output Format

Report as a checklist:
```
- [x] README.md exists and complies with /readme-style
- [ ] LICENSE has placeholder: [year]
- [x] .gitignore — 12/15 lines redundant with global, 3 project-specific
- [x] Makefile complies with /makefile-c (or: no Makefile present)
- [ ] .npmrc has unnecessary shamefully-hoist=true (no Docker/esbuild found)
- [ ] GitHub description missing
- [x] npm-package compliance (or: no matching project skill)
```

Then offer to fix all failing checks.
