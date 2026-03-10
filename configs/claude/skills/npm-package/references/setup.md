# npm Package — Build & Tooling Reference

## package.json

```json
{
  "name": "@darrenkuro/<package-name>",
  "version": "0.1.0",
  "description": "<one-line description>",
  "type": "module",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js"
    }
  },
  "files": ["dist"],
  "scripts": {
    "build": "tsc",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "biome check .",
    "lint:fix": "biome check --write .",
    "format": "biome format --write .",
    "prepublishOnly": "pnpm run build"
  },
  "keywords": [],
  "author": "Darren Kuro",
  "license": "MIT",
  "engines": {
    "node": ">= 22"
  },
  "publishConfig": {
    "access": "public",
    "provenance": true
  },
  "devDependencies": {
    "@biomejs/biome": "^1.9.0",
    "@changesets/cli": "^2.27.0",
    "typescript": "^5.7.0",
    "vitest": "^3.0.0"
  },
  "dependencies": {
    "neverthrow": "^8.2.0"
  }
}
```

Adjust `dependencies` as needed — `neverthrow` is included by default per coding standards. Remove if the package has no error-returning functions.

## tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "isolatedModules": true,
    "noUncheckedIndexedAccess": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "exactOptionalPropertyTypes": true
  },
  "include": ["src"],
  "exclude": ["src/__tests__"]
}
```

## vitest.config.ts

```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
  },
});
```

## biome.json

```json
{
  "$schema": "https://biomejs.dev/schemas/1.9.0/schema.json",
  "organizeImports": {
    "enabled": true
  },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true,
      "correctness": {
        "noUnusedImports": "error",
        "noUnusedVariables": "error"
      }
    }
  },
  "formatter": {
    "indentStyle": "space",
    "indentWidth": 2
  },
  "files": {
    "ignore": ["dist/", "node_modules/"]
  }
}
```

## .changeset/config.json

Created automatically by `pnpm changeset init`. Verify it matches:

```json
{
  "$schema": "https://unpkg.com/@changesets/config@3.0.0/schema.json",
  "changelog": "@changesets/cli/changelog",
  "commit": false,
  "fixed": [],
  "linked": [],
  "access": "public",
  "baseBranch": "main",
  "updateInternalDependencies": "patch",
  "ignore": []
}
```

## .github/workflows/ci.yml

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm run typecheck
      - run: pnpm run lint
      - run: pnpm run test
```

## .github/workflows/release.yml

```yaml
name: Release

on:
  push:
    branches: [main]

concurrency: ${{ github.workflow }}-${{ github.ref }}

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm
          registry-url: "https://registry.npmjs.org"
      - run: pnpm install --frozen-lockfile
      - run: pnpm run build
      - name: Create Release PR or Publish
        uses: changesets/action@v1
        with:
          publish: pnpm changeset publish
          title: "chore: version packages"
          commit: "chore: version packages"
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
          NPM_CONFIG_PROVENANCE: true
```

The `id-token: write` permission is required for npm provenance. The workflow either opens a version PR (when changesets are pending) or publishes (when the version PR is merged).

## src/index.ts (starter)

```typescript
// Public API — re-export from internal modules
```

## src/__tests__/index.test.ts (starter)

```typescript
import { describe, it, expect } from "vitest";

describe("<package-name>", () => {
  it("works", () => {
    expect(true).toBe(true);
  });
});
```
