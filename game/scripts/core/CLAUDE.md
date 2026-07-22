# core/ — headless game state & rules

Pure logic, **no scene tree** (nothing here touches Nodes or UI). Both the balance simulator (`sim/`) and
the UI (`scripts/Main.gd`) drive these classes, so the two can never drift on rules.

## State hierarchy
- **`DynastyState`** — the dynastic layer ABOVE a single life. Owns the current `GameState` (`current`),
  the Legacy wallet/upgrades (`LegacyUpgrades`), staff retention, generation count, `lifetime_cash_earned`,
  best-vent-streak, and ancestors. It wraps the whole save (`to_save_dict`/`load_save_dict`) and pushes
  purchased upgrade effects onto each generation via `_apply_upgrade_effects`.
- **`GameState`** — one generation's run. Owns `EconomyState`, `WageState`, `FrenzyState`, `RushMomentumState`,
  `EpochState`. `SAVE_VERSION` lives here; a mismatched version loads with a warning (non-fatal). To add a
  persisted field: append it in `to_save_dict()`, read it back with a defaulted `data.get(...)`, and bump `SAVE_VERSION`.
- **`EconomyState` / `PropertyState`** — the 52-property ladder; unit costs via `CostCurve`; income multipliers.

## Patterns & gotchas
- **Global multipliers must apply exactly ONCE.** Property income = Family Fortune
  (`LegacyUpgrades.property_income_multiplier`) surfaced through `DynastyState.get_legacy_income_multiplier()`.
  The passive tick reads that METHOD; the rush-collect path reads each property's `legacy_income_multiplier`
  FIELD, seeded from the same method. When adding a new global income/legacy multiplier, fold it into that
  single source so it lands once — never double, never miss (trace `tick()` / `_apply_upgrade_effects` / `get_draft_will`).
- **Stateless catalog configured from tuning.** Data+math tables are `class_name` statics whose `static var`
  config is pushed in from tuning by DynastyState (see `LegacyUpgradeCatalog.cost_multiplier`, `StaffRetention`).
  GOTCHA: DynastyState re-pushes that config on EVERY construction/load — so a sim wanting a custom value must
  set the TUNING field, not the static, or the next dynasty build overwrites it.
- **`EpochCatalog`** is the fixed table of the 6 alien epochs + per-property staffer rosters (a pure data table).
  **`ConfigLoader`** loads `tuning.tres` (+ optional user overrides) and the property `.tres` list.
  **`Money`** = big-number formatting/arithmetic. **`SaveManager`** = versioned JSON to `user://`.
- The estate waterfall grosses on **lifetime cash EARNED** (monotonic), not net worth.
