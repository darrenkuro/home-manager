---
name: readme-style
description: Use when creating or updating a README.md for any project. Provides standard structure with centered title, badges, blockquote tagline, and consistent section ordering.
---

# README Style Standard

## Structure (in order)

1. `<h1 align="center">` — centered project name
2. `<p align="center">` — badge row (license, status, and optionally score/date)
3. `>` blockquote — one-line tagline
4. `---`
5. `## Overview` — what it is, 2-3 sentences
6. Domain sections — varies per project (function reference, API, features, etc.)
7. `## Project Structure` — tree view (if non-trivial)
8. `## Branches` — only if multiple meaningful branches exist
9. `## Usage` — install, build, run, code example
10. `---`
11. `<details><summary>Notes</summary>` — optional collapsed section for lessons/notes
12. `---`
13. `## License` — `[MIT](LICENSE) - Darren Kuro`

## Style Rules

- No emoji in headers
- No contact section (GitHub profile handles that)
- Horizontal rules only between major groups, not every section
- Use `<details>` for supplementary content (notes, lessons, advanced config)
- Use tables for reference-style content (functions, CLI flags, env vars)
- Use fenced tree blocks for project structure
