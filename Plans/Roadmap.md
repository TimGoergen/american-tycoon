# Roadmap — logged future ideas (not scheduled)

A running capture doc for feature ideas Tim wants on the record before they have a plan.
One section per idea: Tim's ask, a short design take, and any load-bearing facts a future
implementer needs. When an idea graduates, it gets its own `Plans/` doc and this entry
points to it.

## 1. "MAX" buy mode for properties, unlocked by a Legacy upgrade (Tim, 2026-07-29)

**Take:** the QoL-as-prestige-reward pattern is exactly Idle Slayer's and fits the shop's
new uncapped structure — but this specific one collides with shipped behavior: **property
buy-MAX already exists, free, and is the DEFAULT buy mode** (`ui_buy_mode` 3 = MAX since
2026-06-23, "a fresh game should start in buy-max" — Tim's own call). Gating it now is a
take-away, not a gift. Options when this graduates: (a) revisit the default (start new
dynasties on ×1 and sell MAX as the upgrade — a real early-game rebalance, not a UI
tweak), or (b) keep MAX free and gate something above it (e.g. "MAX across the whole
tab/epoch in one tap"). Decide deliberately; don't ship the collision.

## 2. "MAX" hire mode for staffers, unlocked by a Legacy upgrade (Tim, 2026-07-29)

**Take:** clean fit, no collisions — staff levels today only have hold-to-repeat
(`hire_hold_*`), so a "buy to cap / buy N levels" mode is genuinely new value, and deep
runs (20-level blocks × 27 epochs) genuinely need it. Natural shape: a utility-family
Legacy track ("Head Hunters"?) whose levels unlock ×10 → block → MAX hire modes.

## 3. "MAX" mode for staffer retention — and maybe all upgrades — via Legacy upgrade (Tim, 2026-07-29)

**Take:** this IS the queued "staff-retention bulk-buy UX" item (Tim, 2026-07-28: "way
too many buttons to press"), upgraded from a UX fix to a prestige reward — better framing,
same work. One caution: retention is bought with the SAME currency (gems) that would buy
the unlock, and it's the endgame's open sink — a MAX button on it needs a spend-preview
("retain everything: 4.2B gems") so one tap can't silently drain a fortune. For "all
upgrades": the uncapped compounders have no MAX by design; a "buy 10 levels" repeat is
the right verb there instead.

## 4. More QoL-via-Legacy candidates (Tim, 2026-07-29 — wants this area explored)

Grounded candidates, each removing friction that exists today (not power — power is the
compounders' job). All fit the utility-track family (capped, additive, restructured 2026-07-28):

- **Auto-restart idle cycles** — unstaffed properties stop after each payout and need
  re-tapping; a capped track that auto-restarts the top N unstaffed properties.
- **Extended offline window** — `offline_cap_seconds` is 4h; levels push it to 8/12/24h.
  (Classic idle-genre Legacy purchase; pairs with the welcome-back minigame.)
- **Deeper ladder peek** — show the next 2/3/4 locked rungs' prices instead of one peek
  rung, for save-up planning in the escalating cohorts.
- **Auto-pop TURBO** — frenzy fires itself at full charge (opt-in toggle once bought);
  respects the "minigames are a player setting" philosophy of choice-not-chore.
- **Epoch-arrival auto-buy** — on contact, automatically buy 1 of each newly-unlocked
  cohort property if affordable (the ownership gate's grunt work, automated).
- **Faster hold-to-repeat rates** — buy/hire hold cadence scaled by a track (the knobs
  already exist per-action in tuning).

## 5. Challenge Mode gated until after the first prestige (Tim, 2026-07-29)

**Take:** good sequencing and cheap to build — it guarantees the minigames are first
experienced in their real context (transitions, with stakes) before free play, and it
matches the progressive-unlock philosophy already shipped (Estate/Ledger tabs). Gate
signal: `dynasty.ancestors.size() > 0` (the Ledger's own "first prestige happened"
signal). Per the no-moving-UI rule, the Settings → CHALLENGES button grays in place with
a "unlocks after your first succession" subtitle, never hides. Small enough to ship in
any session on Tim's word.
