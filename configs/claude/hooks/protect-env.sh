#!/usr/bin/env bash
# PreToolUse hook: block access to .env files
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty')

# Pattern: .env, .env.local, .env.production, etc.
is_env_file() {
  local name
  name=$(basename "$1")
  [[ "$name" == .env.example ]] && return 1
  [[ "$name" == .env || "$name" == .env.* ]]
}

case "$TOOL" in
  Read|Edit|Write|MultiEdit)
    FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')
    if [[ -n "$FILE_PATH" ]] && is_env_file "$FILE_PATH"; then
      echo "Blocked: $TOOL on env file '$FILE_PATH'. Environment files contain secrets." >&2
      exit 2
    fi
    ;;
  Bash)
    CMD=$(echo "$TOOL_INPUT" | jq -r '.command // empty')
    # Check for direct .env file access patterns in shell commands
    if echo "$CMD" | grep -qE '(^|[\s;|&])cat\s+.*\.env($|\s|\.)|\.env($|\s|\.).*<|>\s*\.env($|\s|\.)|source\s+.*\.env($|\s|\.)'; then
      echo "Blocked: Bash command appears to access .env file. Environment files contain secrets." >&2
      exit 2
    fi
    ;;
esac

exit 0
