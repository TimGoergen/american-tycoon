# Git Workflow Rule

## Core Requirement:
Always commit and push changes to the active feature branch immediately after finishing and verifying a task or completing a body of work.

## Specific Guidelines:
1. **Completion Action**: Once a task or feature implementation is complete and verified (e.g. running gates/sim tests), stage the modified/created files (`git add ...`), create a clear semantic commit (`git commit -m "..."`), and immediately push to the remote (`git push origin feature/<name>`).
2. **Branch Naming**: Use the prefix `feature/` for branch names (e.g. `feature/audio-cues`, `feature/rare-events`). Never use `fix/` or `bugfix/` because automated CI builds only trigger on `feature/*` and `main`. Never leave completed work uncommitted or unpushed.
3. **Atomic Execution**: Always execute `git` commands as single, unchained commands (never chain with `;`, `&&`, or shell wrapper scripts).
