---
name: rust-project
description: Scaffold and develop Rust projects (libraries, CLI tools, applications, workspaces). Use when the user asks to create a new Rust project, Cargo workspace, or set up a Rust codebase with clippy, rustfmt, and standard tooling.
---

# Rust Project Development

Read `../project-init/common.md` for shared initialization steps (git, LICENSE, README, repo audit) before proceeding with language-specific setup.

## Scaffold

Two project layouts are supported.

### Single Crate

```
project-name/
├── src/
│   ├── main.rs           # Binary (or lib.rs for library)
│   └── lib.rs            # Optional library root
├── Cargo.toml
└── .github/
    └── workflows/
        └── ci.yml
```

### Workspace

```
project-name/
├── crates/
│   ├── core/
│   │   ├── src/
│   │   │   └── lib.rs
│   │   └── Cargo.toml
│   └── cli/
│       ├── src/
│       │   └── main.rs
│       └── Cargo.toml
├── Cargo.toml              # Workspace root
└── .github/
    └── workflows/
        └── ci.yml
```

After scaffolding, `cargo build` and `cargo test` must succeed.

## Naming

- Crate name: `kebab-case` (Cargo convention)
- Functions/variables: `snake_case`
- Types/Traits: `PascalCase`
- Constants: `SCREAMING_SNAKE_CASE`
- Modules: `snake_case`

## Key Decisions

- **Edition 2024**: Latest Rust edition
- **Clippy lints in Cargo.toml**: Configure workspace-level lints — no per-file `#![allow(...)]` attributes
- **Target stable**: No nightly features required
- **Error handling**: `thiserror` for library error types, `anyhow` for application-level errors
- **rustfmt**: Default formatting (no custom config needed)

## Versioning

Tags use `v` prefix: `v1.0.0` (Rust ecosystem convention).

```bash
git tag v1.0.0
git push --tags
```

## Clippy Lints

All projects configure pedantic clippy lints in `Cargo.toml` rather than using per-file attributes. This catches more issues and keeps the source clean. For workspaces, define lints once at the workspace level and inherit in member crates.

```toml
[lints.clippy]
pedantic = { level = "warn", priority = -1 }
nursery = { level = "warn", priority = -1 }
unwrap_used = "warn"
expect_used = "warn"

[lints.rust]
unsafe_code = "deny"
```

Suppress specific lints only at the call site with `#[allow(...)]` when justified.

## Build & Tooling Reference

For exact file contents (Cargo.toml templates, CI workflow), read `references/setup.md`.
