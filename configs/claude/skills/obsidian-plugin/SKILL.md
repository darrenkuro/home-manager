---
name: obsidian-plugin
description: Scaffold and develop Obsidian plugins. Use when the user asks to create an Obsidian plugin, extension, or vault plugin, develop for Obsidian, set up BRAT-compatible releases, or work on an existing Obsidian plugin project.
---

# Obsidian Plugin Development

## Scaffold

When creating a new Obsidian plugin, generate the following project structure:

```
plugin-name/
├── src/
│   ├── main.ts          # Plugin class (extends Plugin)
│   └── settings.ts      # Settings tab + settings interface
├── styles.css            # Empty placeholder
├── manifest.json
├── versions.json
├── package.json
├── tsconfig.json
├── esbuild.config.mjs
├── version-bump.mjs
├── .npmrc
├── eslint.config.mts
└── .github/
    └── workflows/
        ├── release.yml   # Tag-triggered draft release
        └── lint.yml
```

After scaffolding, run `pnpm install` and verify `pnpm run build` succeeds.

For exact file contents and configurations, read `references/build-setup.md`.

## manifest.json Defaults

- `author`: "Darren Kuro"
- `isDesktopOnly`: false (unless desktop APIs are required)
- `minAppVersion`: "1.5.7"
- `version`: "0.1.0"

## Version Bumping (CRITICAL)

**Before every `git push`, version must be bumped:**

1. Run `pnpm version patch` (or `minor`/`major` as appropriate)
2. This triggers `version-bump.mjs` (via npm `version` lifecycle) which syncs `manifest.json` and `versions.json`
3. Push with tags: `git push && git push --tags`
4. The tag push triggers `.github/workflows/release.yml` → creates draft GitHub release
5. BRAT picks up the new release automatically

Never push without bumping. Never manually edit version numbers — always use `pnpm version`.

## Development Workflow

- **Dev**: `pnpm run dev` — esbuild watch mode, output to project root
- **Build**: `pnpm run build` — typecheck + production bundle
- **Lint**: `pnpm run lint`
- **Test in vault**: Symlink the plugin directory into the vault's `.obsidian/plugins/`:
  ```bash
  ln -s /path/to/plugin-name /path/to/vault/.obsidian/plugins/plugin-name
  ```
  Then reload Obsidian (Cmd+R) or use the "Reload app without saving" command.

## Plugin Code Guidelines

### DOM Safety
- **Never use `innerHTML`** — use `createEl()`, `createDiv()`, `createSpan()`, `empty()` instead
- Use `sanitizeHTMLToDom()` if you must render user HTML

### App Access
- Use `this.app` inside Plugin methods, never the global `app` variable
- Pass `app` explicitly to helper functions/classes that need it

### Lifecycle & Cleanup
- Use `this.registerEvent()` for workspace/vault events — auto-cleaned on unload
- Use `this.registerInterval()` for `window.setInterval` — auto-cleaned on unload
- Use `this.registerDomEvent()` for DOM events — auto-cleaned on unload
- Don't detach leaves in `onunload()` — users may want to keep the layout

### Commands
- Never set default hotkeys in command definitions
- Use `editorCallback` for commands that operate on the editor
- Use `checkCallback` for commands that are conditionally available

### File Operations
- Use `Vault.process()` over `Vault.modify()` for background file edits (avoids race conditions)
- Use `requestUrl()` instead of `fetch()` for mobile compatibility
- Use `normalizePath()` for any user-provided file paths

### UI
- Sentence case for all UI text (buttons, menu items, settings labels)
- Use `getActiveViewOfType(MarkdownView)` not `workspace.activeLeaf`
- Don't store view/leaf references — re-query with `getLeavesOfType()` each time
- Minimize `console.log` — remove debug logging before release

### Linting
- Use `eslint-plugin-obsidianmd` to catch guideline violations automatically
- The scaffold includes this preconfigured in `eslint.config.mts`

## API Reference

When you need specifics about Obsidian's API (Plugin lifecycle, Settings, Commands, Views, Vault, Workspace, Events, Editor extensions, etc.), read `references/api.md`.

## Build & Tooling Reference

When you need exact file contents for build configuration (esbuild, tsconfig, package.json, CI workflows, version-bump script, eslint config), read `references/build-setup.md`.
