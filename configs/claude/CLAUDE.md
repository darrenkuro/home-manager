# User Preferences

## Package Manager
- Use pnpm instead of npm for all package management
- Commands: pnpm install, pnpm add, pnpm run, pnpm dlx

## Abbreviations
- "hm" = home manager, located at ~/.config/home-manager

## Claude Code Config Paths
- Claude config directory: `~/.config/claude/` (or `$CLAUDE_CONFIG_DIR` if set)
- Claude skills location: `~/.config/claude/skills/` (symlinked from hm)
- `settings.json`: owned by Claude Code (not hm-managed). Hooks key injected by hm on `re`
- `hooks/`: symlinked from hm (`~/.config/home-manager/configs/claude/hooks/`)
- Plugins: use `/plugin install` directly — settings.json is writable
- This CLAUDE.md source: `~/.config/home-manager/configs/claude/CLAUDE.md` (managed by home-manager)
- To edit global Claude settings, edit the source file above then run `re`

## Code Standards (TypeScript projects)
When working in a TypeScript codebase:
- TypeScript-first with proper types. Do not use `any` unless absolutely necessary. Co-locate types with their modules unless shared across multiple files.
- **Error handling**: Use `neverthrow` and return `Result`/`Option` types instead of throwing. Only deviate if explicitly told otherwise.
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

## Skills
- When creating or updating skills, invoke the `skill-creator` plugin (enabled in settings.json) which provides the full skill creation lifecycle including evals, benchmarking, and description optimization

## New Project Init
When creating a new project with git init, always include these files from the hm templates:
- `.gitignore` — use sections: Env (with .env, .envrc, !examples), macOS, VSCode, JetBrains, Node.js, Backup files
- `LICENSE` — MIT License with "Darren Kuro" as copyright holder
- `README.md` — use the `/readme-style` skill for formatting

## Workflow Orchestration

### 1. Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately - don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes - don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests - then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Task Management

1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `tasks/todo.md`
6. **Capture Lessons**: Update `tasks/lessons.md` after corrections

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.
