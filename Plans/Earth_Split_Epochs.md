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
(`EpochState.update`). The split needs one NEW threshold — Blue→White.

**Decided: $75M earned** (Tim, 2026-07-27, revising the study's first $150M read —
`sim/BlueCollarStudy.gd`; brief: the threshold should land when a new player owns at
least one of each Blue Collar property, has bought a few of each, and can afford Day
Trading, $6M). A bare founder restricted to Blue Collar buying, same play model as
Sim.gd's playouts:

| milestone | IDLE (passive floor) | ACTIVE (rush top 2, no Strong-Arm) |
|---|---|---|
| own 1 of each | $11.9M earned (3.7 m) | $9.5M (1.5 m) |
| own 3 of each | $28M (4.3 m) | $20.1M (1.8 m) |
| cash covers Day Trading | $130M (5.6 m) | $69M (2.0 m) |
| **at $150M: cash on hand** | **$7M (5.7 m)** | **$7.8M (2.4 m)** |

- $75M anchors on the ACTIVE player, who arrives with Day Trading money in hand
  (~$7.5M at $69M earned). An idle player arrives a few million short — but the sim's
  cash figures come from a greedy buyer that never stops reinvesting; a real player
  who wants Day Trading just pauses Blue Collar buying, and at that income the gap
  closes in tens of seconds. A brief, deliberate save-up is ON-design: every alien
  boundary works this way (flagship ≈ 10% of the previous threshold ≈ cash on hand;
  "earning your first purchase is the achievement", GDD §5.5). Day Trading at $75M is
  an 8% flagship — almost exactly the established ratio ($150M would soften it to 4%).
- Timing vs today: the White Collar tab currently unlocks (afford $6M) at 5.6 m idle /
  2.0 m active — $75M lands the game's FIRST epoch beat at ~5.1 m / ~2.1 m. Slightly
  earlier than today, per the locked fast-pace principle, and it rehearses the real
  boundary feel rather than a softened version.
- White→Luminari keeps the full `earth_economy_target` ($103.6T) — the Earth total is
  unchanged, it just becomes tier 2's exit rather than tier 1's.
- Mechanically: `economy_scale` stays the single source of truth (threshold =
  `scale × earth_economy_target`). Blue Collar gets `scale = 75e6 / 103.6e12 ≈ 7.24e-7`;
  White Collar 1.0; aliens keep their 16807-per-step ladder (exponent re-based, values
  identical to today's).

## The arrival beat (design decision #2)

Tier 2's arrival is Earth→Earth, so the alien First Contact framing (hail from a civ,
trade-deal minigame for a new alien property type) doesn't fit as-is.

**Decided (Tim, 2026-07-27): quiet card only for v1.** A promotion-flavored beat on the
contact-overlay bones — moving up, not alien contact — with NO minigame at tier 2 for
now. **Deferred follow-up:** add the trade-deal minigame here later with new
promotion-themed copy (Tim likes the rehearsal idea; it needs its own writing pass).
The dispatch just needs a clean seam so the minigame can slot in later.

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
  they follow automatically — and the renumbering is NEUTRAL at every equivalent content
  moment. White Collar properties: at "Luminari just arrived" they have 2 blocks today
  (reached 2 − unlock 1 + 1) and 2 blocks after (3 − 2 + 1); block prices are anchored
  to the block's epoch ECONOMY (`get_staff_block_anchor` → `economy_scale(block_epoch)`),
  which renumbers along with them — same blocks, same prices, at every point of the run.
  The one real change is a GAIN: Blue Collar properties open an extra 20-level block at
  the White Collar arrival, priced off the White economy (modest) — an early staff-depth
  beat that reinforces the new epoch. Endgame depth: Blue 27 blocks (one more than
  today), White 26 (exactly today's).

**Save migration (save format v10)**
- `current_tier`: saved tier T ≥ 2 → T + 1. A saved tier-1 (mid-Earth) run maps to Blue
  or White by the own-all-Blue-Collar test, then money.
- White Collar `staff_level`s need NO clamping or grandfathering: a save at today's tier
  T migrates to tier T+1, where the White cap is identical (20·(T+1−2+1) = 20·T — see
  the staff-blocks note above). Blue caps only grow. The only mapping rule is the
  tier-1 one above: a mid-Earth save that already owns any White Collar property (or
  meets the gate) maps to tier 2, so nothing the player owns ever locks on them.
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

## Decisions log (all three open questions resolved 2026-07-27)

1. **Threshold: $75M** (Tim's call, 2026-07-27, on the `sim/BlueCollarStudy.gd` data —
   see the Thresholds section: active players arrive with Day Trading money in hand,
   idle players get a seconds-long deliberate save-up matching the alien-boundary
   convention, and the first epoch beat lands slightly EARLIER than today's tab unlock).
2. **Arrival beat: quiet promotion card only.** The trade-deal minigame comes later
   with promotion-themed copy (deferred follow-up; leave a dispatch seam).
3. **Staff blocks: uniform rule, no special-casing, no migration clamps** — the
   renumbering turned out to be neutral at every equivalent content moment (blocks AND
   prices), with Blue Collar gaining one cheap early block. See the staff-blocks note.

## Implementation order (when approved)

1. Core renumber: EpochCatalog split + `.tres` unlock_tier bumps + save migration v10.
2. Threshold + gate; EpochTest updated and green headless.
3. UI fan-out: pager, backgrounds, portraits dispatch, promotion beat, tuning panel.
4. Full sim suite + boot; push branch APK; Tim's device pass (early game + a migrated
   mid-Earth save + a deep save).
