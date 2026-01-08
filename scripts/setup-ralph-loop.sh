#!/bin/bash

# Ralph Loop Setup Script
# Creates state file for in-session Ralph loop

set -euo pipefail

# Determine project root and state directory
PROJECT_ROOT="${GEMINI_PROJECT_DIR:-.}"
STATE_DIR="$PROJECT_ROOT/.gemini"
STATE_FILE="$STATE_DIR/ralph-state.json"
DEBUG_LOG="$STATE_DIR/ralph-debug.log"

# Parse arguments
PROMPT_PARTS=()
MAX_ITERATIONS=0
COMPLETION_PROMISE="null"
DEBUG_MODE="false"

# Parse options and positional arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Ralph Loop - Interactive self-referential development loop

USAGE:
  /ralph-loop [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Initial prompt to start the loop (can be multiple words without quotes)

OPTIONS:
  --max-iterations <n>           Maximum iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Promise phrase (USE QUOTES for multi-word)
  --debug                        Enable debug logging to ralph-debug.log
  -h, --help                     Show this help message

DESCRIPTION:
  Starts a Ralph Wiggum loop in your CURRENT session. The stop hook prevents
  exit and feeds your output back as input until completion or iteration limit.

  To signal completion, you must output: <promise>YOUR_PHRASE</promise>

  Use this for:
  - Interactive iteration where you want to see progress
  - Tasks requiring self-correction and refinement
  - Learning how Ralph works

EXAMPLES:
  /ralph-loop Build a todo API --completion-promise 'DONE' --max-iterations 20
  /ralph-loop --max-iterations 10 Fix the auth bug
  /ralph-loop Refactor cache layer  (runs forever)
  /ralph-loop --completion-promise 'TASK COMPLETE' Create a REST API
  /ralph-loop --debug Fix the build

STOPPING:
  Only by reaching --max-iterations or detecting --completion-promise
  No manual stop - Ralph runs infinitely by default!

MONITORING:
  # View state:
  cat .gemini/ralph-state.json
HELP_EOF
      exit 0
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --max-iterations requires a number argument" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "❌ Error: --max-iterations must be a positive integer or 0, got: $2" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --completion-promise requires a text argument" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    --debug)
      DEBUG_MODE="true"
      shift
      ;;
    *)
      # Non-option argument - collect all as prompt parts
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

# Join all prompt parts with spaces
PROMPT="${PROMPT_PARTS[*]}"

# Validate prompt is non-empty
if [[ -z "$PROMPT" ]]; then
  echo "❌ Error: No prompt provided" >&2
  echo "   Ralph needs a task description to work on." >&2
  exit 1
fi

# Create state directory
mkdir -p "$STATE_DIR"

# Initialize debug log if enabled
if [[ "$DEBUG_MODE" == "true" ]]; then
  echo "--- Ralph Debug Log Started $(date) ---" > "$DEBUG_LOG"
  echo "Setup script initialized." >> "$DEBUG_LOG"
  echo "Parameters: Max Iterations=$MAX_ITERATIONS, Promise=$COMPLETION_PROMISE" >> "$DEBUG_LOG"
  echo "Project Root: $PROJECT_ROOT" >> "$DEBUG_LOG"
fi

# Generate JSON state file (using python/node or manual construction if jq not guaranteed, but jq is standard enough in dev envs, or simple printf)
# To be safe and portable without relying on jq in setup, we'll use a python one-liner or just careful string construction since we control inputs.
# Note: completion_promise and prompt need escaping.

# Using a python one-liner for safe JSON generation if python3 is available, else fallback?
# Given we are in a dev environment for an extension, let's assume python3 or node is available.
# Let's use a simple node script since this is a JS/TS ecosystem extension.

node -e "
  const fs = require('fs');
  const state = {
    active: true,
    iteration: 1,
    max_iterations: parseInt('$MAX_ITERATIONS'),
    completion_promise: '$COMPLETION_PROMISE' === 'null' ? null : '$COMPLETION_PROMISE',
    debug: '$DEBUG_MODE' === 'true',
    started_at: new Date().toISOString(),
    prompt: process.argv[1]
  };
  fs.writeFileSync('$STATE_FILE', JSON.stringify(state, null, 2));
" "$PROMPT"

# Output setup message
cat <<EOF
🔄 Ralph loop activated in this session!

Iteration: 1
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
Completion promise: $(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "$COMPLETION_PROMISE (ONLY output when TRUE - do not lie!)"; else echo "none (runs forever)"; fi)

The stop hook is now active. When you try to exit, the SAME PROMPT will be
fed back to you. You'll see your previous work in files, creating a
self-referential loop where you iteratively improve on the same task.

To monitor: cat .gemini/ralph-state.json

⚠️  WARNING: This loop cannot be stopped manually! It will run infinitely
    unless you set --max-iterations or --completion-promise.

🔄
EOF

# Output the initial prompt if provided
if [[ -n "$PROMPT" ]]; then
  echo ""
  echo "$PROMPT"
fi

# Display completion promise requirements if set
if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "CRITICAL - Ralph Loop Completion Promise"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo "To complete this loop, output this EXACT text:"
  echo "  <promise>$COMPLETION_PROMISE</promise>"
  echo ""
  echo "STRICT REQUIREMENTS (DO NOT VIOLATE):"
  echo "  ✓ Use <promise> XML tags EXACTLY as shown above"
  echo "  ✓ The statement MUST be completely and unequivocally TRUE"
  echo "  ✓ Do NOT output false statements to exit the loop"
  echo "  ✓ Do NOT lie even if you think you should exit"
  echo ""
  echo "IMPORTANT - Do not circumvent the loop:"
  echo "  Even if you believe you're stuck, the task is impossible,"
  echo "  or you've been running too long - you MUST NOT output a"
  echo "  false promise statement. The loop is designed to continue"
  echo "  until the promise is GENUINELY TRUE. Trust the process."
  echo ""
  echo "  If the loop should stop, the promise statement will become"
  echo "  true naturally. Do not force it by lying."
  echo "═══════════════════════════════════════════════════════════"
fi