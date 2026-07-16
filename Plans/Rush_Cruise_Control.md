# Rush Cruise Control (Rush Overheat amendment) — design of record

**Origin:** Tim, 2026-07-16. After approving Rush Overheat's push-your-luck rhythm, Tim missed
the old ability to rush constantly. Chosen compromise: holding is safe forever at a reduced
"cruise" bonus; the danger bands become an OPT-IN gamble behind a dedicated OVERDRIVE button.

**Status:** Design agreed 2026-07-16; implementing on `feature/rush-cruise-control`.

## The deal

- **Hold = cruise, forever.** While rush is held and overdrive is NOT engaged, heat climbs
  normally but **clamps at the cruise point** — the heat where the bonus equals
  `rush_momentum_cruise_bonus` (first-cut **+25%**, Tim's number). No overheat is possible
  while cruising. This restores the zone-out infinite rush, at 5 points under the old +30% cap.
- **OVERDRIVE is a dedicated button** (Tim: same pattern as the TURBO pop button and the
  minigame inputs — one obvious tappable thing). Tapping it while rushing releases the clamp:
  heat resumes climbing through Building's remainder, Hot, and Critical exactly as shipped —
  secret rolled ceiling, overheat, lockout, re-arm all unchanged.
- **Overdrive is per-excursion.** It disengages when the rush hold ends (and on overheat and
  on reset). The next press starts back in cruise mode; the gamble is always a fresh choice,
  never a sticky mode you forgot you left on.
- Everything below the cruise point is untouched: build/bleed rates, frenzy freeze, First
  Contact reset, the "cash always matches the readout" pure-function invariant.

## Why the bands survive unchanged

The cruise point is derived, not a new band: cruise_heat = the inverse of the Building
band's linear bonus mapping at `cruise_bonus` (≈ 0.833 heat units at +25% with the shipped
+30%-at-Hot edge). The band geometry, ceiling roll ("randomness lives only in Critical"),
and the +55% peak stay exactly as tuned in `Plans/Rush_Overheat.md`.

Boundary rule: with max Legacy the cruise point reaches heat 1.0 exactly. Heat AT 1.0 while
cruising must NOT start an excursion (no ceiling roll, no Hot visuals) — the Building band
becomes inclusive of 1.0; an excursion starts only when overdrive pushes heat PAST the tick.

## Legacy upgrades (Tim: "partially nerf the limitations") — two upgrades, both additive + capped

| Upgrade | Effect per level | Cap | Rationale |
|---|---|---|---|
| **Cooling Systems** | +1 point cruise bonus (25% → 26% → …) | 5 levels (+30% = the old always-on cap, NEVER higher) | Late-dynasty heirs re-earn the old infinite rush exactly; Hot/Critical bonuses stay exclusive to riding the danger zone (Tim 2026-07-16: cap at +30%). |
| **Rapid Restart** | −10% total overheat lockout time (drain faster AND re-arm shorter, same scale) | 5 levels (half the punishment, never zero) | Overheating always stings, but a storied dynasty recovers faster. |

Both additive with hard caps (the compounding treatment is reserved for the three core
accelerators — a compounding limitation-remover runs away). Costs follow the existing
catalog's small-utility pattern (Frenzy shop tier); first-pass values, Tim feel-tunes.

## UI

- OVERDRIVE button on the momentum bar, following the FrenzyBar precedent (square icon
  button beside a display-only meter). Visible/enabled only while a rush hold is live,
  overdrive is not yet engaged, and no lockout is active; hidden otherwise so the bar
  stays calm during idle play. Large tap target (UI readability rule).
- While cruising at the clamp the bar reads as a steady, content state (e.g. CRUISE +25%
  caption) — clearly distinct from the amber/red danger escalation.
- Once engaged, the shipped overdrive presentation takes over unchanged (amber wash,
  hazard-striped Critical, blink, chips, haptics).

## Knobs (Balance Tuning)

| Knob | First-cut | Meaning |
|---|---|---|
| `rush_momentum_cruise_bonus` | 0.25 | Sustainable bonus while holding without overdrive |

Legacy effect sizes/caps/costs live in `LegacyUpgradeCatalog` like every other upgrade.

## Verification

- `sim/RushOverheatTest.gd` extended: cruise clamp holds indefinitely; overdrive engage
  resumes the climb; disengage-on-release; Legacy cruise cap and lockout scaling; the
  boundary rule at heat 1.0. Duty-cycle comparison re-run (cruise vs ride/vent) so Tim
  sees what the gamble is actually worth over the safe +25%.
- Headless editor import + game boot; device pass by Tim (Firebase APK).

## Decision log

- Cruise band compromise chosen over living-with-it and full revert (Tim, 2026-07-16).
- Cruise bonus starts at +25% (Tim, 2026-07-16).
- Dedicated OVERDRIVE button, not a gesture (Tim, 2026-07-16).
- Legacy ceiling for cruise = +30%, the old cap, never into Hot (Tim, 2026-07-16).
- Two Legacy upgrades — cruise cap raise AND lockout softening (Tim, 2026-07-16).
- Overdrive disengages on release (Claude's call, flagged): keeps the gamble a per-press
  choice and protects the zone-out default; trivially flippable to a latched toggle.
