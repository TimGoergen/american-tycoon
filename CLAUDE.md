# American Tycoon — Project Instructions

## Before Any Work

Read `/docs` before starting any task. The authoritative sources are:

- **GDD v0.2** — canon for design intent
- **Mechanics Spec v0.1** — canon for math and formulas
- **M1 Brief** — canon for current milestone scope

## Standing Review Criteria

Every implementation must be evaluated against:

- **Principle 4** — playable and fun first
- **The anti-pillar** — GDD §0.1 (what this game must never become)

## Rules

- **No tuning constants in code.** All tuning values (costs, rates, multipliers, timings, etc.) load from `/config`.
- **Script language: GDScript.**
