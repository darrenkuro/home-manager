# User Preferences

## Package Manager
- Use pnpm instead of npm for all package management
- Commands: pnpm install, pnpm add, pnpm run, pnpm dlx

## Abbreviations
- "hm" = home manager, located at ~/.config/home-manager

## Claude Code Config Paths
- Claude config directory: `~/.config/claude/` (or `$CLAUDE_CONFIG_DIR` if set)
- Claude skills location: `~/.config/claude/skills/`
- This CLAUDE.md source: `~/.config/home-manager/configs/CLAUDE.md` (managed by home-manager)
- To edit global Claude settings, edit the source file above then run `re`

## Code Standards
- This is a TypeScript-first codebase. All new code should be written in TypeScript with proper types. Do not use `any` unless absolutely necessary. Co-locate types with their modules unless shared across multiple files.

## Refactoring Guidelines
- When refactoring or reorganizing files, make ALL changes in a single atomic pass — move files, update all imports, and verify compilation before reporting completion. Do not leave partial moves.

## Trading Bot / Polymarket
- When implementing changes to the trading bot codebase, always run the full test suite (`npm test` or equivalent) after every refactoring step and confirm all tests pass before proceeding to the next change.
- When modifying strategy logic or trading parameters, always preserve previously implemented features (profit-taking, hedge logic, partial sells, etc.) in new test runs. Never test a change in isolation that drops prior work.

## Docker / Infrastructure
- For Docker-based projects: always create a .dockerignore excluding node_modules and local build artifacts. Use pnpm's hoisted node_modules layout or shamefully-hoist=true when building Docker images. Test `docker build` before reporting completion.

## Database
- When working with database schemas that import from JSON data, always make columns nullable by default unless the data is guaranteed to be present. Check sample data before adding NOT NULL constraints.

## Parallel Agents / Batch Work
- When spawning parallel sub-agents for large batch tasks, limit each agent's scope to avoid hitting the 32k output token limit. For PDF-heavy tasks, use smaller batches and fallback reading strategies for large files.
