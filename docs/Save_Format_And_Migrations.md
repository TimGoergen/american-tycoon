# Save format and migrations

**Current `SAVE_VERSION`: 13** (`game/scripts/core/GameState.gd`).

This is the account of what each version changed and what code still migrates from it. Without it,
answering "why did this old save load wrong?" means reading three files and guessing at git history —
which is exactly the situation this document exists to end.

## The shape of a save

One JSON dictionary, written by `SaveManager` to `user://`. Two nested levels:

- **`DynastyState.to_save_dict()`** — the bloodline: ancestors, the Legacy wallet and purchased
  upgrade levels, staff retention, challenge high tiers, and the met-minigame set. It holds the
  living generation under `"current"`.
- **`GameState.to_save_dict()`** (that `"current"` value) — one lifetime: cash, properties, epoch
  tier, the wage ladder, and every `ui_` player preference.

A legacy bare-generation save has no `"current"` — the loader treats the top level as the generation.

## When to bump `SAVE_VERSION`

**Only when an existing key changes meaning or an old save would load WRONG.** Adding a key that
defaults sensibly when absent does not need a bump — that precedent was set by `ui_currency_format`
(2026-08-05) and followed by the met-minigame set and the three audio settings.

> `game/scripts/core/CLAUDE.md` still states an older always-bump rule. The additive-key exception
> above is the practice actually followed since 2026-08-05.

## Version history

| Version | Shipped in | What changed | Migration still in code |
|---|---|---|---|
| 1–4 | pre-2026-06 | Original format; the Legacy wallet was accumulate-only (`legacy_total`) | `DynastyState.load_save_dict` maps `legacy_total` into the spendable wallet |
| **5** | `965c505` Clock-in numeric ladder | Named job titles became a numeric wage ladder. Pre-v5 saves have no `epoch_tier` and default to Earth | Defaulting only |
| **8** | `0b97621` Epoch-depth Phase 1 | One sequential staff ladder with per-epoch blocks, replacing `staff_tier` | `GameState.load_save_dict`: `version <= 8 or sp.has("staff_tier")` folds the old tier into `staff_level`, **clamped** to the blocks the reached epoch had opened |
| **9** | `00df27c` Statistics screen | Best Vent Streak persisted | Defaulting only |
| **11** | — | (intermediate) | — |
| **12** | `8ca5677` Earth split | Earth became TWO epochs, so every alien tier shifts +1 | `GameState.load_save_dict`: `version <= 11` adds 1 to any `epoch_tier >= 2`; a tier-1 save becomes White Collar **only if it already owns a White Collar property**, otherwise it stays Blue Collar and earns the promotion beat like a fresh run |
| **13** | `bd35f52` Endgame Economy | The six capped utility tracks doubled their level counts at half the per-level effect | `DynastyState.load_save_dict`: `save_version <= 12` maps owned levels **BY EFFECT** — a pre-v13 level becomes twice the level number, granting the same total bonus the player bought |

## The three rules these migrations follow

**Migrate by EFFECT, never by raw number.** The v13 utility restructure doubled level counts and
halved per-level effect; mapping level 4 to level 4 would have silently halved what a player owned.
Mapping it to level 8 preserves what they actually bought.

**A migration may be generous, never punitive.** The v8 staff mapping is approximate — old blocks
counted 20 levels *plus* a hire, v9 blocks count 20 *including* it — so a full block gains one level.
That one-level generosity was accepted deliberately for a one-time migration.

**Prefer evidence in the save over a default.** The v12 Earth split could not tell whether a tier-1
save belonged in Blue or White Collar, so it asks the save: does it own a White Collar property? The
same instinct seeded the met-minigame set from `challenge_highest_tiers` rather than starting empty,
which is what stopped an existing player finding every Challenge cabinet locked.

## Testing

`EpochTest` is the migration gate — it covers the 27-tier ladder and the v12 tier shift.
`AudioSettingsTest` covers the whole `ui_` preference surface generically: **every preference that
survives a save must also survive a succession.** That assertion is written against the property list
rather than a fixed set of fields, so a preference added later is covered without editing the test.

That generic form exists because the bug class is real and recurring: `DynastyState._new_generation`
builds a brand-new `GameState`, so any player CHOICE parked there silently reverts every prestige
unless `_carry_player_settings_to_heir` copies it. `ui_buy_mode` and `ui_minigame_enabled` dropped
that way for months before it was caught.

**Adding a preference means touching three places**: the field on `GameState`, `to_save_dict` /
`load_save_dict`, and `_carry_player_settings_to_heir`. Miss the third and it works perfectly until
the player prestiges.
