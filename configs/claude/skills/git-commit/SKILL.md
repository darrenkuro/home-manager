---
name: git-commit
description: Use when creating git commit messages. Provides conventional commit format with type(scope): subject pattern, type reference table, and examples.
---

# Git Commit Style

## Format

```
<type>(<scope>): <subject>
```

### Types

| Type       | When to use                                    |
| ---------- | ---------------------------------------------- |
| `feat`     | New feature                                    |
| `fix`      | Bug fix                                        |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `chore`    | Build process, tooling, dependency updates     |
| `docs`     | Documentation only                             |
| `test`     | Adding or updating tests                       |
| `style`    | Formatting, whitespace (no logic change)       |
| `perf`     | Performance improvement                        |
| `ci`       | CI/CD configuration                            |

### Rules

- **Subject**: imperative mood, lowercase, no period, max 50 chars
- **Scope**: optional, the module/area affected (e.g., `auth`, `api`, `ui`)
- **Body** (optional): wrap at 72 chars, explain *why* not *what*
- **Footer** (optional): `BREAKING CHANGE:` prefix for breaking changes
- Keep commits atomic — one logical change per commit

### Examples

```
feat(auth): add OAuth2 login flow
fix(api): handle null response from upstream
refactor(ui): extract sidebar into composable component
chore: bump typescript to 5.7
```
