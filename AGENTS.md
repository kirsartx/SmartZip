# SmartZip Agent Handoff Rules

## Start Here

Before proposing or editing code, read in this order:

1. docs/continuity/ACTIVE_TASK.md
2. docs/continuity/DECISIONS.md
3. README.md
4. tests/README.md
5. git status --short

Summarize the current task, working-tree state, and next verification command. Wait for the user's confirmation before editing.

## Cross-Model Continuity

- Treat project files and Git history as the source of truth; never rely on another provider's conversation, response ID, or session ID.
- Start a new conversation when switching between Codex and EchoBird.
- Only one model may edit this worktree at a time.
- Preserve existing user changes. Do not use git reset --hard, git checkout --, or overwrite an uncommitted file to make the tree clean.

## Before Handoff

Update docs/continuity/ACTIVE_TASK.md with the goal, completed work, remaining work, changed files, commands run, and their exact results. Record stable choices in docs/continuity/DECISIONS.md.

## Verification

Run git diff --check after edits. Run the focused or complete test command from tests/README.md when the task changes executable behavior. State explicitly when tests were not run.

## Sensitive Data

Do not record API keys, passwords, session IDs, response IDs, or unredacted logs in project files or prompts.
