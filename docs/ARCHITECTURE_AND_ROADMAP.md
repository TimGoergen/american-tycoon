# American Tycoon — Architecture & Roadmap

**Snapshot: 2026-08-10**, taken from the working tree at `527eef6` on `main`.

This is the orientation document for the codebase: what the pieces are, how they talk to each other,
what is built versus still designed-only, where the sharp edges are, and how art, audio, and builds
actually get made. It is a *snapshot* — it describes the code as it stands, not as it was planned.
Where the code and a canon document disagree, that disagreement is called out rather than smoothed
over, because those gaps are the ones that cost a session.

**It does not replace canon.** The GDD is authority on design intent, the Mechanics Spec on math,
`docs/PROJECT_GUIDELINES.md` on conventions. This document is authority on *what currently exists*.

---

## Contents

1. [System Architecture & Node Relationships](#1-system-architecture--node-relationships)
2. [Roadmap — Completed vs. Pending](#2-roadmap--completed-vs-pending)
3. [Known Quirks, Bugs & Technical Debt](#3-known-quirks-bugs--technical-debt)
4. [Asset Pipeline & Build Workflows](#4-asset-pipeline--build-workflows)

---

## 1. System Architecture & Node Relationships

### 1.1 The layering

The architecture has one organizing rule, inherited from the M1 brief's "simulator-ready
architecture" requirement, and everything else follows from it:

> **Game logic must run headless. Nothing in `scripts/core/` may touch the scene tree.**

That single constraint is why the balance simulator and the game can never disagree about the rules —
they instantiate the *same* classes and read the *same* config. It is also why `core/` has no
`Node`, no `@onready`, and no signals-to-UI in the conventional Godot sense.

```
                    ┌──────────────────────────────────────────┐
   config/          │  tuning.tres  +  properties/NN_*.tres    │   326 property resources
   (data)           │           (the only tunable numbers)      │   + 1 tuning resource
                    └───────────────────┬──────────────────────┘
                                        │  ConfigLoader.load_tuning() / load_properties()
                                        ▼
   scripts/core/    ┌──────────────────────────────────────────┐
   (headless)       │  DynastyState → GameState → EconomyState │   NO scene tree, NO Nodes
                    │  + static catalogs (EpochCatalog, …)     │   pure logic + rules
                    └───────┬──────────────────────┬───────────┘
                            │                      │
              drives        │                      │        drives
                            ▼                      ▼
   scripts/ui/      ┌───────────────┐      ┌───────────────┐   sim/
   (presentation)   │   Main.gd     │      │  Sim / gates  │   (headless SceneTree scripts)
                    │  + Controls   │      │  + studies    │
                    └───────┬───────┘      └───────────────┘
                            │
                            │ Audio.play_cue(...)   ← the ONE autoload
                            ▼
   scripts/audio/   ┌───────────────────────────────────────────┐
                    │  Audio.gd (autoload)  ·  Haptics.gd       │
                    └───────────────────────────────────────────┘
```

**On autoloads — the root `CLAUDE.md` is out of date.** It states "There are no autoloads." There is
exactly one: `Audio="*res://scripts/audio/Audio.gd"` in `project.godot`, added during the audio pass
(merged `1bd2511`, 2026-08-10). The *spirit* of the rule still holds — shared helpers are
`class_name` statics (`ConfigLoader`, `EpochCatalog`, `UiPalette`, `Money`, `SaveManager`,
`StafferFace`, `HeirNames`, `TutorialCatalog`) used directly, and `Audio` is the deliberate
exception because a sound system genuinely needs a persistent node with audio players on it. See
[§3.4](#34-documentation-drift) — and note that this exception is *why* sims cannot name `Audio`
directly ([§3.2](#32-the-headless-verification-quirks)).

### 1.2 The state object graph (`scripts/core/`)

State nests in exactly two levels, and the save format mirrors that nesting one-to-one.

```
DynastyState ......................... the BLOODLINE (survives death)
├── current: GameState ............... the living generation
├── LegacyUpgrades .................. the gem wallet + purchased upgrade levels
│   └── LegacyUpgradeCatalog ........ static table; config pushed in from tuning
├── StaffRetention .................. staff kept across a succession
├── ancestors[] ..................... prior generations (the Family Ledger's source)
├── lifetime_cash_earned ............ monotonic; the prestige basis
├── best_vent_streak ................ a dynasty-wide earned record
├── challenge_highest_tiers ......... arcade records, keyed by display_name()
└── met_minigames ................... the encountered-game set (dynasty-scoped)

GameState ("current") ................ ONE LIFETIME
├── EconomyState .................... the property ladder + cash
│   └── PropertyState[] ............. per-property: units, staff level, cycle, milestones
│       └── CostCurve ............... piecewise band ratios; exact-sum bulk pricing
├── WageState ....................... the numeric wage/title ladder
├── FrenzyState ..................... the TURBO one-bar state machine
├── RushMomentumState ............... heat / bands / vent windows / overheat
├── EpochState ...................... reached tier (1–27), contact readiness
├── AutoPurchaseState ............... the Acquisitions Desk's buying policy
├── ChallengeScores / ChallengeGoals  challenge ladders and reward tracks
├── TutorialProgress ................ which coach tips have fired
└── SAVE_VERSION = 13 ............... version lives here, not on DynastyState
```

**Where the important invariants live:**

- **Global multipliers must apply exactly once.** Property income is multiplied by Family Fortune
  (`LegacyUpgrades.property_income_multiplier`) surfaced through
  `DynastyState.get_legacy_income_multiplier()`. The passive tick reads that **method**; the
  rush-collect path reads each property's `legacy_income_multiplier` **field**, seeded from the same
  method. Two paths, one source. Any new global multiplier folds into that source — trace `tick()`,
  `_apply_upgrade_effects`, and `get_draft_will` before believing it lands once.
- **The estate waterfall grosses on lifetime cash *earned*** (monotonic), never net worth. This was
  the M2 Phase 0 foundational swap, and the obituary headline plus the Ledger career stats both read
  those accumulators.
- **Stateless catalogs, configured from tuning.** `LegacyUpgradeCatalog.cost_multiplier`,
  `StaffRetention`, and friends are `static var`s pushed in by `DynastyState`. It re-pushes on
  **every** construction and load — so a sim that wants a custom value must set the *tuning field*,
  never the static.
- **`EpochCatalog`** (3,467 lines) is a pure data table: the 27-tier ladder — Earth Blue Collar and
  White Collar, then 25 alien civilizations — plus per-property staffer rosters.

### 1.3 The scene tree — `Main.tscn` and what hangs off it

`Main.tscn` is the *only* scene. Every `Control` under it is **built in code** by `Main.gd`
(`_build_ui`, `_build_property_tab`, `_build_epoch_pager`, `_build_estate_tab`, `_build_settings_tab`,
`_build_tab_bar`) rather than authored in the editor. That is a deliberate trade: the layout lives
next to the logic that drives it and diffs as text, at the cost of not being visually editable.

```
Main (Control, scripts/Main.gd — 3,890 lines)
│
├── _background (TextureRect) .............. prairie → space → centered space, by epoch tier
├── _hero_stat (HeroStat) ................. income/sec ticket; stamp-pop on purchase
├── _first_contact_overlay (FirstContact…)  the civ banner under the hero stat
├── _frenzy_bar (FrenzyBar) ............... TURBO charge + pop
├── _momentum_bar (MomentumBar) ........... rush heat, bands, vent windows, auto-buy toggle
│
├── TAB 0 — Property
│   ├── epoch pager (label, ‹ ›, « », dots, MAKE CONTACT, next-badge)
│   └── ScrollContainer → PropertyRow × N ... ONE epoch tab's rows draw at a time
│       └── ManagerCircle → StafferFace ..... procedurally drawn portrait
├── TAB 1 — Estate  (_legacy_screen: LegacyScreen — the Estate Office shop)
├── TAB 2 — Ledger  (_ledger_screen: FamilyLedgerScreen)
├── TAB 3 — Settings (volume rows, Balance Tuning swap-in, HELP, CHALLENGES)
│
├── _wage_panel (WagePanel) ............... bottom, permanent
├── _tab_bar (4 icon tabs, bottom-pinned)
│
└── FULL-SCREEN MODALS (instantiated + add_child'd here, opened on demand)
    ├── _welcome_overlay (WelcomeBackOverlay)   the app ALWAYS opens here
    ├── _will_screen (WillScreen)               obituary → will → heir
    ├── _minigame_screen (MinigameScreen)       hosts all six minigame types
    ├── _minigame_review_screen, _challenges_screen
    ├── _about_screen, _stats_screen, _help_screen
    ├── _dev_panel (DevTuningPanel)             on-device balance editing
    ├── _first_contact / _new_ventures overlays
    └── _tutorial_tip (TutorialTip)             one instance, re-anchored per tip
```

**The epoch pager is the performance architecture.** 326 properties cannot all be live rows, so the
ladder is paged one epoch at a time (`tab = tier − 1`) with arrows, dots, and swipe. Only the visible
tab's rows exist and animate. `_epoch_tab` is persisted, because the Acquisitions Desk buys against
"the last civ tab you were on" even while you are in another tab.

**Frame budget split** (`Main._process`): logic advances on a fixed accumulator at `LOGIC_HZ`
regardless of frame rate (Unity's `FixedUpdate`, hand-rolled — Godot's `_process` has no fixed
variant), while rendering and UI refresh read state per frame. The income/sec readout deliberately
refreshes on its own 0.1s cadence so the number is legible instead of flickering 60×/second.

### 1.4 Signal relationships

`core/` emits only where a *rules* event needs announcing — everything else is a direct call, since
signalling within one tightly-coupled object is pure indirection.

| Emitter | Signals | Consumer |
| :--- | :--- | :--- |
| `EpochState` | `contact_made(new_tier)` | `Main` → background swap, civ banner, ceremony audio |
| `RushMomentumState` | `band_entered`, `vent_incoming`, `vent_window_opened`, `vent_lift_registered`, `vent_succeeded`, `vent_missed`, `overheated`, `rush_ready` | `MomentumBar` (paint), `Main` (audio, haptics, tutorial tips) |

That `RushMomentumState` cluster is the densest signal surface in the project, and it exists because
the overheat/vent model is a genuine state machine whose transitions drive sound, haptics, the bar,
and a tutorial tip independently.

**The UI's signal conventions**, uniformly applied:

- **Leaf → host, never host → leaf.** `PropertyRow` emits `buy_requested`, `tap_requested`,
  `hold_rush_requested`, `rush_hold_released`, `rush_pressed`, `rush_released`, `hire_requested` —
  all carrying `prop_index` — and `Main` handles them (`_on_buy_requested`, `_on_tap_requested`, …).
  A row never touches `GameState`. This is what keeps 2,227 lines of row presentation free of rules.
- **Every full-screen modal exposes `signal closed` + an `open()` method.** `AboutScreen`,
  `StatsScreen`, `HelpScreen`, `MinigameReviewScreen`, `ChallengesScreen`, `DevTuningPanel` all
  follow it. `Main` adds them to its `modal_up` set when they should freeze the economy.
- **`MomentumBar` paints what `Main` pushed it, never its own guess** — enforced by the
  `MomentumBarStateTest` gate.
- **Minigames are reward-agnostic.** `Minigame.gd` emits `completed(performance)` where performance
  is `[0,1]`, plus `banner_requested` and `challenge_time_penalty`. `MinigameScreen` maps performance
  to a multiplier and re-emits upward (`finished`, `legacy_bonus_earned`, `challenge_finished`,
  `minigame_met`). **A minigame must never know what the reward is** — that contract is what lets the
  same six games serve transitions, the arcade, and review mode.
- **`DevTuningPanel` requests, never applies.** It emits `apply_requested(overrides)`,
  `defaults_requested`, `reset_dynasty_requested`, `jump_epoch_requested`, `grant_legacy_requested`,
  `grant_cash_requested`; `Main` performs the mutation. A dev panel that wrote state directly would
  be a second, untested path into the economy.

### 1.5 File inventory by size

Useful for orientation, and for seeing where the 300-line convention has been left behind
([§3.3](#33-technical-debt)).

| Script | Lines | Role |
| :--- | ---: | :--- |
| `Main.gd` | 3,890 | The root screen; owns everything above |
| `core/EpochCatalog.gd` | 3,467 | 27-tier ladder + staffer rosters (pure data) |
| `ui/StafferFace.gd` | 3,464 | Procedural portrait generator, 27 tiers of treatment |
| `ui/MomentumBar.gd` | 2,293 | Rush/heat/vent bar |
| `ui/MinigameScreen.gd` | 2,277 | Reward-agnostic minigame host |
| `ui/PropertyRow.gd` | 2,227 | One property row |
| `ui/LegacyScreen.gd` | 1,069 | Estate Office shop |
| `ui/DevTuningPanel.gd` | 1,044 | On-device balance editor |
| `ui/BasketballMinigame.gd` | 1,040 | Micro Basketball |
| `ui/MatchThreeMinigame.gd` | 961 | Match Three presentation |
| `core/RushMomentumState.gd` | 958 | Heat model (rules) |
| `scripts/audio/Audio.gd` | 974 | Cue/loop banks, buses, voice pool |
| `core/GameState.gd` | 751 | One generation |
| `core/DynastyState.gd` | 641 | The bloodline |
| `resources/TuningConfig.gd` | 789 | 134 `@export` knobs |
| `core/EconomyState.gd` | 497 | Cash + ladder |
| `ui/UiPalette.gd` | 496 | The design system |

### 1.6 GDScript practices this codebase actually uses

`docs/PROJECT_GUIDELINES.md` states the *rules*. This section records the project-specific **idioms** —
the patterns a reader will meet in file after file and should imitate. They are load-bearing
architectural choices, not style preferences.

**Static `class_name` classes instead of singletons.** Shared helpers are `class_name` classes whose
members are `static`, called directly at the type: `ConfigLoader.load_tuning()`, `Money.display()`,
`UiPalette.style_button()`, `EpochCatalog.staffers_for()`, `StafferFace.draw_face()`. No instance, no
autoload, no `get_node`. This is what keeps `core/` headless — a static call works identically in a
sim and in the game. (Unity analogue: a `static class` of helpers, not a `MonoBehaviour` singleton.)

**Config over constants.** Any number that affects gameplay lives in `game/config/` and reaches the
code through `TuningConfig`'s 134 `@export` fields. A gameplay constant hardcoded in a `.gd` file
cannot be tuned on the device, which defeats the Balance Tuning panel — so the rule is absolute for
tunables. Structural constants (`INCOME_DISPLAY_INTERVAL`, `LOGIC_HZ`) stay in code, named and
unit-suffixed.

**UI built in code, not in the editor.** Every `Control` is constructed by a `_build_*` method rather
than authored in `Main.tscn`. The trade is deliberate: layout lives beside the logic that drives it
and diffs as reviewable text, at the cost of not being visually editable. A consequence worth
knowing — there is **one scene file** in the entire project.

**Fixed-timestep logic, per-frame presentation.** `Main._process` accumulates delta and advances game
logic at a fixed `LOGIC_HZ` regardless of frame rate; rendering only ever *reads* state. Godot has no
built-in `FixedUpdate`, so the accumulator is hand-rolled. Anything that must be frame-rate
independent belongs on the logic side of that split.

**Typed everything, at both ends.** Variables and signatures carry explicit types
(`var health: int = 100`, `func take_damage(amount: int) -> void`), including typed collections
(`const SKIN_TONES: Array[Color]`). This is not decoration — GDScript's static typing is what makes a
327-file project navigable and catches a whole class of error at parse time.

**Signals travel upward only.** A leaf emits, a host handles. `PropertyRow` never touches
`GameState`; it emits `buy_requested(prop_index, mode, source)` and lets `Main` act. This is why
2,227 lines of row presentation contain no rules, and why the same row works in a test harness.

**Seeded procedural generation over stored variants.** `StafferFace` derives every face from a seed
that folds in the generation, so nothing needs caching or baking and a manager stays stable across a
run. The same instinct appears in `HeirNames`.

**Comments carry the *why*, and often a date and a name.** The house style records the decision, not
the mechanism: `# Tim, 2026-07-31`, `# device-tuned`, `# fit: DynastyArcStudy`, `# TBD-SIM`. Those
markers are load-bearing — `Tuning_Record.md` reads them as the provenance system for all 134 knobs.

**Defaulted reads for save compatibility.** Persisted fields are always read back as
`data.get("key", default)` so an older save loads rather than crashing. See
`Save_Format_And_Migrations.md` for when this needs a `SAVE_VERSION` bump (it usually does not).

---

## 2. Roadmap — Completed vs. Pending

### 2.1 Milestone status against GDD §13

| Milestone | GDD exit criterion | Status |
| :--- | :--- | :--- |
| **M1 — The Slice** | Dopaminergic on real hardware; return-spike verified against a real 3-hour gap | ✅ **Complete** — shipped and long since superseded |
| **M2 — The Dynasty** | "Speeds up every time" across ≥5 generations | ⚠️ **Complete except Track B.** Death, obituary, will/heir, estate tax, Legacy shop, heir names, Family Ledger, lifetime-cash basis all shipped. **Origins, debt, bankruptcy, loan offers, and mail are SHELVED** on `shelved/credit-and-class` — Tim's call: early-game cash influx flattened the opening grind. Expected to return as a *post-prestige* mechanic for accelerated heirs |
| **M3 — The Theme** | "The game is *itself*" | ⚠️ **Mostly built.** Audio implementation done 2026-08-10 (assets still placeholder); epoch-keyed staffing UI, first-contact beat, welcome-back ritual, the Ledger, staffer portraits, tutorial/onboarding all shipped. **Outstanding: the art pass** (hero illustrations, backdrops beyond the five that exist), **narrator copy pass**, and **rare events** |
| **M4 — The Epoch** | Earth captured; first contact made | ⚠️ **Partially built.** Epoch progression well beyond the milestone's ask — 27 tiers, 25 alien civs, MAKE CONTACT as a deliberate player verb, the full endgame economy fitted by `DynastyArcStudy`. **Not built: the Earth target/percentage display and the Final Dollar sequence** (GDD §10) — `grep` finds no implementation of either |

The blunt read: the project has run *past* its milestone framing. M4's epoch content shipped while
M3's art pass and M2's credit track did not, so the M1–M4 ladder no longer describes the work
remaining. See [§3.4](#34-documentation-drift).

### 2.2 Systems shipped since the milestones stopped describing the work

Each of these has a plan doc in `Plans/` and is live in `main`:

| System | What it is |
| :--- | :--- |
| **Rush → Overheat → Vent Windows** | The push-your-luck heat model: bands, vent windows requiring N lifts, overheat, re-arm, cruise control. Gate: `RushOverheatTest` |
| **Epoch depth: 27 tiers** | Earth split into Blue/White Collar (2 epochs) + 25 alien civs, 326 properties |
| **MAKE CONTACT** | Epochs no longer auto-advance; leaving an era is a button press gated on owning 35 flagship units |
| **Legacy / Estate Office** | Gem wallet, capped utility tracks + uncapped compounders, restructured 2026-07-28, endgame curve fitted 2026-08 |
| **Acquisitions Desk** | Auto-purchase, 8 levels, page-scoped, buys the X least-expensive affordable properties. Rush locks out while on. Gate: `AutoPurchaseTest` |
| **Head Hunters** | Bulk hire: ×10 → BLOCK (to the 20-level boundary) → MAX |
| **Bulk staff retention** | Shipped ungated; the button's own label is the spend quote |
| **Minigame framework** | Six types (Match Three, Timing Bar, Catch the Money, Memory, Micro Basketball, Balance) behind one reward-agnostic host |
| **Challenge Mode** | The arcade: tier ladders, two reward tracks, gated behind the first prestige, and per-game gated on having *met* that game. Gate: `ChallengeGoalsTest` |
| **Audio system** | Cue/loop banks, buses, voice pool, pitching, ceremony beats, per-minigame vocabularies, era-band music. Gates: `AudioCoreTest`, `AudioSettingsTest` |
| **Staffer portraits** | Procedural, seeded, per-civ silhouettes. Gate: `PortraitSheet` (needs a renderer) |
| **Tutorial / onboarding** | Coach tips fired on first relevance, both verb-driven and polled |
| **Currency format setting** | Alphabet, abbreviation, and scientific modes — presentation only |
| **Family Ledger, Stats, About, Help** | The progressive-unlock tab set |
| **Balance Tuning dev panel** | On-device editing of all 134 knobs, embedded in the Settings tab |

### 2.3 Pending — captured, not scheduled

`Plans/Roadmap.md` is the capture doc. Five of its eight entries have graduated into their own plans
and shipped. **Live, ungraduated entries:**

| # | Idea | State |
| :--- | :--- | :--- |
| 1 | **"MAX" buy mode gated behind a Legacy upgrade** | ⚠️ **Blocked by a collision** — buy-MAX already exists, free, as the *default* buy mode (`ui_buy_mode` 3). Gating it now is a take-away. Needs a deliberate decision: rebalance the early game to start on ×1, or gate something above MAX instead |
| 4 | **QoL-via-Legacy candidates** | Six grounded ideas, none built: auto-restart idle cycles · extended offline window (4h → 8/12/24h) · deeper ladder peek · auto-pop TURBO · epoch-arrival auto-buy · faster hold-to-repeat rates |
| 6 | **Spelled-out-word currency format** (a 4th mode) | Logged, unbuilt. Rejected for the third slot because "$4.2 quattuorvigintillion" is 26 characters and cannot fit a price button at this game's font sizes. If ever built, the open question — everywhere vs. roomy readouts only — is the whole risk |

**Designed in canon but not implemented:**

- **Rare events** (GDD §9) — the tuning knobs exist and are wired into the dev panel
  (`crash_multiplier`, `crash_duration_minutes`, `audit_settle_rate`, `audit_threshold`, all
  `TBD-SIM`), but **no event system consumes them**. The knobs are a promise the code has not kept.
- **The Final Dollar / win condition** (GDD §10) — no implementation exists.
- **Earth target & percentage display** (M4) — not built.
- **Meta-tier upgrades**, the second-order prestige track (GDD §8.7) — proposed 2026-07-01, unbuilt.
- **Origins / debt / bankruptcy / loan offers / mail** — built and preserved on
  `shelved/credit-and-class`. `DynastyState` already threads `outstanding_debt` (hardcoded `0.0`)
  through the estate waterfall as a parameter, so the seam is open for its return.

---

## 3. Known Quirks, Bugs & Technical Debt

### 3.1 GDScript & Godot editor quirks

| Quirk | Consequence | Handling |
| :--- | :--- | :--- |
| **New `class_name` is not in the global class cache until a project import** | `--script` fails with *"Could not resolve external class"* | Run `<godot> --headless --editor --quit --path game` first |
| **That editor import rewrites `game/project.godot`** — reorders sections, strips comments | You ship churn you did not author | `git restore game/project.godot` afterward, every time |
| **`--check-only` on a single UI script reports false "identifier not declared"** for `class_name`/preload references | A clean script looks broken | `--check-only` alone is not authoritative. Editor import + a `--quit-after 90` boot is |
| **`tuning.tres` overrides `@export` defaults in `TuningConfig.gd`** | Changing a default silently does nothing if the `.tres` already carries a value | `grep tuning.tres` before assuming a default change ships |
| **`.import` files are gitignored** | Fine at defaults (CI regenerates identically); the moment you *change* a setting it exists only on your machine — works locally, ships without it | **Change an import setting → `git add -f` that `.import`.** All of `game/audio/` is force-added for this reason |

### 3.2 The headless-verification quirks

These bite in `sim/` specifically, and every one of them has cost a debugging session:

- **Autoload globals are not in scope under `--script`.** The script passed to `--script` compiles
  *before* autoloads register, so a sim cannot name `Audio` directly. Resolve it with
  `root.get_node_or_null(^"Audio")` **after awaiting a frame** — during `_initialize()` the root is
  not yet in the tree, so an absolute path errors. A scene instantiated later, like `Main.tscn`, uses
  the global name freely.
- **During `_initialize()` the root is not in the tree, so `add_child` does not run `_ready`.** Await
  a frame before touching anything a node builds there.
- **`ObjectDB instances leaked / resources still in use at exit`** is normal `SceneTree`-script
  teardown noise, not a failure.
- **Sims load baked defaults** (`ConfigLoader.load_tuning(false)`), never a device's user overrides —
  a study must measure the authored curve.
- **`DynastyState` re-pushes tuning into catalog statics on every construction.** Poking a
  `static var` directly to test a value is silently overwritten. Set the *tuning field*, then build.
- **`PortraitSheet` cannot run headless at all** — no framebuffer, so `get_image()` returns null. It
  needs `--rendering-driver opengl3`, opens a window for ~30s, and is opt-in via `run_gates.ps1 -All`.

### 3.3 UI rendering quirks

Each of these produced a bug that looked like something else entirely:

| Quirk | Symptom |
| :--- | :--- |
| `RichTextLabel` inside a `CanvasLayer` without `custom_minimum_size` + `AUTOWRAP_OFF` | Renders as stray pixels |
| `AUTOWRAP_WORD` + `OVERRUN_TRIM_ELLIPSIS` together | Min height collapses to ~1px — invisible text. Use autowrap alone |
| Markers over a framed `ProgressBar` positioned against the inset track | Sit 1–2px off the fill edge. Use `frac × width − inset`, the fill's own coordinates |
| Texture layout math without `get_used_rect()` | Transparent canvas padding throws off aspect ratios. Crop with `AtlasTexture` when an icon must fill its box |
| **Runtime `FileAccess` read of a `.svg` source** | **Crashed the device build** (opened → immediately minimized). Exported builds strip raw SVG source — load the *imported* texture. Desktop and boot checks do not catch this |
| Per-frame-polled state driving `stop()`/`play()` or tween rebuilds | Crashed a device. Audio state must be edge-driven, not polled |

### 3.4 Documentation drift

The code has moved past several documents that still speak in the present tense. Each of these is a
live trap for the next session:

| Where | Says | Actually |
| :--- | :--- | :--- |
| `CLAUDE.md` (root) | "There are **no** autoloads" | `Audio` is an autoload since 2026-08-10 |
| `CLAUDE.md` (root) | "**M1 Brief** — canon for the current milestone scope" | M1 shipped ~June 2026; the brief describes 12 Earth properties and one screen. It is history, not scope |
| `game/project.godot` | `config/description="Idle/tycoon — M1 The Slice"`, `config/version="0.0.0.0001"` | Version is stamped by CI at build time, so the committed value is cosmetic — but the description is simply wrong now |
| `scripts/core/CLAUDE.md` | Bump `SAVE_VERSION` for any new persisted field | Practice since 2026-08-05 is **additive keys that default sensibly do not need a bump** — set by `ui_currency_format`, followed by the met-minigame set and the audio settings. `docs/Save_Format_And_Migrations.md` flags this contradiction explicitly |
| GDD §13 milestones | M1→M4 as sequenced plateaus | M4 content shipped while M2's credit track and M3's art pass did not. The ladder no longer describes remaining work |

### 3.5 Technical debt

**File size.** The 300-line convention is comprehensively exceeded. `Main.gd` at 3,890 lines is the
one that matters most — it is the wiring hub for every verb in the game, and its `_build_*` methods
mean UI construction and event handling share a file. `EpochCatalog.gd` (3,467) and `StafferFace.gd`
(3,464) are less concerning: one is a data table and the other is a generator with 27 bespoke
treatments; both are long because their *content* is long, not because their structure is tangled.
`MomentumBar` (2,293), `MinigameScreen` (2,277), and `PropertyRow` (2,227) are the realistic
extraction candidates if a refactor is ever scheduled. **None of this is urgent** — but a newcomer
should know the convention and the reality differ by an order of magnitude.

**Unverified tuning — the two deviations.** `legacy_cost_steepening` ships at **1.10** (Tim seeded
1.03) and `alpha_legacy_deep` at **0.05** (Tim seeded 0.06). Both were forced by `DynastyArcStudy`
over five iterations — at 1.03 the dynasty summited at generation 3, at 1.12 it stalled dead at tier
25. **Neither has ever been judged on a device.** Tim confirmed the retune "feels really good in the
first 5 or 6 epochs," which validates the early bands — but the deep bands and the shop curve, which
is precisely what these two govern, remain unverified by play.

**`TBD-SIM` placeholders — 13 knobs never validated by a study or a device:**

| Area | Knobs |
| :--- | :--- |
| Core loop | `band_step` (1.1), `cycle_floor` (1.0), `rush_pct` (0.1) |
| Offline | `offline_efficiency` (0.5) |
| Estate | `estate_exemption_base`, `estate_tax_rate_base`, `loophole_rate_floor` |
| Rare events *(system unbuilt)* | `crash_multiplier`, `crash_duration_minutes`, `audit_settle_rate`, `audit_threshold` |
| Valuation | `EconomyState`'s holdings-valuation rule and net-worth definition are both documented as provisional |

**Recurring bug classes — the ones that have actually bitten:**

1. **The three-place preference bug.** `DynastyState._new_generation` builds a brand-new `GameState`,
   so any player choice parked there silently reverts on every prestige unless
   `_carry_player_settings_to_heir` copies it. `ui_buy_mode` and `ui_minigame_enabled` dropped that
   way for *months*. **Adding a preference means touching three places** — the field, the
   save/load pair, and the carry method. Miss the third and it works perfectly until the player
   prestiges. `AudioSettingsTest` now asserts this generically against the property list, so new
   preferences are covered without editing the test.
2. **Double-applied global multipliers** — see [§1.2](#12-the-state-object-graph-scriptscore).
3. **Partial gate runs.** On 2026-08-10 a full session's changes were verified against 9 of 12 gates,
   with two never run despite edits to the code they cover. `tools/run_gates.ps1` exists to make that
   impossible; it judges by **exit code**, never by scraping output, because the human-readable
   summary lines had already drifted (`MatchThreeTest` prints "ALL TESTS PASS", everything else
   prints "ALL CHECKS PASSED") — which is exactly how a grep-based runner misses a gate while
   appearing to pass.

**Repository hygiene (found 2026-08-10, all currently unfixed):**

- **95 phantom-modified `.import` files.** `git status` reports them modified; `git diff` produces
  **zero content hunks**. Cause: `core.autocrlf=true` globally, **no `.gitattributes` in the repo**,
  and Godot writes these files with LF. The next `git add -A` commits 95 meaningless line-ending
  changes that bury the following real diff. Fix and renormalize procedure in
  `DEVELOPMENT_WORKFLOW.md` §9.1.
- **One untracked `.uid`** — `game/sim/VentBonusStudy.gd.uid`, while 96 others are tracked.
- **`sim/CLAUDE.md` documents 27 scripts; there are 28.** `VentBonusStudy` appears in neither that
  inventory nor `run_gates.ps1`. It is a study, so its absence from the runner is correct; its
  absence from the inventory is the exact ambiguity that document exists to remove.

**Structural debt worth naming:**

- `sim/` holds 28 scripts of which 12 are gates; the other 16 are studies and one generator
  (`AudioCueDoc` *writes* `game/audio/README.md`). Nothing in the filenames distinguishes them —
  only `run_gates.ps1` and `sim/CLAUDE.md` do.
- `shelved/credit-and-class` is an unmerged branch carrying a complete feature. It will bit-rot
  against `main` for as long as it sits there; `DynastyState`'s `outstanding_debt` parameter is the
  seam that keeps its return cheap.
- **The MAX-buy collision** (Roadmap §1) is a design decision blocking an idea, recorded so nobody
  ships the take-away by accident.

---

## 4. Asset Pipeline & Build Workflows

### 4.1 Art

**"Assets are code."** The art is overwhelmingly **SVG source committed to the repo** and imported by
Godot — 46 SVGs against 5 PNGs and 2 JPGs.

| Folder | Contents |
| :--- | :--- |
| `game/art/icons/` | 38 SVGs — tab icons (active/inactive pairs), gems, coins, arrows, checkboxes, lock, gamepad, turbo, basketball, memory pads |
| `game/art/worlds/` | 6 SVGs — Earth plus five alien world glyphs |
| `game/art/backgrounds/` | prairie (Earth), space + centered space (post-contact), minigame, basketball court |
| `game/art/branding/` | the logo (also the app icon) |
| `game/art/ui/` | minigame button |
| `art concepts/` *(repo root, not in `game/`)* | AI-generated concept art — ChatGPT/Copilot/Gemini exports, logo iterations, a PSD. **Reference material, not shipped** |

**The portrait system is procedural, not authored.** 25 alien civilizations × per-property staffer
rosters cannot be drawn by hand, so `StafferFace.gd` draws every face with the canvas's own `draw_*`
primitives from a **seed**. The seed folds in the current generation, so a manager looks the same
everywhere for the life of a run and each new dynasty's staff looks fresh. Features are rolled
independently (eyes, brows, noses, mouths, hair) so faces read as individuals; within a civ, members
must differ by **shape**, not just palette — head half-width and half-height roll independently and
each picks one of three silhouette constructions, because the first batch's recolor-only approach
read as one template. `draw_face()` returns `false` for any tier with no treatment, so a future tier
28 degrades to the headshot icon rather than drawing nothing.

**Rules for touching art:**

- **Never read `.svg` source at runtime** — exported builds strip it, and this crashed the device
  build. Load the imported texture.
- **Measure with `get_used_rect()`** — the SVG canvases carry transparent padding of varying size.
- **Colors and font sizes come from `UiPalette.gd`**, never hardcoded. Procedural art draws clothing
  from the same palette so staffers cannot introduce off-palette hues.
- **Changed an import setting? `git add -f` the `.import`.**

### 4.2 Audio

The audio pipeline is the most automated part of the project, and it is worth copying elsewhere.

**Getting a sound into the game is: name the file after the cue and put it in the right folder.**
There is no manifest to edit.

| Kind | Folder | Named |
| :--- | :--- | :--- |
| One-shot cues | `res://audio/cues/` | `<cue id>.ogg` |
| Continuous layers | `res://audio/loops/` | `heat_loop.ogg`, `urgency_loop.ogg` |
| Music | `res://audio/music/` | one per era band |

- **`.ogg` beats `.wav`** — `.ogg` is tried first, so a sourced track automatically supersedes a
  placeholder of the same name without deleting anything. All ~100 current files are `.wav`
  placeholders generated by `tools/generate_placeholder_audio.py`.
- **Variants:** `<cue id>_1` … `_4` and the game picks one at random per play. Used on constantly
  heard sounds (tap, purchase).
- **Layers:** a layered cue also looks for `<cue id>_layer`, mixed *on top* for big moments.
- **A missing file is not an error** — the cue is silent and startup logs one line listing everything
  unrecorded. That is what let the entire audio design exist before a single sound was sourced.
- **`game/audio/README.md` is generated**, not written. Edit `CUES` in `scripts/audio/Audio.gd` (and
  `TRIGGERS` in `sim/AudioCueDoc.gd` for descriptions), then re-run
  `<godot> --headless --path game --script res://sim/AudioCueDoc.gd`.
- **Buses** decide which slider governs a sound *and* whether it counts as the player being present
  (SFX and UI do; Ceremony and Music do not). Layout: `audio/default_bus_layout.tres`.
- **Android audio config** is in `project.godot`: `driver/output_latency.android=15`,
  `driver/mix_rate.android=48000` — the outcome of a latency investigation.
- ⚠️ **All of `game/audio/` has its `.import` files force-added.** The WAV importer defaults to QOA
  compression and these samples are PCM; a lost import setting means every sample decodes on the way
  out. This is the single most important reason the `.import` rule exists.

### 4.3 Configuration data

- **`game/config/properties/NN_*.tres`** — **326 files**, one per property, loaded in
  `ConfigLoader.PROPERTY_PATHS` order across the 27 epochs.
- **`game/config/tuning.tres`** — the single tuning resource backing `TuningConfig.gd`'s 134 knobs.
  It **overrides** the `@export` defaults.
- **`TuningOverrides.gd`** persists on-device edits from the Balance Tuning panel to `user://`, so a
  device can carry a custom tuning without touching the repo. Sims deliberately ignore these.
- **`docs/civilizations_v2_draft.json`** (~1.1MB, 26 civs / 326 staffers) is generated by
  `claude/civ_v2_regen/assemble.py`. Neither it nor `claude/civ_v2_regen/` (~1.5MB of JSON) should be
  read wholesale into context.

### 4.4 Verify before you build

```powershell
pwsh tools\run_gates.ps1           # 11 headless gates + a boot check
pwsh tools\run_gates.ps1 -All      # ...plus PortraitSheet (opens a window ~30s)
pwsh tools\run_gates.ps1 -Only Audio
```

Judged by exit code. A new gate must call `quit(0)`/`quit(1)` **and** be added to the `$headless`
list in the runner, or it silently is not part of "is this change safe."

### 4.5 Local builds — `build/build.bat`

Mirrors CI on your own machine. Requires Godot 4.5.1 **as `godot` on PATH** (note: this differs from
every other workflow in the project, where Godot is invoked by absolute path from `D:\Downloads\`),
Inno Setup 6, and the keystore.

1. Version stamp `0.0.<short-sha>` from `git rev-parse --short HEAD`.
2. Export Windows → `dist/american_tycoon_<sha>_win.exe`.
3. Wrap in Inno Setup (`build/setup.iss`) → `dist/american_tycoon_setup_<sha>.exe`.
4. Export Android → `dist/american_tycoon_<sha>.apk` (skipped with a warning if the keystore is
   absent).

⚠️ Local Android builds need the keystore password written into `game/export_presets.cfg`. Protect
against committing it:
`git update-index --skip-worktree game\export_presets.cfg`.

### 4.6 CI — `.github/workflows/build.yml`

Triggers on pushes to **`main`** and **`feature/**`**. Godot 4.5.1-stable, Java 17, Ubuntu runners;
the Godot binary and export templates are cached (key `godot-4.5.1-stable-v1` — **clear the Actions
cache when changing `GODOT_VERSION`**).

| Job | Runs when | Does |
| :--- | :--- | :--- |
| **`export`** | every push | Decodes the keystore from a secret, injects the password into the preset, stamps versions, exports Windows + Android, signs the APK. Uploads the Windows exe **only on `main`** — on feature branches nothing downloads it and it costs ~44MB of artifact storage |
| **`firebase-deploy`** | every push | Pushes the signed APK to Firebase App Distribution — this is how work-in-progress reaches the phone without merging |
| **`windows-installer`** | `main` only | Inno Setup 6 (pre-installed on Windows runners) wraps the exe |
| **`release`** | `main` only | Publishes a tagged GitHub **pre-release** with installer + APK (`softprops/action-gh-release@v2`) |

**Version stamping**, done in CI and worth understanding because three values must agree:

- `version/code` — a plain integer from `GITHUB_RUN_NUMBER`; Android requires it to increase every
  release.
- `version/name` — `0.0.0.NNNN` from the build number; this is what Firebase and Android settings
  show.
- `project.godot`'s `config/version` — rewritten to match, because it is what the in-game About
  screen displays. If these drift, the About screen lies about which build is installed.

**Export presets** (`game/export_presets.cfg`):

| | Preset 0 | Preset 1 |
| :--- | :--- | :--- |
| Name | `Windows Desktop` | `Android` |
| Output | `../dist/american_tycoon_win.exe` | `../dist/american_tycoon.apk` |
| Architectures | — | `arm64-v8a` only |
| Package | — | `com.timgoergen.americantycoon` |
| Keystore | — | `../build/android_release.keystore`, user `american_tycoon`, **password blank in the repo** |

Both leave `include_filter`, `exclude_filter`, and `custom_features` empty. A silent filter is how
assets go missing in release builds only — if you add one, comment why.

**Secrets:** `FIREBASE_SERVICE_ACCOUNT_KEY` (App Distribution Admin), the base64 keystore, and the
keystore password. `.gitignore` blocks `build/android_release.keystore` and
`build/keystore_info.txt` — the keystore committed at `build/` in the working tree is
gitignored, not tracked.

### 4.7 Branch → artifact map

| Branch | Firebase APK | Windows exe | Installer | GitHub release |
| :--- | :---: | :---: | :---: | :---: |
| `feature/**` | ✅ | — | — | — |
| `main` | ✅ | ✅ | ✅ | ✅ pre-release |

`main` is the stable default branch (the `release` branch was retired 2026-06-22). Claude may push
feature branches freely; **confirm before pushing `main`** — a push there cuts a release.
