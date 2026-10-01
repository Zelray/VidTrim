# VidTrim — AGENTS.md

VidTrim is a simple Windows desktop tool (PowerShell, no install required) that trims
seconds off the beginning of video files, either one file at a time or a whole folder
of them. It's driven by double-clicking the launcher — no command line knowledge needed.

## What it does (one pass, high level)
1. Double-click the icon → asks: pick a **file** or a **folder**.
2. Windows Explorer picker opens (single-file picker, or folder picker).
3. Asks how many seconds to cut from the **beginning** of each video. Default **60** if you just hit Enter.
4. If a folder: asks which extension to process. Default **.mp4**.
5. Shows a confirmation summary ("will cut X seconds off these N videos — sure?").
6. Offers to **keep the originals** (strongly recommended, Y is default):

   - Single file: original stays in place, renamed with a trailing `~`
     (e.g. `family_vacation.mp4~`).
   - Folder: originals are moved into a subfolder called `Original_Vids`
     inside the picked folder.

   It checks free disk space first; if there's not enough it refuses and suggests
   working in smaller batches.
7. Trims the videos in place.
8. Job-done message: tells the user to verify the new videos, and that typing
   **DELETE** moves the saved originals to the Recycle Bin (the `Original_Vids`
   subfolder for folder jobs; for single files the `~`-renamed original).

## Engineering rules for anyone (any agent) working on this codebase

### 1. Think Before Coding
Don't assume. Don't hide confusion. Surface tradeoffs.

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First
Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.
- Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes
Touch only what you must. Clean up only your own mess.

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.
- When your changes create orphans:
  - Remove imports/variables/functions that YOUR changes made unused.
  - Don't remove pre-existing dead code unless asked.
- The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution
Define success criteria. Loop until verified.

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]

Strong success criteria let you loop independently. Weak criteria ("make it work")
require constant clarification.
