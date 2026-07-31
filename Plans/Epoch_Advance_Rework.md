# Epoch Advance Rework — flagship gate, MAKE CONTACT, and an honest progress bar

Status: **planned, partially landed.** The tuning knob and predicate are in (behaviour-
preserving at the default); nothing player-visible has changed yet.

All decisions below are Tim's (2026-07-30/31) unless marked as a recommendation.

## The problem, measured

Tim, from device testing: *"each epoch seems to speed up with each new property you buy,
and the time between your first purchase of the last property to completing the economy is
pretty short."*

`sim/EpochPhaseStudy.gd` was built to measure this. It splits each epoch into **UNLOCK**
(entering it until you own ≥1 of every property in it) and **STACK** (from there until the
epoch clears). Live, the stack phase is **0.3%** of an epoch — from epoch 12 it rounds to
zero, and from epoch 13 the last property purchase and the epoch clear land in the *same
0.1s tick*. The flagship, the property each epoch is named for, gets no playtime at all.

Two fixes were proposed and both were **measured and rejected**:

| lever | result |
|---|---|
| raise the money gate (`earth_economy_target` ×1 / ×3 / ×10) | 0.3% / 0.8% / 2.3% |
| narrow the cohort cost spread (2.00× / 1.80× / 1.60×) | 0.3% / 0.4% / 0.4% |

Both fail for one reason: by end of epoch, income grows **super-exponentially** (staff
levels, upgrades and unit stacking compound at once), so anything denominated in dollars is
crossed in seconds. The epoch does not end because the player runs out of things to earn —
it ends the instant the ownership gate is satisfied, and that gate is satisfied by a single
purchase. The cost-spread change was additionally *harmful*: holding cohort capital fixed
makes a flatter ladder's cheapest rung pricier, so epoch 3's unlock went 24s → 52s, slowing
the opening for no benefit.

## The fix: a non-dollar gate

Require **N units of the epoch's flagship** (its most expensive property) before it will
advance. This is different in kind from everything above because it can only be satisfied
*after* the roster is complete — in the calmer post-unlock growth regime, not the explosive
one. Measured:

| flagship units | mean stack share | shape |
|---|---|---|
| 1 (live) | 0.3% | no tail |
| 10 | 1.2% | negligible |
| 25 | 3.3% | negligible |
| **35** | **34.3%** | **unlock dominant early, real tail deep** |
| 40 | 55.5% | mid epochs become mostly stacking |
| 50 | 83.5% | unlock collapses to 2-14s |

**Decision: 35.** Chosen on its per-epoch shape, not its mean — epochs 3-11 sit at 6-18%
stack (the fast early pace survives untouched, per the locked pace principle), while epochs
12-16 run 32-57%, which is exactly where Tim noticed the problem.

**The knob is TWITCHY and must be device-tuned.** 25 → 3.3%, 35 → 34%, 40 → 55%: a ±5 swing
reshapes the game. The cause is that cumulative cost of N units grows as `r0^N` (r0 = 1.09),
so the requirement is cheaper than what the player accumulates anyway until it suddenly
isn't. Two consequences: (a) any future change to `r0` or to the decay bands moves this
knob's effective value, so they must be re-checked together; (b) do not "round it to 50 for
the milestone" — 50 is measured and it is far too much.

## Scope

### 1. The gate — LANDED (default is a no-op)

- `TuningConfig.epoch_flagship_units_required: int = 1`. At 1 this is exactly the historical
  behaviour, since owning one of each already implies one flagship — every prior balance
  result still holds, and MoneyTest + EpochTest pass unchanged.
- `EconomyState.get_flagship_index_for_unlock_tier(tier)` — the tier's costliest property.
  Selected by COST, never by config order (config order is save/append order, which for some
  tiers is flagship-then-siblings).
- `GameState._owns_all_in_epoch(tier)` now also requires the flagship's `units_owned >=
  epoch_flagship_units_required`.
- **Remaining:** set `epoch_flagship_units_required = 35` in `tuning.tres`. Deliberately not
  done yet — it is a live balance change and it overlaps the banded-decay retune still
  awaiting Tim's device verdict.

### 2. MAKE CONTACT button — Tim's call, wanted on its own merits

Today `epoch.update` advances the moment both conditions are met — a push. Make it a pull:
when conditions are met, the epoch does **not** auto-advance; a MAKE CONTACT control lights
up and the player chooses when to go.

Why it is good independently of the gate: it makes lingering a *choice*, so the compressed
ending stops being something the game does to the player. It also matches the game's own
idiom — prestige is already a deliberate player act, not an automatic one.

- `EpochState.update` gains a "ready but not advanced" state rather than advancing directly;
  the actual advance moves behind an explicit `advance()` call the UI triggers.
- **No-moving-UI applies:** the button is always present and grays in place, never appears.
  It needs a clear ready state (the tab-bar treatment's "icon colour = you are here, red dot
  = something new" separation is the precedent for how to signal it).
- **Stall risk:** epoch advance is the main progression spine, so a player who does not
  notice the button stalls indefinitely. Mitigation: reuse the shipped coach-card system
  (fire on AVAILABILITY, per the locked tutorial principle) plus the existing pager red dot.
- Open question for Tim: does First Contact still play its overlay automatically once the
  player taps MAKE CONTACT (recommended — the beat is the reward for tapping), and does the
  transition minigame still fire there?

### 3. Economy progress bar — Tim's catch

Tim: *"you would likely fly past 100% a while before you bought all the required flagships."*
Correct, and the study confirms it — at epoch 16 the money threshold is met **2.6 minutes**
before the gate opens. The bar (`Main._refresh_contact_progress` → `HeroStat.set_epoch_progress`)
currently tracks only `cash_earned_this_gen` against `consume_threshold`, so it would pin at
100% and sit there while the real requirement is still running.

**Recommendation: the bar shows the LEAST COMPLETE of the two requirements** — money
progress and flagship-units progress — so it reaches 100% exactly when the player can
actually advance, and never lies. That handles both regimes automatically without a mode
switch: early epochs are money-bound and it behaves as today; deep epochs are flagship-bound
and it tracks units. The readout should name whichever half is binding (e.g. "FLAGSHIP
21 / 35") so the number is actionable rather than mysterious.

Alternative considered: a two-segment bar showing both. Rejected as busier for no gain — the
player only ever needs to know what is currently blocking them.

### 4. Blocked-state UX — needs updating, currently would mislead

`Main._property_blocking_epoch_progress()` returns the index of the lowest un-owned property
and drives BOTH the pager's red dot and the one-time `epoch_blocked` coach card, anchoring
the card to that property's tab. With a unit-count gate, that anchor is wrong: every property
is owned and the blocker is a *quantity* on the flagship. It must return the flagship (and
the card copy must say how many units remain) whenever the roster is complete but the unit
requirement is not.

### 5. Saves

Forward-only, matching the precedent set by the ownership gate: a generation that has already
advanced past an epoch must never be retro-locked by the new requirement. The gate reads live
state (`units_owned`), so no save format change is needed — but a mid-run save sitting just
past a boundary must not be pulled backwards, and that needs an explicit check.

## Verification

- `MoneyTest` + `EpochTest` must stay green at the default (they do).
- `EpochPhaseStudy` re-run after any decay/`r0` change, since the knob is coupled to both.
- Device test is the real gate on the value of 35 — the sim's buyer allocates perfectly and
  buys the instant it can afford, so it compresses the tail harder than a human will. Treat
  34.3% as a lower bound on the stack share a real player feels.

## Sequencing (recommendation)

1. MAKE CONTACT + progress bar + blocked-state UX, with the gate still at its default of 1.
   All three are correct and shippable independently, and none of them change balance.
2. Then flip `epoch_flagship_units_required` to 35 as a single, isolated, revertible balance
   commit — after the banded-decay device verdict lands, so two economy changes are never
   being judged at once.
