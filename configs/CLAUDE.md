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
- **Error handling**: Always use `neverthrow` and return `Result`/`Option` types instead of throwing. Only deviate if explicitly told otherwise.
- **Functional style**: Prefer arrow functions (`const foo = () => {}`) over `function` declarations. Only use `function` if explicitly told otherwise.
- **No classes**: Prefer closures and factory functions. Only use classes if explicitly told otherwise.

## Refactoring Guidelines
- When refactoring or reorganizing files, make ALL changes in a single atomic pass — move files, update all imports, and verify compilation before reporting completion. Do not leave partial moves.

## Trading Bot / Polymarket
- When implementing changes to the trading bot codebase, always run the full test suite (`npm test` or equivalent) after every refactoring step and confirm all tests pass before proceeding to the next change.
- When modifying strategy logic or trading parameters, always preserve previously implemented features (profit-taking, hedge logic, partial sells, etc.) in new test runs. Never test a change in isolation that drops prior work.

## Docker / Infrastructure
- For Docker-based projects: always create a .dockerignore excluding node_modules and local build artifacts. Use pnpm's hoisted node_modules layout or shamefully-hoist=true when building Docker images. Test `docker build` before reporting completion.

## Database
- When working with database schemas that import from JSON data, always make columns nullable by default unless the data is guaranteed to be present. Check sample data before adding NOT NULL constraints.

## Process Management
- **Always verify processes are actually killed** before starting new instances. `kill $(cat pidfile)` may not kill the full process tree (e.g., node/tsx spawns child processes). After killing, run `ps aux | grep <process-pattern>` to confirm no orphaned processes remain.
- When restarting a long-running process (bot, server, watcher), kill ALL matching PIDs found via `ps aux`, not just the PID file. Wait and re-check before starting the replacement.
- Use `TaskStop` for background tasks managed by Claude Code, but still verify with `ps aux` afterward.

## Parallel Agents / Batch Work
- When spawning parallel sub-agents for large batch tasks, limit each agent's scope to avoid hitting the 32k output token limit. For PDF-heavy tasks, use smaller batches and fallback reading strategies for large files.

## Fetching Tweets (X.com)
- Use the **FxTwitter API** to load any tweet/X post: `https://api.fxtwitter.com/{username}/status/{tweet_id}`
- No authentication required, returns clean JSON with full text, author info, engagement stats, and media
- Extract the tweet ID from any x.com or twitter.com URL and plug it into the endpoint
- Use WebFetch on the fxtwitter URL to read tweet contents

## New Project Init
When creating a new project with git init, always include these files from the hm templates:
- `.gitignore` — use sections: Env (with .env, .envrc, !examples), macOS, VSCode, JetBrains, Node.js, Backup files
- `LICENSE` — MIT License with "Darren Kuro" as copyright holder
- `README.md` — centered h1, badge row (license, status, size/date), blockquote tagline, horizontal rules between sections
