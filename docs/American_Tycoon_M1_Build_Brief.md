# American Tycoon — M1 Build Brief ("The Slice")

**Date:** June 12, 2026
**Audience:** Claude Code, working in the new Godot repo
**Canon:** GDD v0.2 · Mechanics Spec v0.1 · Art Style Guide v0.1 (this brief summarizes; the canon documents win on conflict)
**Exit criterion (GDD §13):** Dopaminergic on real phone hardware; the return-spike loop verified against a real 3-hour gap.

---

## 1. What M1 Is

The smallest playable version of the core loop that can prove the game is fun: tap a wage, buy properties, run cycles, cross count milestones, feel the acceleration, bank an offline pile, return, spend it, watch income/sec jump. Placeholder art (style-guide palette and fonts only — no hero illustrations). One screen.

**M1 exists to answer one question: does the return spike feel good in the hand?**

## 2. In Scope

### Systems (Mechanics Spec references)
- **Properties** — all 12 from the Earth table (GDD §4 / config-driven from day one, Spec §11): purchase, cycles, collect-on-completion.
- **Cost curve** — piecewise band ratios (Spec §3.2), with +1 / +10 / +to-next-milestone / MAX bulk buttons (exact-sum pricing; the 2022 MAX bug stays dead).
- **Count milestones** — bands at 20×2^k; adaptive reward: halve cycle to CYCLE_FLOOR, then double income (Spec §3.3). Per-property milestone slider (Spec §3.5).
- **Tapping** — start verb + rush verb at RUSH_PCT (Spec §4).
- **Wage button** — flat wage per tap; full title/tuition ladder is M2+, but the button, the tap counter, and one or two placeholder promotions ship now (the ladder must exist to be obliterated by the first ATM).
- **Frenzy** — full one-bar state machine (Spec §7); feel-tune constants on hardware.
- **Staffing** — per-property hire, auto-run (Spec §6). Needed in M1 because offline draws from staffed properties only.
- **Offline accrual** — closed-form on resume, staffed-only, capped (Spec §§2, 6). Two-beat welcome-back screen (plain version; ceremony copy is M3).
- **Income/sec hero stat** — top of screen, stamp-pop + flashed delta on purchase (Style Guide §9). This is the dopamine delivery vehicle; do not stub it.
- **Save** — JSON, versioned schema, autosave 10s + on background (Spec §12). Timestamp for offline calc per Spec §2 clock policy.

### Engineering foundations (cheap now, miserable later)
- `Money` wrapper type (Spec §1).
- Fixed-timestep logic at LOGIC_HZ, render decoupled (Spec §2).
- All property/tuning values loaded from config Resources (Spec §11) — no constants in code.
- Tuning table (Spec §12) as a single config file.
- **Simulator-ready architecture:** game logic must run headless (no scene-tree dependencies in the sim core). The balance simulator (Spec §13) begins during M1.

## 3. Explicitly Out of Scope (resist)

Death/prestige/Legacy (M2) · estates, will screen, Estate Planning tab (M2) · origins flow & debt (M2) · loan offers (M2) · heir names (M2) · events (M3) · hero art, staffer cards, backdrops (M3) · narrator copy (M3) · Earth target % display, Final Dollar (M4) · planets (M4) · audio beyond placeholder collect/purchase blips (M3).

If a system tempts inclusion because "it's small," check it against the 2022 postmortem: the project died of technical details before reaching the dopamine. Ship the slice.

## 4. The One Screen

Main screen only (Spec §14), portrait: income/sec ticket (top) · frenzy bar · scrolling property ladder (12 rows: name, owned count, milestone slider, cycle progress, buy buttons, hire button) · wage button (bottom, permanent). Style-guide palette + candidate fonts; rects-and-text fidelity is fine, but motion language (Style Guide §9 — stamps, not bounces; cycle spin tied to real cycle progress) ships in M1 because the acceleration feel is the test subject.

## 5. M1 Verification Protocol

1. Build to phone. Play the opening 15 minutes fresh: does purchase cadence quicken? Do the first milestones land with visible speed-up?
2. Staff the ATM, close the app, live life for ~3 hours.
3. Return. The pile should fund at least one threshold (Spec tuning anchor, GDD §3.2). Spend it in ≤2 taps via bulk buy. The income/sec jump should *feel* like something.
4. If any step fails: tune constants (Spec §12), not systems. Log every constant change — those are the simulator's first calibration data.

## 6. Repo Conventions

- Godot 4.x, mobile renderer, portrait lock.
- `/game` (scenes/scripts) · `/sim` (headless simulator entry) · `/config` (Resources: properties, tuning) · `/art/src` (asset SVGs — assets are code) · `/docs` (the three canon documents + this brief).
- CLAUDE.md at repo root: points to canon docs, states Principle 4 (playable-and-fun first) and the anti-pillar (GDD §0.1) as standing review criteria for every change.
