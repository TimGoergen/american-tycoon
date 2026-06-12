# Tuning Change Log

Per M1 brief §5: every constant change made during hardware feel-testing is
logged here — these are the balance simulator's first calibration data.

| Date | Constant | Old | New | Reason |
|---|---|---|---|---|
| 2026-06-12 | rush_pct | 0.05 | 0.10 | Tim: rush impact per tap was visible but minimal; direct input should give a more visible boost. 10 taps now completes a cycle instead of 20. |
| 2026-06-12 | frenzy_burn_duration | 90.0 | 30.0 | Tim: frenzy should burn faster — a near-full bar was giving ~75s windows; max window is now 30s. |
| 2026-06-12 | frenzy_max_multiplier | 4.0 | 5.6 | Tim: frenzy boost should be 40% greater (4.0 × 1.4). Shorter, sharper spike instead of a long mild one. |
