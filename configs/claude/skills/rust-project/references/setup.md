# Rust Project — Build & Tooling Reference

## Cargo.toml (Single Binary)

```toml
[package]
name = "<project-name>"
version = "0.1.0"
edition = "2024"
license = "MIT"
description = "<one-line description>"

[dependencies]
anyhow = "1"

[dev-dependencies]

[lints.clippy]
pedantic = { level = "warn", priority = -1 }
nursery = { level = "warn", priority = -1 }
unwrap_used = "warn"
expect_used = "warn"

[lints.rust]
unsafe_code = "deny"
```

## Cargo.toml (Single Library)

```toml
[package]
name = "<crate-name>"
version = "0.1.0"
edition = "2024"
license = "MIT"
description = "<one-line description>"

[lib]
name = "<crate_name>"

[dependencies]
thiserror = "2"

[dev-dependencies]

[lints.clippy]
pedantic = { level = "warn", priority = -1 }
nursery = { level = "warn", priority = -1 }
unwrap_used = "warn"
expect_used = "warn"

[lints.rust]
unsafe_code = "deny"
```

## Cargo.toml (Workspace Root)

```toml
[workspace]
members = ["crates/*"]
resolver = "2"

[workspace.package]
version = "0.1.0"
edition = "2024"
license = "MIT"

[workspace.lints.clippy]
pedantic = { level = "warn", priority = -1 }
nursery = { level = "warn", priority = -1 }
unwrap_used = "warn"
expect_used = "warn"

[workspace.lints.rust]
unsafe_code = "deny"

[workspace.dependencies]
# Shared dependencies — member crates reference these with `.workspace = true`
```

## Cargo.toml (Workspace Member)

```toml
[package]
name = "<crate-name>"
version.workspace = true
edition.workspace = true
license.workspace = true

[lints]
workspace = true

[dependencies]
# Crate-specific dependencies
```

## .github/workflows/ci.yml

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  CARGO_TERM_COLOR: always

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy, rustfmt
      - uses: Swatinem/rust-cache@v2
      - name: Format
        run: cargo fmt --check
      - name: Clippy
        run: cargo clippy -- -D warnings
      - name: Test
        run: cargo test
      - name: Build
        run: cargo build
```

## Starter Files

### src/main.rs (Binary)

```rust
fn main() {
    println!("Hello, world!");
}
```

### src/lib.rs (Library)

```rust
//! <crate-name> — <one-line description>
```
