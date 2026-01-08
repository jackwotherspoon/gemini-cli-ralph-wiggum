# Ralph Wiggum Gemini Extension

Implementation of the Ralph Wiggum technique for iterative, self-referential AI development loops in the Gemini CLI.

## What is Ralph?

Ralph is a development methodology based on continuous AI agent loops. As Geoffrey Huntley describes it: **"Ralph is a Bash loop"** - a simple `while true` that repeatedly feeds an AI agent a prompt file, allowing it to iteratively improve its work until completion.

The technique is named after Ralph Wiggum from The Simpsons, embodying the philosophy of persistent iteration despite setbacks.

### Core Concept

This extension implements Ralph using an `AfterAgent` stop hook that intercepts the agent's exit attempts:

```bash
# You run ONCE:
/ralph-loop "Your task description" --completion-promise "DONE"

# Then Gemini CLI automatically:
# 1. Works on the task
# 2. Tries to exit
# 3. Stop hook blocks exit
# 4. Stop hook feeds the SAME prompt back as additional context
# 5. Repeat until completion
```

The loop happens **inside your current session** - you don't need external bash loops. The Stop hook in `hooks/stop-hook.sh` creates the self-referential feedback loop by blocking normal session exit and re-injecting the original prompt.

## Installation

1.  Navigate to this directory.
2.  Link the extension to your Gemini CLI:
    ```bash
    gemini extensions link .
    ```
3.  Restart Gemini CLI.

## Quick Start

```bash
/ralph-loop "Build a REST API for todos. Requirements: CRUD operations, input validation, tests. Output <promise>COMPLETE</promise> when done." --completion-promise "COMPLETE" --max-iterations 50
```

Gemini will:
- Implement the API iteratively.
- Run tests and see failures.
- Fix bugs based on test output.
- Iterate until all requirements met.
- Output the completion promise when done.

## Commands

### `/ralph-loop`

Start a Ralph loop in your current session.

**Usage:**
```bash
/ralph-loop "<prompt>" --max-iterations <n> --completion-promise "<text>" [--debug]
```

**Options:**
- `--max-iterations <n>` - Stop after N iterations (default: unlimited).
- `--completion-promise <text>` - Phrase that signals completion. Must be wrapped in `<promise>` tags in the model's output.
- `--debug` - Enable debug logging to `$GEMINI_PROJECT_DIR/.gemini/ralph-debug.log`.

### `/cancel-ralph`

Cancel the active Ralph loop (removes the state file).

**Usage:**
```bash
/cancel-ralph
```

## How It Works (Technical Details)

- **State Persistence**: State is stored in `$GEMINI_PROJECT_DIR/.gemini/ralph-state.json`.
- **Looping Mechanism**: Uses the `AfterAgent` hook. It increments the iteration count in the state file and returns a `decision: "block"` with the original prompt in the `reason` field to force the model to continue.
- **Completion Detection**: The hook scans the model's `prompt_response` for `<promise>TEXT</promise>`. If it matches the configured promise, the state file is deleted and the loop stops.

## Philosophy

Ralph embodies several key principles:

1.  **Iteration > Perfection**: Don't aim for perfect on the first try. Let the loop refine the work.
2.  **Failures Are Data**: "Deterministically bad" means failures are predictable and informative. Use them to tune prompts.
3.  **Operator Skill Matters**: Success depends on writing good prompts, not just having a good model.
4.  **Persistence Wins**: Keep trying until success. The loop handles retry logic automatically.

## Learn More

- Original technique: [https://ghuntley.com/ralph/](https://ghuntley.com/ralph/)
- Ralph Orchestrator: [https://github.com/mikeyobrien/ralph-orchestrator](https://github.com/mikeyobrien/ralph-orchestrator)
