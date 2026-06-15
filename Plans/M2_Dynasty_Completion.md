# M2 — The Dynasty: Completion Plan

> **First action on approval:** copy this file to `D:\Claude\American Tycoon\Plans\M2_Dynasty_Completion.md`
> (Tim's rule: AT plans live in a `Plans` folder at the project root).

> **STATUS UPDATE (2026-06-15).** Phase 0 (lifetime-cash basis) and Track A
> (obituary + Family Ledger) are **built, verified, and kept** — on
> `feature/lifetime-cash-basis` and `feature/ceremony-and-ledger`, ready for
> `release`. **Track B (Credit & Class — origins, debt, bankruptcy, loan offers,
> mail) is SHELVED** at Tim's call: early-game cash influx flattens the opening
> grind. The founder starts at $0; the credit/class system is expected to return as
> a **post-prestige** mechanic (options for accelerated heirs, not the founder). The
> full Track B implementation is preserved, unmerged, on the `shelved/credit-and-class`
> branch for resurrection. See GDD §8 for the design of record.

## Context

American Tycoon's M2 ("The Dynasty", GDD §13) is mostly built: death + estate
waterfall (`EstateWaterfall.gd`), the Reading of the Will + heir reveal
(`WillScreen.gd`), estate tax, the Legacy currency + Estate Office shop + 6
upgrades, the heir-name generator (`HeirNames.gd`), and the full succession flow
in `Main.gd`. "Speeds up every time" is already verified in the sim.

What M2 still lacks per GDD §13 / Mechanics Spec §8–9: **origins**, **debt &
bankruptcy**, **loan offers**, the **Family Ledger**, the **obituary beat**, and
the **lifetime-cash-earned estate basis** Tim resolved on 2026-06-14 (GDD commit
b8d279d, marked "M2-later"). This phase builds all of it — the full M2 remainder —
bringing M2 to its exit criterion. Decisions confirmed with Tim: finish M2, do the
whole remainder, include the cash-basis swap.

The work splits into a **foundational swap** (lands first; everything else builds
on it) and two largely independent tracks suitable for parallel agents:
**Credit & Class** (origins, debt, offers, mail) and **Ceremony & Ledger**
(obituary, Family Ledger).

## Branching

Per `project-branching-strategy`: cut feature branches off `release`, delete after
merge. Suggested branches:
- `feature/lifetime-cash-basis` (foundational, lands first)
- `feature/credit-and-class`
- `feature/ceremony-and-ledger`

**Loose end (Tim's call):** today's GDD design-decision commits and recent UI
polish sit only on `feature/ui-refinements`, not in `release`. Worth merging that
to `release` so the M2 branches (and the shipped build) reflect the current design.
Not part of this plan unless Tim wants it folded in.

---

## Phase 0 — Foundational: lifetime-cash-earned estate basis

The estate waterfall currently grosses on `EconomyState.get_net_worth()` (cash +
book value). Mechanics Spec §9.1 now specifies `estate_gross = cash_earned_this_gen`.
This is foundational because the obituary headline and the Family Ledger career
stat both read the new accumulators, and the debt/bankruptcy path plugs into the
same waterfall.

**`EconomyState.gd`**
- Add `var cash_earned_this_gen: float = 0.0` — monotonic; only ever increases.
- Increment it from *earned* dollars only — property income in `tick()`, and wage
  taps (see GameState). Do **not** count granted money: loan principal, birth seed
  cash, or windfall gifts. To keep the earned/granted distinction explicit, leave
  `award_cash()` as the "granted" path and add the earned increments at the points
  income is actually produced (property `tick`, wage tap, offline apply).
- Offline pile counts as earned (it is property income while away): have
  `OfflineCalculator.apply` add the banked amount to `cash_earned_this_gen`, or add
  it where the result is applied in `GameState.apply_offline`.

**`GameState.gd`**
- In `tap_wage()` / `hold_tap_wage()`, add the earned wage to
  `economy.cash_earned_this_gen` (the wage is earned money).
- Save: bump `SAVE_VERSION` 3 → 4; persist `cash_earned_this_gen`. Older saves
  default it to `0.0` (or seed from `total_income` as a best-effort backfill —
  decide in implementation; 0.0 is safe and simplest).

**`DynastyState.gd`**
- Add `var lifetime_cash_earned: float = 0.0` — the cross-generation, never-reset
  accumulator (GDD §8.3 obituary headline, §8.2 Family Ledger career stat).
- In `perform_succession()`, before replacing `current`, add
  `current.economy.cash_earned_this_gen` to `lifetime_cash_earned`.
- In `get_draft_will()`, set `estate_gross = current.economy.cash_earned_this_gen`
  (replacing `get_net_worth()`). Per Spec §9, the rest of the waterfall is
  unchanged. Remove the `built_estate = estate_net - starting_cash` seed-exclusion
  hack: seed cash is granted, so it was never in the new gross; convert Legacy from
  `estate_net` directly (Estate Lawyers multiplier still applies).
- Persist `lifetime_cash_earned` in `to_save_dict` / `load_save_dict`.

**Tuning note (TBD-SIM):** changing the gross magnitude means `k_legacy` /
`alpha_legacy` need re-calibration. Re-run the sim and adjust in `tuning.tres`;
log the change in `claude/tuning-log.md`.

**`sim/Sim.gd`**: update the multi-generation protocol to exercise the new basis
and re-confirm "speeds up every time" still holds; report time-to-founder-peak per
generation as before.

---

## Phase 1 — Track A: Death Ceremony & Ledger

### A1. Obituary beat (GDD §8.3 beat 1)

Add a **Phase 0** to `WillScreen.gd` (it already manages a phased in-place overlay,
so a third phase keeps the ceremony in one place). Order becomes: obituary → will →
heir reveal.

- New `show_obituary(stats: Dictionary)` + a `_build_phase0()` builder and a
  `continue_to_will` signal.
- Content from the dying generation's real stats: dynasty name + Roman numeral,
  a deadpan life summary, and the **headline = `cash_earned_this_gen`** (this
  generation's lifetime earnings, the §8.3 figure — not net worth at death).
  Supporting deadpan lines: employees (count of staffed properties), "grew the
  family fortune from $X to $Y" (seed → cash_earned), "Hours worked: 0" gag.
- `Main.gd`: the prestige flow becomes `show_obituary → continue_to_will →
  show_will → pass_on_confirmed → show_heir_reveal`. Pass the dying generation's
  stats into the obituary before `perform_succession()` clears them.

### A2. Family Ledger (GDD §8.2)

- `DynastyState.gd`: add `var ancestors: Array = []`. In `perform_succession()`,
  append a record before raising the heir:
  `{ name, generation, fortune (cash_earned_this_gen), cause }`. `cause` is
  `"Retired to Palm Beach"` for a normal succession; the bankruptcy path
  (Track B) passes `"Creditors"`. Persist `ancestors` in the save dict.
- New `scripts/ui/FamilyLedgerScreen.gd` — a scrollable list of ancestor rows in
  the annual-report register (reuse `UiPalette` + `WillScreen`'s
  `_add_document_row` pattern; large text per `feedback-ui-readability`).
- `Main.gd`: a button to open it (alongside the Estate Office button); freeze ticks
  while open, matching the existing overlay pattern in `_process`.

---

## Phase 2 — Track B: Credit & Class

### B0. Mail (shared infra, Spec §10 delivery rule)

Offers and payment-due notices arrive as **mail** (never push, never nag). Minimal
M2 surface: a lightweight `scripts/ui/MailScreen.gd` (an inbox list) plus a small
"you have mail" indicator on Main. Items expire silently if ignored. Keep it simple
— this is the delivery channel both offers and debt notices use.

### B1. Origins (GDD §8.1, Spec §8)

- New `scripts/ui/OriginScreen.gd` — the opening "Do you have rich parents?" with
  four paths → (starting cash, initial debt):
  No → $1,000 / $0 · Yes-gift → $50,000 / $0 · Interest-free → $200,000 debt ·
  High-interest → $500,000 debt.
- Shown once, only on a brand-new dynasty (generation 1, no save). `DynastyState`
  accepts the chosen origin (seed cash + seeds the initial debt schedule) and
  records that the choice was made so it never re-shows.
- `Main.gd`: present `OriginScreen` before normal play when starting fresh.
- (Achievement "Bootstrapped" is out of scope — achievements are a separate pass.)

### B2. Debt & bankruptcy (Spec §8, §9.2)

- New `scripts/core/DebtState.gd` (per generation, headless): `outstanding_balance`
  + an ordered list of scheduled payments, each `{ trigger, amount }` where trigger
  is `net_worth >= X` **or** `income_per_sec >= Y` (milestone-triggered, never
  wall-clock — idle must never be punished). Tracks the active grace window.
- Wire into the tick loop (via `GameState`/`DynastyState`): when a trigger fires
  during active play, the payment is **due** → delivered as mail with a grace
  window of active play time; UI shows the next trigger transparently.
- Replace the hardcoded `outstanding_debt = 0.0` in `DynastyState.get_draft_will()`
  with the live `DebtState.outstanding_balance` (the waterfall already accepts it).
- **Miss = forced generation end (bankruptcy):** creditors seize
  `min(estate, outstanding_balance)` before tax; almost nothing converts to Legacy;
  succession proceeds with `cause = "Creditors"` (feeds the Family Ledger). Add a
  `perform_bankruptcy_succession()` path (or a flag on `perform_succession`).
- Persist `DebtState` inside the generation's save block.

### B3. Loan offers (Spec §8, §11)

- New resource `scripts/resources/LoanTier.gd` (`extends Resource`, same pattern as
  `PropertyConfig`/`TitleRow`): `{ eligibility_min, eligibility_max (net-worth
  band), principal, payment_schedule, flavor }`. Data table in
  `config/loans/*.tres` (or a single table resource) loaded by `ConfigLoader`.
- New `scripts/core/OfferSystem.gd`: rolls an eligible offer at generation start and
  on band promotion; **one active loan max**; terms improve with band
  (payday → prime → bailout). Offers arrive as mail; expire silently if ignored.
- Accepting adds principal to cash (granted, **not** earned — does not touch
  `cash_earned_this_gen`) and installs the payment schedule into `DebtState`.

### B-sim

`sim/Sim.gd`: drive an origin choice, accept/repay a loan across a generation, and
exercise the bankruptcy path so the waterfall + Legacy math are validated under
debt and under a missed payment.

---

## New tuning constants (`TuningConfig.gd` + `tuning.tres`)

- Origin path payouts/debts (or hard-code in `OriginScreen` — but tuning.tres is the
  established home for numbers).
- Debt grace-window length; offer cadence; loan-tier band thresholds (or in the
  loan data table). Mark new economy constants `# TBD-SIM`.

## File summary

**Modify:** `EconomyState.gd`, `GameState.gd`, `DynastyState.gd`, `WillScreen.gd`,
`Main.gd`, `TuningConfig.gd`, `config/tuning.tres`, `OfflineCalculator.gd`,
`sim/Sim.gd`, `claude/tuning-log.md`.
**Add:** `scripts/ui/FamilyLedgerScreen.gd`, `scripts/ui/OriginScreen.gd`,
`scripts/ui/MailScreen.gd`, `scripts/core/DebtState.gd`,
`scripts/core/OfferSystem.gd`, `scripts/resources/LoanTier.gd`,
`config/loans/*.tres`.

## Parallelization (per CLAUDE.md)

Phase 0 lands first, solo — it sets the data model and succession signature both
tracks extend. Then Track A and Track B run as parallel agents. The one contention
point is `DynastyState` (both tracks add succession behavior: ancestors record vs.
bankruptcy path) — give each agent a clearly scoped edit region there, or land
Track B's succession change first and rebase Track A on it.

## Verification

- **Headless first (Tim's standard):** parse-check changed scripts; boot the project
  headless; run `sim/Sim.gd` across ≥6 generations and confirm (a) the per-generation
  time-to-founder-peak still shrinks ("speeds up every time", M2 exit criterion),
  (b) the waterfall grosses on `cash_earned_this_gen`, (c) a missed payment forces a
  bankruptcy generation-end with creditors seizing first and ~0 Legacy, (d) accepting
  an offer adds principal without inflating `cash_earned_this_gen`.
- **In-app:** start a fresh dynasty → origin screen appears and seeds cash/debt;
  play to a debt trigger → mail arrives, pay within grace; deliberately miss →
  bankruptcy obituary, cause "Creditors" in the Family Ledger; normal death →
  obituary headline = lifetime earned, will math correct, ancestor appears in the
  Ledger with "Retired to Palm Beach".
- Re-tune `k_legacy`/`alpha_legacy` against the sim and log every constant change in
  `claude/tuning-log.md`.

## Open items to confirm during build
- Whether "earned" tracks wage vs. capital gains separately for the Ledger (GDD §11
  wants the split eventually) or a single combined accumulator now (plan assumes
  combined; split is a small later add).
- Old-save backfill for `cash_earned_this_gen`: `0.0` vs. seed from `total_income`.
