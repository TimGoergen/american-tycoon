# Prestige Re-tune — "Reward Pushing a Run" (2026-07-23)

**Status:** APPLIED to `tuning.tres` on `feature/prestige-retune`, awaiting Tim's device pass.
**Tool:** `game/sim/PrestigeStudy.gd` (device-scale gem-yield + shop-cost tables).

## The problem
The Legacy yield curve `legacy_gain = floor(k × (estate_net / $1,000) ^ alpha)` was too flat at the
live `alpha = 0.22` (from the 2026-07-14 Option-C runaway fix). A 4-billion-fold range of run sizes
($23k → $100T) mapped to only ~1 → ~900 gems, so **out-earning a past run was barely rewarded** —
the opposite of the Idle-Slayer model ([[project-at-inspiration-idle-slayer]]) where a good run pays
off. (The "~2 gems first prestige" that started this was partly a sim-scale artifact: `Sim.gd`'s
180s/gen dynasty protocol only reaches toy ~$10M estates; device runs are 8+ orders of magnitude
bigger. `PrestigeStudy.gd` computes at real device scale.)

## The key finding (PrestigeStudy)
Steepening `alpha` decompresses the reward, and the runaway fear was overblown:
- **Reward for pushing** (gems per run): at `alpha 0.35`, a full Earth run mints **~830 gems** vs
  108 today; the endgame mints ~320k vs ~4.6k.
- **Single-prestige income is never explosive**: spending a run's *entire* gem yield on Family
  Fortune (the ×1.20/level compounder) reaches only ~2.5× at Earth, ~12.8× at the full endgame —
  far below the ×237 cap.
- **The real brake is the geometric shop cost, not the flat yield.** The five max-level-30 ×2
  compounders' top level costs **~9.7 billion gems** (~19.3B to max) under the new ×3 multiplier —
  ~30,000 endgame runs away, an "endless chase" never reached. Reachable spending lives in the
  low-to-mid levels; the deep end is aspirational by construction.

## Applied (candidate C)
| knob | old | new |
|---|---|---|
| `alpha_legacy` | 0.22 | **0.35** |
| `k_legacy` | 0.50 | **0.16** |
| `legacy_upgrade_cost_multiplier` | 2.0 | **3.0** |

Net effect: out-earning clearly pays (a bigger run = a bigger, satisfying gem haul), the low end
stays sane (a $1B run still ~14 gems; Trust Fund's first level is 3 gems), and the ×3 cost keeps the
richer yields from buying out the shop — the geometric cost is the robust runaway brake.

## Verification
`Sim.gd`: waterfall +18 Legacy at $800M net (was +9), dynasty + save round-trip PASS, juiced-heir
deep test ×4.3 income (down from ×5.2 — MORE controlled). No runaway.

## Still open / to watch on device
- The **cumulative multi-generation** growth (upgrades are permanent, stacking across prestiges) is
  what the single-prestige tables can't show — but the geometric cost bounds it too. Confirm the
  dynasty still paces well on device.
- Optional, independent: the max-level-30 compounders top out in the billions and are never reached.
  If a real "maxed it" moment is wanted, lower `max_level` (e.g. 30→18-20). Does not affect the
  reward-for-pushing goal; a separate call.
