# Git Workflow Rule

Always commit every completed body of work into a dedicated feature branch starting with the prefix `feature/` (e.g. `feature/multi-touch-rush-crash`) as soon as it is finished, and push that branch to origin remote (`git push -u origin feature/<name>`).

**Branch Naming Requirement**:
Use `feature/` for branch names (never `fix/`, `bugfix/`, etc.) because automated CI builds only trigger on branches matching `feature/*` and `main`. Never leave completed work uncommitted on `main`.
