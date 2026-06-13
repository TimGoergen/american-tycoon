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
