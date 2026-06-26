# Tuning Change Log

Per M1 brief §5: every constant change made during hardware feel-testing is
logged here — these are the balance simulator's first calibration data.

| Date | Constant | Old | New | Reason |
|---|---|---|---|---|
| 2026-06-12 | rush_pct | 0.05 | 0.10 | Tim: rush impact per tap was visible but minimal; direct input should give a more visible boost. 10 taps now completes a cycle instead of 20. |
| 2026-06-12 | frenzy_burn_duration | 90.0 | 30.0 | Tim: frenzy should burn faster — a near-full bar was giving ~75s windows; max window is now 30s. |
| 2026-06-12 | frenzy_max_multiplier | 4.0 | 5.6 | Tim: frenzy boost should be 40% greater (4.0 × 1.4). Shorter, sharper spike instead of a long mild one. |
| 2026-06-12 | hold_rush_per_second | — | 5.0 | New constant: holding the rush button auto-rushes at this rate (Tim requested hold-to-rush). |
| 2026-06-12 | frenzy_fill_hold_factor | — | 0.6 | New constant: held-rush pulses charge the frenzy meter at 60% of a real tap (Tim's spec). |

## 2026-06-13 — Property ladder magnitude rebalance

Tim: "each successive property type has an unsatisfying income; each new property
type should feel like it unlocks a new magnitude of values." Diagnosis: the old
ladder grew income/sec only ~2× per tier while base cost grew ~11×, so every new
property was ~5.5× *less* income-per-dollar than the last (a downgrade, not a
magnitude jump), and base cycle lengths ballooned to 2048 s (34 min) — high tiers
were nearly dead on unlock.

Rebalance (all 12 `config/properties/*.tres`, validated in the sim's new ladder
magnitude table):
- **income/sec per tier → ~5×** (Tim's choice) via re-tuned `base_income_per_unit`.
- **base_cost per tier → ~7×** (was ~11×): a gentle efficiency taper so each new
  tier is a real magnitude jump *and* still worth buying. Sim evidence: the greedy
  buyer now climbs to tier 11 in 10 min (was stalling at tier 5).
- **base_cycle_length tamed to a 0.4–60 s band** (was up to 2048 s) so a freshly
  bought high tier is alive within a minute; milestones still speed it up.
- ATM (tier 1) unchanged (50 cost, 5 income, 0.4 s).

Note for later: this makes the single-generation economy much hotter (the dynasty
sim blows past the $103.6T Earth target within a few generations). That is the
prestige constants' job to calibrate (`k_legacy`, `k_sprint`, etc. — all still
TBD-SIM placeholders), not the property ladder's. Flag for a prestige tuning pass.

## 2026-06-15 — Prestige/Legacy constant pass (Step 1 of 2)

Goal (Tim's three criteria, modeled on Idle Slayer's prestige feel): every reset
scales up; first prestige funds 1–2 felt-but-safe upgrades (target 10–16 Legacy);
always another upgrade to chase. This step tunes the estate→Legacy *conversion*;
the catalog-ceiling work (criterion 3) is Step 2.

| Date | Constant | Old | New | Reason |
|---|---|---|---|---|
| 2026-06-15 | k_legacy | 0.01 | 0.005 | Solve gen-1 yield to Tim's 10–16 target. Sim gen-1 net $5.5M → +11 Legacy (was +4). |
| 2026-06-15 | alpha_legacy | 0.4 | 0.5 | Un-flatten the curve so bigger runs pay off visibly (criterion 1). ×10 cash now → ×3.16 Legacy (was ×2.5). |

Sim evidence (6-gen dynasty, after change): first-prestige Legacy 11; per-succession
Legacy now 11/13/29/44/88/123 (was 4/4/8/8/10/14); lifetime cash earned climbs every
generation (12.1M→911.5M) instead of flat-stepping. Residual gen-6 wobble (+2.2s) is
mostly the sim's cheapest-first greedy buyer plus the still-unraised catalog ceilings.

## 2026-06-15 — Prestige catalog: compounding accelerators + raised caps (Step 2 of 2)

Criterion 3 ("always another upgrade to chase that has meaningful feel") can't be solved
by the conversion constants — it's the catalog. Two coupled changes (Tim chose the
compounding model over additive-with-raised-caps):

- **Effect model → compounding** for the three core accelerators (Family Fortune income,
  Efficiency cycle speed, Connections wage). `LegacyUpgrades` getters now apply
  `(1 + effect_per_level) ^ level` instead of `1 + effect_per_level × level`, so every
  level is the same RELATIVE jump no matter how deep — the Idle-Slayer feel. The other
  three upgrades stay additive on purpose (compounding a discount → free hiring;
  compounding the Legacy-yield → runaway loop).
- **Caps raised 8–12 → 30** on those three lines (effectively endless; geometric
  `cost_growth` is the real brake, so there's always a meaningful next level).
- `describe_effect` updated so the three compounding cards show their true total
  multiplier ("×6.19 property income") instead of a now-wrong additive percentage.

Sim evidence (6-gen dynasty, after Steps 1+2): time-to-founder-peak now strictly shrinks
every generation — 176 → 116 → 106 → 70.8 → 60.9 s (the earlier gen-6 wobble is gone);
property income mult compounds 1.00→1.20→1.44→1.73; lifetime cash earned climbs and
accelerates 12.1M → 84.8M → 865.9M → 3.1B; first prestige still 11 Legacy. Save
round-trip PASS, no script errors. Economy stays well under the $103.6T Earth target over
6 gens (no compounding runaway). Still first-pass values for on-device feel-tuning.


## 2026-06-25 — Back-tier cycle stretch, second pass (top → ~4.5 min)

The 2026-06-22 rework took the back half (tiers 7–12) to a 180s (3 min) top at ~1.5×/tier.
Tim asked to push the top further into the roadmap's stated 3–5 min ceiling. Raised the
back-half ratio to ~1.6×/tier so the change concentrates at the top:

| Tier | Property | Cycle old → new | base_income_per_unit old → new |
|---|---|---|---|
| 7 | Day Trading | 24 → 26 | 3,333,333 → 3,611,111 |
| 8 | Flipping Houses | 36 → 41 | 24,242,424 → 27,609,427 |
| 9 | Multi Level Marketing | 54 → 66 | 200,000,000 → 244,444,444 |
| 10 | Hedge Fund | 81 → 106 | 1,500,000,000 → 1,962,962,963 |
| 11 | Legislative Assets | 121 → 170 | 10,755,555,556 → 15,111,111,252 |
| 12 | Executive Assets | 180 → 272 | 88,888,888,889 → 134,320,987,654 |

**Income-neutral** (same discipline as the first pass): each tier's `base_income_per_unit`
was scaled by the same factor as its `base_cycle_length`, so per-unit income/sec is
unchanged to display precision (e.g. tier 12: 134,320,987,654 / 272 = 88,888,888,889 / 180
= $493.8M/s). Only the cadence gets chunkier — longer waits, fatter lump sums, and more
speed-up halvings before the 1s cycle floor. Tiers 1–6 untouched.

Sim evidence (6-gen dynasty): dynasty still "speeds up every time" — 179.9 → 166.4 →
166.4 → 134.5 → 120.3 s to the founder's peak; waterfall spot-check and save round-trip
PASS; no script errors. As expected for an income-neutral change, economy magnitudes are
unmoved. First-pass ceiling — on-device feel-test will say whether 4.5 min is the sweet
spot or it wants 4 / 5 min.
