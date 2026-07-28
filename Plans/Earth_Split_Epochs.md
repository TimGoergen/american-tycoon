# Earth Split — Blue Collar and White Collar as full epochs

**Status: draft for Tim's review (2026-07-27). Nothing implemented.**
Target branch: `feature/civs-12-26` (it renumbers the same 27-tier content that branch ships).

## What Tim asked for

Earth Blue Collar and Earth White Collar become full separate epochs, each with its own
economy progress bar fill — not two tabs sharing one Earth epoch.

## Why it fits (the design case)

- White Collar is already a proto-epoch: it has an ownership gate (own every Blue Collar
  property), an affordability gate, and its own pager tab. This makes the progression
  grammar uniform — one rule for every step of the ladder.
- The player currently reaches the END of the whole Earth run before ever seeing an epoch
  arrival. The split teaches the core loop (bar fills → engage the whole cohort → arrival
  beat → new cohort opens) within the first minutes — a cheap rehearsal for First Contact.
- The economy bar becomes meaningful from minute one: today it crawls toward $103.6T for
  the entire Earth run; Blue Collar's own target gives an early first fill.

## The new ladder shape

27 epochs. Tier 1 = Earth Blue Collar (properties 1–6), tier 2 = Earth White Collar
(properties 7–12), tiers 3–27 = the 25 alien civs (all shift +1 from today's 2–26).

A happy accident of the current code: pager tabs already run 0 = Blue, 1 = White,
2 = Luminari…, so **tab = tier − 1 uniformly** after the split. `_epoch_tab_of()`
collapses to `unlock_tier − 1` and the Earth special-casing (indices 0–5 / 6–11)
disappears. The White Collar tab-unlock rule (own all Blue + afford its cheapest)
retires in favor of the standard epoch gate.

## Thresholds (the one real tuning decision)

Epoch advance stays "earn the epoch's economic value AND own ≥1 of every property in it"
(`EpochState.update`). The split needs one NEW threshold — Blue→White:

- **Proposal: $60M earned.** Same anchor rule as every other epoch boundary: the next
  cohort's flagship (Day Trading, $6M) ≈ 10% of the previous threshold. This also lands
  close to when the White Collar tab unlocks today (afford $6M ≈ the same wealth band),
  so early pacing barely moves — deliberate, per the locked fast-pace principle.
- White→Luminari keeps the full `earth_economy_target` ($103.6T) — the Earth total is
  unchanged, it just becomes tier 2's exit rather than tier 1's.
- Mechanically: `economy_scale` stays the single source of truth (threshold =
  `scale × earth_economy_target`). Blue Collar gets `scale = 60e6 / 103.6e12 ≈ 5.79e-7`;
  White Collar 1.0; aliens keep their 16807^(tier-2) ladder (exponent re-based, values
  identical to today's).

## The arrival beat (design decision #2)

Tier 2's arrival is Earth→Earth, so the alien First Contact framing (hail from a civ,
trade-deal minigame for a new alien property type) doesn't fit as-is.

- **Proposal: reuse the contact plumbing with promotion flavor.** A "You've outgrown the
  corner hustle — Wall Street calls" beat: same overlay bones, Earth voice, no alien hail.
- The trade-deal minigame CAN run here (White Collar opens a genuinely new property kind —
  Day Trading — so GDD §5.5's "negotiate the opening bonus" logic applies cleanly), giving
  the player a rehearsal of the First Contact minigame loop before the real thing. Upside-
  only, as always. If Tim prefers a quieter beat, skip the minigame and keep just the card.

## Blast radius (what actually changes)

**Core**
- `EpochCatalog.EPOCHS`: split Earth's dict into Blue Collar / White Collar (each with its
  own staffer roster slice, scale, display name); re-number the 25 alien dicts' `tier`
  fields 3–27. Earth-the-civilization stays the civ for BOTH tiers 1–2 (pager titles
  "EARTH — BLUE COLLAR" / "EARTH — WHITE COLLAR", as the tabs read today).
- 320 `.tres` files: White Collar's six get `unlock_tier = 2`; all 314 alien properties
  bump `unlock_tier` +1. (Blue Collar's six stay tier 1 — no file change.)
- `EpochState`: no logic change (the loop already handles N epochs); Earth-is-tier-1
  comments update.
- Staff blocks: `staff_block_epoch` / `staff_blocks_available` key off `unlock_tier`, so
  they follow automatically — but note the FEEL changes: Blue Collar properties open
  their second 20-level staff block at the White Collar arrival (nice — an early staff-
  block beat too), and White Collar properties now start their ladder one epoch later
  than Blue's (one fewer block at any reached tier than today).

**Save migration (save format v10)**
- `current_tier`: saved tier T ≥ 2 → T + 1. A saved tier-1 (mid-Earth) run maps to Blue
  or White by the own-all-Blue-Collar test, then money.
- White Collar `staff_level`s: their per-property cap drops by one block (20 levels) at
  any given reached tier. Forward-only precedent (the ownership gate, 2026-07-23): DON'T
  clamp existing levels — keep them, cap only future buys until the cap catches up.
- `_tab_unlocked` persistence: sizes already track `_epoch_tab_count()`; resize logic
  must handle the +1 growth on load (same pattern as the 11→26 growth already shipped).

**UI / content (the tier-indexed fan-out)**
- `Main._background_path_for_tier`, planet watermark, `EpochPagerDots` (27), pager
  labels/subtitles, `StafferFace` bespoke `_draw_*` portrait dispatch (alien tiers all
  +1), First Contact overlay dispatch (alien beats now tiers 3+, new tier-2 promotion
  beat), coach cards / tutorial tips that name epochs, Challenge goals that reference
  reaching a tier.
- `DevTuningPanel` playtest jump row: E1–E27.

**Sims / verification**
- `EpochTest`: ladder totals (12 + escalating cohorts unchanged in content, re-tiered),
  cohort integrity per NEW tier numbers, threshold table, a migration round-trip check.
- `Sim.gd` pacing tables, `UnlockCadence`, `PrestigeStudy` (should be untouched —
  magnitudes don't move), full playout; headless boot; device pass by Tim.
- The civ regen pipeline (`assemble.py`) tier constants, and the durable recipe: alien
  income decay becomes `0.80^(tier-2)` under the new numbering (same values as today —
  the exponent re-bases with the renumber, worth stating explicitly so a future
  extension doesn't double-decay).

## What does NOT change

- All 326 property costs, incomes, cycles — zero economy re-tune. The alien decay
  exponent re-bases so every shipped number is identical.
- Prestige/gem economics (estate-value based).
- The Earth total ($103.6T) as the alien-frontier entry bar.
- Tab count and order in the pager (27 tabs were already planned as 26+1... the pager
  simply gains formal tier identity — dots/arrows/swipe behave as today).

## Open questions for Tim

1. **$60M Blue→White threshold** — right band? (It intentionally mirrors today's White
   Collar tab-unlock timing; a lower value makes the first epoch beat land even sooner.)
2. **Promotion beat**: full treatment with the trade-deal minigame rehearsal, or a quiet
   card-only beat?
3. OK that White Collar staff ladders start one epoch later than today (one fewer block
   at a given tier), with existing saves grandfathered rather than clamped?

## Implementation order (when approved)

1. Core renumber: EpochCatalog split + `.tres` unlock_tier bumps + save migration v10.
2. Threshold + gate; EpochTest updated and green headless.
3. UI fan-out: pager, backgrounds, portraits dispatch, promotion beat, tuning panel.
4. Full sim suite + boot; push branch APK; Tim's device pass (early game + a migrated
   mid-Earth save + a deep save).
