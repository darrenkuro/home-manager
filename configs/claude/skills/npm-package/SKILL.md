---
name: npm-package
description: Scaffold and develop npm packages (TypeScript libraries, Node.js modules). Use when the user asks to create a new npm package, TypeScript library, publishable module, or set up a project with Changesets for automated versioning. Also use for existing npm packages that need standardized tooling.
---

# npm Package Development

Load the `/project-init` skill for shared initialization steps (git, LICENSE, README, CI, repo audit) before proceeding with language-specific setup.

## Scaffold

```
package-name/
├── src/
│   ├── index.ts            # Public API exports
│   ├── types.ts            # Shared types (if needed)
│   └── __tests__/
│       └── index.test.ts
├── package.json
├── tsconfig.json
├── vitest.config.ts
├── biome.json
├── .changeset/
│   └── config.json
└── .github/
    └── workflows/
        ├── ci.yml
        └── release.yml
```

After scaffolding:
1. `pnpm install`
2. `pnpm changeset init` (sets up `.changeset/` directory)
3. Verify `pnpm run build` and `pnpm run test` succeed

## Naming

- Package scope: `@darrenkuro/`
- Package name: `kebab-case`
- Code: `camelCase` for functions/variables, `PascalCase` for types

## Key Decisions

- **ESM-only**: `"type": "module"` — no CJS dual builds
- **Node 22+**: Target ES2022, module Node16
- **tsc for build**: Plain TypeScript compilation to `dist/`, generates declaration files
- **Vitest for testing**: Fast, ESM-native, minimal config
- **Biome for lint/format**: Single tool replacing both ESLint and Prettier
- **neverthrow for errors**: Return `Result` types instead of throwing
- **Changesets for versioning**: Automated changelog and version bumps

## Publishing Flow

Automated via GitHub Actions (`release.yml`):

1. Make changes and commit
2. `pnpm changeset` — describe the change, select semver bump type (creates a markdown file in `.changeset/`)
3. Push to main — the release workflow detects pending changesets and opens a "Version Packages" PR that bumps `package.json`, generates `CHANGELOG.md`
4. Merge that PR — the workflow publishes to npm with provenance and creates git tags

Tag format: `v1.0.0` (Changesets handles tag creation automatically).

**Requires**: `NPM_TOKEN` secret set in the GitHub repo settings (Settings > Secrets > Actions).

## Scripts

```json
{
  "build": "tsc",
  "typecheck": "tsc --noEmit",
  "test": "vitest run",
  "test:watch": "vitest",
  "lint": "biome check .",
  "lint:fix": "biome check --write .",
  "format": "biome format --write .",
  "prepublishOnly": "pnpm run build"
}
```

## Code Patterns

- Export only types and functions from `index.ts` (barrel file)
- Use `.js` extensions in import statements (ESM requirement for Node16 module resolution)
- Co-locate tests in `src/__tests__/`
- Use discriminated union error types with neverthrow
- Prefer arrow functions and factory functions over classes

## Build & Tooling Reference

For exact file contents (package.json, tsconfig.json, biome.json, vitest config, changeset config, CI workflow), read `references/setup.md`.
