#!/bin/bash
# ClawdOnDesk PermissionRequest notification hook
# Fires when Claude Code is waiting for user permission in the terminal.
# Writes request info to IPC file so the desktop pet shows an alert bubble.

set -euo pipefail

IPC_DIR="$HOME/.claude/clawdondesk"
PENDING_FILE="$IPC_DIR/pending_permission.json"

# Ensure IPC directory exists
mkdir -p "$IPC_DIR"

# Read hook input from stdin
INPUT=$(cat)

# Extract tool info
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)

# Build a human-readable description
case "$TOOL_NAME" in
  Bash|bash)
    DESCRIPTION=$(echo "$TOOL_INPUT" | jq -r '.command // "" | .[0:200]' 2>/dev/null)
    ;;
  Write|Edit)
    DESCRIPTION=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""' 2>/dev/null)
    ;;
  *)
    DESCRIPTION=$(echo "$TOOL_INPUT" | jq -r 'to_entries | map(.key + "=" + (.value | tostring | .[0:50])) | join(", ") | .[0:200]' 2>/dev/null)
    ;;
esac

# Generate a unique request ID
REQUEST_ID="$(date +%s)-$$"

# Write the pending permission request
cat > "$PENDING_FILE" <<EOF
{
  "id": "$REQUEST_ID",
  "sessionId": "$SESSION_ID",
  "tool": "$TOOL_NAME",
  "description": $(echo "$DESCRIPTION" | jq -Rs .),
  "timestamp": $(date +%s)
}
EOF

# PermissionRequest hooks are notification-only — exit 0
exit 0
