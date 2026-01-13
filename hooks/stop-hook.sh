#!/bin/bash

# Ralph Wiggum AfterAgent Stop Hook
# Prevents session exit when a ralph-loop is active
# Feeds output back as input to continue the loop

set -euo pipefail

# Read hook input from stdin
if ! HOOK_INPUT=$(cat); then
    echo '{"decision": "allow", "systemMessage": "⚠️ Ralph loop: Failed to read input"}'
    exit 0
fi

# Determine project root and state directory
PROJECT_ROOT="${GEMINI_PROJECT_DIR:-.}"
STATE_DIR="$PROJECT_ROOT/.gemini"
RALPH_STATE_FILE="$STATE_DIR/ralph-state.json"
DEBUG_LOG_FILE="$STATE_DIR/ralph-debug.log"

if [[ ! -f "$RALPH_STATE_FILE" ]]; then
  # No active loop - allow exit
  echo '{"decision": "allow", "continue": false}'
  exit 0
fi

# Parse state from JSON
STATE_JSON=$(cat "$RALPH_STATE_FILE")
ITERATION=$(echo "$STATE_JSON" | jq -r '.iteration')
MAX_ITERATIONS=$(echo "$STATE_JSON" | jq -r '.max_iterations')
COMPLETION_PROMISE=$(echo "$STATE_JSON" | jq -r '.completion_promise')
DEBUG_MODE=$(echo "$STATE_JSON" | jq -r '.debug')
PROMPT_TEXT=$(echo "$STATE_JSON" | jq -r '.prompt')

# Logging function
log() {
  if [[ "$DEBUG_MODE" == "true" ]]; then
    # Ensure log directory exists
    mkdir -p "$(dirname "$DEBUG_LOG_FILE")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$DEBUG_LOG_FILE"
  fi
}

log "Stop hook triggered. Iteration: $ITERATION, Max: $MAX_ITERATIONS"

# Helper to output JSON safely
output_json() {
    jq -n -c "$@"
}

# Validate numeric fields
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  log "Error: Invalid iteration number '$ITERATION'. Stopping loop."
  rm "$RALPH_STATE_FILE"
  output_json --arg msg "⚠️ Ralph loop: State file corrupted (iteration)" '{decision: "allow", continue: false, systemMessage: $msg}'
  exit 0
fi

if [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  log "Error: Invalid max_iterations '$MAX_ITERATIONS'. Stopping loop."
  rm "$RALPH_STATE_FILE"
  output_json --arg msg "⚠️ Ralph loop: State file corrupted (max_iterations)" '{decision: "allow", continue: false, systemMessage: $msg}'
  exit 0
fi

# Check if max iterations reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  log "Max iterations reached ($MAX_ITERATIONS). Stopping loop."
  rm "$RALPH_STATE_FILE"
  output_json --arg msg "🛑 Ralph loop: Max iterations ($MAX_ITERATIONS) reached." '{decision: "allow", continue: false, systemMessage: $msg}'
  exit 0
fi

# Get prompt_response from hook input (Gemini specific)
# Use jq safely to extract the field
LAST_OUTPUT=$(echo "$HOOK_INPUT" | jq -r '.prompt_response // empty')

if [[ -z "$LAST_OUTPUT" ]]; then
  log "Warning: No model response found in hook input. Stopping loop."
  output_json --arg msg "⚠️ Ralph loop: No model response found. Stopping." '{decision: "allow", continue: false, systemMessage: $msg}'
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Check for completion promise (only if set)
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  # Extract text from <promise> tags
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^	+|	+$//g; s/	+/ /g' 2>/dev/null || echo "")
  
  if [[ -n "$PROMISE_TEXT" ]]; then
      log "Detected promise tag: '$PROMISE_TEXT'"
  fi

  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    log "Promise matched completion criteria. Stopping loop."
    rm "$RALPH_STATE_FILE"
    output_json --arg msg "✅ Ralph loop: Detected <promise>$COMPLETION_PROMISE</promise>" '{decision: "allow", continue: false, systemMessage: $msg}'
    exit 0
  fi
fi

# Not complete - continue loop with SAME PROMPT
NEXT_ITERATION=$((ITERATION + 1))
log "Continuing loop. Next iteration: $NEXT_ITERATION"

if [[ -z "$PROMPT_TEXT" || "$PROMPT_TEXT" == "null" ]]; then
  log "Error: No prompt text found in state file. Stopping loop."
  rm "$RALPH_STATE_FILE"
  output_json --arg msg "⚠️ Ralph loop: State file corrupted (no prompt). Stopping." '{decision: "allow", continue: false, systemMessage: $msg}'
  exit 0
fi

# Update iteration in state file (JSON)
# We can use node to update the JSON file safely
node -e "
  const fs = require('fs');
  const file = '$RALPH_STATE_FILE';
  const state = JSON.parse(fs.readFileSync(file, 'utf8'));
  state.iteration = $NEXT_ITERATION;
  fs.writeFileSync(file, JSON.stringify(state, null, 2));
"

# Build system message
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="🔄 Ralph iteration $NEXT_ITERATION | To stop: output <promise>$COMPLETION_PROMISE</promise>"
else
  SYSTEM_MSG="🔄 Ralph iteration $NEXT_ITERATION | No completion promise set - loop runs infinitely"
fi

# Construct user-friendly block reason
if [[ $MAX_ITERATIONS -gt 0 ]]; then
  BLOCK_REASON="[Ralph Loop] Iteration $NEXT_ITERATION of $MAX_ITERATIONS..."
else
  BLOCK_REASON="[Ralph Loop] Iteration $NEXT_ITERATION."
fi

log "Feeding prompt back to agent via BLOCK decision."

# We block the agent's attempt to stop.
# 'reason': Sent to Agent (Context) -> Original Prompt
# 'systemMessage': Displayed to User (UI) -> Short Status
# 'hookSpecificOutput': Tells the hook to clear context between iterations.
output_json \
  --arg reason "$PROMPT_TEXT" \
  --arg msg "$BLOCK_REASON" \
  '{
    "decision": "block",
    "reason": $reason,
    "systemMessage": $msg,
    "hookSpecificOutput": {"hookEventName": "AfterAgent", "clearContext": true}
  }'

exit 0
