# Ralph Wiggum Extension

This extension implements the Ralph Wiggum technique - continuous self-referential AI loops for interactive iterative development.

## What is the Ralph Wiggum Technique?

The Ralph Wiggum technique is an iterative development methodology based on continuous AI loops.

**Core concept:**
The same prompt is fed to the AI repeatedly. The "self-referential" aspect comes from the AI seeing its own previous work in the files and git history.

**Each iteration:**
1. AI receives the SAME prompt.
2. Works on the task, modifying files.
3. Tries to exit.
4. Stop hook intercepts and feeds the same prompt again.
5. AI sees its previous work in the files.
6. Iteratively improves until completion.

## Available Commands

### /ralph-loop <PROMPT> [OPTIONS]

Start a Ralph loop in your current session.

**Usage:**
```
/ralph-loop "Refactor the cache layer" --max-iterations 20
/ralph-loop "Add tests" --completion-promise "TESTS COMPLETE"
```

**Options:**
- `--max-iterations <n>` - Max iterations before auto-stop.
- `--completion-promise <text>` - Promise phrase to signal completion.
- `--debug` - Enable debug logging (saved to `.gemini/ralph-debug.log`).

**How it works:**
1. Creates `.gemini/ralph-state.json` state file.
2. You work on the task.
3. When you try to exit, the stop hook intercepts.
4. Same prompt is fed back.
5. You see your previous work.
6. Continues until promise detected or max iterations reached.

### /cancel-ralph

Cancel an active Ralph loop (removes the loop state file).

## Key Concepts

### Completion Promises

To signal completion, you must output a `<promise>` tag:

```
<promise>TASK COMPLETE</promise>
```

The stop hook looks for this specific tag. Without it (or `--max-iterations`), Ralph runs infinitely.
