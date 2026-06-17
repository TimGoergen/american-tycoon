# Epoch-Based Staffing System — Design Plan

**Status:** approved & in build. Phase 1 (headless core) DONE 2026-06-16 (commit d7e6b23 on
`feature/epoch-staffing`, off `release`). GDD §6 rewrite DONE 2026-06-16 (now the design of
record — see "GDD impact" below). NEXT: Phase 2 (Legacy per-staffer retention).
**Supersedes:** GDD §6 ("Staffing & Automation") — now rewritten to match; see "GDD impact" below.

---

## 1. The idea in one paragraph

Staffing stops being a one-time on/off switch and becomes a **tiered upgrade track keyed to
alien epochs**. The single currency stays **Earth dollars** — aliens are *flavor and magnitude*,
not a new money type. As a run pushes its earnings far enough, Earth makes **contact** with
successive alien civilizations (from `docs/alien_civilizations.md`). Each contact opens the next
epoch and unlocks a **new staffer tier for every property** — an alien-tech replacement that is a
large multiplier over the previous staffer, with the civilization's technology as the in-fiction
reason ("the Luminari run your ATMs on coherent light now"). This is what diegetically justifies
Earth's economy climbing to absurd, off-world magnitudes: capitalism ran out of Earth, so it
opened the galaxy as a market.

## 2. How the loops fit together (Tim's calls, 2026-06-16)

- **Currency:** one currency (Earth dollars). Alien currencies are naming/flavor on magnitude
  bands, not separate mechanics.
- **Epochs are reached *within a run* by consuming the entire current economy** (Tim, 2026-06-16).
  Each epoch has a *total economic value*; Earth's is the existing Earth target (~$103.6T = "buy the
  Earth"). Once the player has extracted that whole value, contact with the next civilization fires
  and the next epoch (orders of magnitude larger) opens. "You ran out of Earth to buy, so the galaxy
  opens" — the threshold ladder *is* the absurd-scale justification.
- **Prestige resets the run to the beginning of Earth** (this already happens — `perform_succession`
  → `_new_generation` builds a fresh `GameState`). Prestige is *how you get strong enough to reach
  later civilizations*: each life, Legacy upgrades let you punch further into the epoch ladder than
  the last.
- **Staff do NOT survive prestige by default.** They reset with the founder.
- **A Legacy (prestige) upgrade lets you retain *individual* staff** across the reset — the
  "Loyal Household Staff" idea from GDD §6, now realized as the persistence mechanic.

Net effect: three progression cadences that reinforce instead of compete — milestones (within
property), epochs (within run), Legacy (across runs).

## 3. What already exists (so we refactor, not rebuild)

- Per-property hire → permanent auto-cycle: `PropertyState.is_staffed`, `hire_staff()`, auto-restart
  in `tick()`.
- Hire cost (`get_staff_cost`, 50× band-1 unit cost), full `try_hire` path Economy → GameState.
- HIRE / STAFFED button states in `PropertyRow`, manager portrait circle, save/load of staffing.
- All 12 Earth staffer names already authored in the `.tres` configs (ATM Technician … Chief of Staff).
- Legacy upgrade scaffolding (`LegacyUpgradeCatalog` + `LegacyUpgrades`) with a working
  compounding-effect model and a "Loyal Staff" *cost discount* (distinct from retention).

## 4. Mechanical changes

### 4.1 New: epoch data + state (headless)
- **`scripts/core/EpochCatalog.gd`** — static data table (same style as `LegacyUpgradeCatalog`):
  one row per epoch = `{ id, civilization, home_planet, currency_flavor, contact_threshold,
  staff_multiplier, staffer_names_by_property }`. First pass: **Earth + 3 alien races** (e.g.
  Luminari Collective, Geth-Sentinel Grid, Mycelium Unity) so the system is exercised end-to-end
  without authoring all 100.
- **`scripts/core/EpochState.gd`** — tracks `current_epoch` reached *this run*; advances when
  `economy.cash_earned_this_gen` (or net worth — TBD, see open Q) crosses the next
  `contact_threshold`; exposes the active epoch for income math and UI, and emits a "contact made"
  signal for the transition screen.
- Thresholds are TuningConfig-backed so they're editable in the dev panel.

### 4.2 `PropertyState`: `is_staffed: bool` → `staff_tier: int`
- `0` = unstaffed; `1` = Earth staffer; `2+` = the alien staffer unlocked at that epoch.
- `staff_tier >= 1` means "staffed" (auto-cycle) — existing automation logic unchanged.
- Each tier carries a **per-property income multiplier** (`EpochCatalog.staff_multiplier`),
  applied at point of payment alongside frenzy/Legacy (so it shows up in income/sec honestly).
- You can only hire/upgrade to a tier once its epoch is reached this run.
- Hire-to-next-tier cost scales with tier (reuses the existing curve, × a per-tier factor).

### 4.3 Income threading
- New `staff_income_multiplier` flows from `EpochCatalog` → `PropertyState` the same way
  `cycle_speed_multiplier` already does, and folds into `_collect()` / `get_income_per_sec()`.

### 4.4 Staff retention via Legacy (per-staffer)
- **Every staffer is individually retainable** (Tim, 2026-06-16) — not a single global "N highest"
  upgrade. The player spends Legacy to mark a specific property's staffer as retained; a retained
  staffer carries its tier into the heir on `_new_generation`.
- Modeled as a **per-property retained tier** on the dynasty layer (`LegacyUpgrades` or a small
  sibling state): "you've paid to keep the ATM's staffer at tier 2", so the heir's ATM starts
  staffed at tier 2. Buying retention again raises the retained tier.
- This replaces the old single "Loyal Household Staff" catalog entry idea; the existing "Loyal
  Staff" *cost discount* upgrade is unrelated and stays.

### 4.5 Save schema
- Bump `GameState.SAVE_VERSION`; store `staff_tier` per property (migrate old `is_staffed` → tier 1)
  and the run's `current_epoch`. Older saves load (default epoch 1, tier from bool).

### 4.6 Sim
- `sim/Sim.gd` dynasty protocol gains epoch advancement + staff-tier hiring so the
  "speeds up every time" check still holds and the new multipliers are balance-verified headless.

## 5. UI changes (later phase)
- Staffer card per property: current alien staffer name + tier multiplier, and an "upgrade staff"
  action when a new epoch unlocks a better tier.
- **First-contact moment**: a flavor beat when a `contact_threshold` is crossed — names the
  civilization, its tech, and "new markets open." Reuses the ceremony/overlay pattern.
- An epoch indicator near the hero stat (which civilization Earth is currently trading with).
- *Deferred:* the GDD §6 "quiet ratio" (hire cost vs. lifetime revenue) — still a nice satirical
  stat for a staffer card, but no longer the centerpiece; track separately.

## 6. Phasing (each phase headless-verified before the next)
1. ✅ **Epoch core + staff-tier refactor** — `EpochCatalog`, `EpochState`, `PropertyState` tier,
   income threading, save bump (v4→v5), sim. No UI. *DONE 2026-06-16, commit d7e6b23.*
2. ✅ **Legacy staff retention** — `StaffRetention.gd` (per-property retained tier + geometric
   Legacy cost), `DynastyState.buy_staff_retention` + `_apply_retained_staff` carry-forward in
   `_new_generation`, dynasty save round-trip. *DONE 2026-06-16; EpochTest §6 (11 checks) PASS.*
3. ✅ **UI** — tiered HIRE/UPGRADE/STAFFED button on `PropertyRow` (epoch-gated), epoch banner
   under the hero stat, `FirstContactOverlay`, and a Household Staff retention section in the
   Estate Office (`LegacyScreen`). Income readout throttled and the property-ladder visibility
   rule (owned ∪ affordable ∪ cheapest-unaffordable) landed alongside. *DONE 2026-06-16; Main
   scene headless smoke test PASS.*
4. ✅ **Content** — epochs extended to 6 (added Quartzite Conglomerate + Chronophage Enclave),
   full 12-staffer rosters + narrator contact lines for every alien epoch; EpochTest §7 content
   integrity check added. *DONE 2026-06-16.*

## 7. GDD impact — DONE 2026-06-16
GDD §6 (Staffing & Automation) **rewritten** as epoch-keyed staffing with subsections §6.1 (staff
tiers), §6.2 (Epochs & First Contact, incl. the v1 epoch table from `EpochCatalog.gd`), §6.3
(per-staffer retention), §6.4 (deferred "quiet ratio"). Also reconciled: §3 loop 3 (now "The Epoch"
/ alien contact instead of distinct markets), §5.1 (Legacy reaches deeper epochs), the Future
Features "alien-contact epochs" entry (marked ADOPTED & IN BUILD; only the per-epoch modifier draft
stays parked), §14 Q8 "Market Two" (superseded), §13 milestones (M3/M4). Mechanics Spec §6 (tiered
hire), Legacy retention line, PropertyConfig/PlanetConfig notes, and the Art Style Guide §6 staffer
cards (per-epoch reskins, ~48-card asset bill) updated to match.

## 8. Resolved decisions (Tim, 2026-06-16)
1. **Epoch trigger:** consume the entire current economy (reach the epoch's total economic value).
2. **Retention:** every staffer individually retainable via Legacy (per-property retained tier).
3. **v1 races (chosen thematically):** Earth + 3 aliens, in contact order —
   - **Epoch 2 — Luminari Collective** (Energy/Plasma, *Photons*). First contact electrifies the
     whole operation: money moves at light speed. The "wow, everything just got faster/brighter" beat.
   - **Epoch 3 — Geth-Sentinel Grid** (Cybernetic, *Logic Nodes*). Full algorithmic automation —
     the satire of finance run entirely by machines (day trading, hedge funds, MLM as code).
   - **Epoch 4 — Mycelium Unity** (Fungal hive-mind, *Spores*). Self-replicating biological growth;
     money that literally spreads. MLM-as-mycelial-network is the punchline.
   Arc: energy → automation → proliferation, each a different flavor of "the aliens make your money
   machine inhuman." More races added in Phase 4.
