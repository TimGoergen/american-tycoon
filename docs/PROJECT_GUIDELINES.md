# Project Guidelines

A single, unified statement of the rules, conventions, and procedures that govern work on Tim's
Godot games. It consolidates every `CLAUDE.md` found across the machine (listed under *Sources*
below) so there is one place to look instead of nine.

**American Tycoon is the active project.** Where a rule differs by project, American Tycoon's
version is the default and the differences are called out explicitly in
[Per-Project Deltas](#per-project-deltas).

### The tool-neutral doc set

These four documents are written to be read by any tool or person, not just Claude Code. Together
they replace what used to live only in `CLAUDE.md` files and in session memory:

| Document | Answers |
| :--- | :--- |
| **`PROJECT_GUIDELINES.md`** *(this file)* | What the rules are — conventions, style, process |
| **`ARCHITECTURE_AND_ROADMAP.md`** | What the code is — architecture, status, technical debt |
| **`CI_CD_FIREBASE.md`** | What happens after you push — pipeline, secrets, Firebase |
| **`DEVELOPMENT_WORKFLOW.md`** | Which command to type — tests, builds, git, every flag written out |

Design canon (GDD, Mechanics Spec, Tuning Record, Save Format) remains authoritative for intent and
math; these four are authoritative for practice.

---

## Contents

1. [Sources](#sources)
2. [Working Agreement](#working-agreement)
3. [GDScript Style Guide](#gdscript-style-guide)
4. [File & Node Hierarchy](#file--node-hierarchy)
5. [Signal Handling](#signal-handling)
6. [UI Rules](#ui-rules)
7. [American Tycoon Architecture](#american-tycoon-architecture)
8. [Build & Verify Commands](#build--verify-commands)
9. [Verification Gates ("Unit Tests")](#verification-gates-unit-tests)
10. [Export Presets](#export-presets)
11. [Git & Branching](#git--branching)
12. [Per-Project Deltas](#per-project-deltas)
13. [Self-Review Checklist](#self-review-checklist)

---

## Sources

Everything below was consolidated from these files. They remain in place and remain authoritative
for their own folder; this document is the merged reading of them.

| File | Contributed |
| :--- | :--- |
| `C:\Users\chefq\.claude\CLAUDE.md` | Global working agreement, project paths, tooling paths |
| `C:\Claude\American Tycoon\CLAUDE.md` | AT hard rules, code map, headless build/verify, gotchas |
| `C:\Claude\American Tycoon\game\scripts\core\CLAUDE.md` | Headless state hierarchy, multiplier rules |
| `C:\Claude\American Tycoon\game\scripts\ui\CLAUDE.md` | Design system, modal pattern, minigame contract |
| `C:\Claude\American Tycoon\game\sim\CLAUDE.md` | Gates vs. studies, the gate table, sim gotchas |
| `C:\Claude\Critter Quitters\CLAUDE.md` | GDScript style guide, function design, work process |
| `C:\Claude\Critter Quitters\game\CLAUDE.md` | Folder map, Godot conventions, scene ownership, renderer |
| `C:\Claude\Critter Quitters_BACKUP\CLAUDE.md` | Naming table, comment rules, self-review checklist ⚠ |
| `C:\Claude\Critter Quitters_BACKUP\game\CLAUDE.md` | (identical to the live copy — nothing new) |

⚠ The `_BACKUP` root file is a **fuller** version than the live one: it carries a naming-convention
table, a Comments section, and a self-review checklist that the live `Critter Quitters\CLAUDE.md`
no longer has. Those sections are preserved here. Blob Chain has no `CLAUDE.md` of its own and
inherits this document.

---

## Working Agreement

**Tim reviews; Claude implements.** Tim reads and evaluates the code, not just runs it. That single
fact drives every style rule in this document.

- Prioritize human readability in every file — naming, structure, and intent must be clear to a
  careful non-expert reader.
- Never sacrifice clarity for cleverness or brevity. Avoid idiomatic shortcuts that obscure meaning.
- When making a non-obvious implementation decision, leave a brief comment explaining **why**.
- Before considering any implementation done, ask: *would a thoughtful non-expert understand what
  this file does and why?*
- Tim is a professional database developer and data architect — do not over-explain source control,
  testing, deployment, or data modeling. He is new to Godot/GDScript — **do** explain Godot APIs,
  node patterns, and GDScript idioms clearly; Unity comparisons help.
- Prompt to ask whether changes should be committed if nothing has been committed for 20+ minutes.
- Decompose work across parallel agents whenever the pieces are independent (multiple files,
  multiple systems, research + implementation).

**Design canon comes first.** Before any work, consult the relevant sections of `docs/` — not the
whole thing (the American Tycoon GDD alone is ~95KB):

- **GDD v0.2** — canon for design intent. See §0.1 *the anti-pillar*: what this game must never become.
- **Mechanics Spec v0.1** — canon for math and formulas.
- **M1 Brief** — canon for the current milestone scope.
- **`docs/Tuning_Record.md`** — where each tuning number came from (fitted vs. feel-tuned).
- **`docs/Save_Format_And_Migrations.md`** — what each `SAVE_VERSION` changed and what still migrates.

Every implementation is judged against **Principle 4 (playable and fun first)** and the anti-pillar.

**Process rules:**

- **GDD maintenance** — the GDD is a live document. Update it whenever work changes, adds, or
  removes a design decision, mechanic, or system. Don't wait to be asked.
- **Feature branches** — all work happens on a feature branch, never directly on `main`. Check the
  active branch at the start of every session; if it is `main`, stop and ask which branch to use.
- **Game balance** — for any numeric value affecting gameplay, propose a specific value with a brief
  rationale. If a proposed value conflicts with a recorded playtesting note, flag it and ask.
- **Scope** — before expanding beyond the stated task (extra files, adjacent refactors, unrequested
  features), flag what you noticed and ask whether to include it.
- **Plans** live in each project's `Plans\` folder at the project root — never scattered in `docs/`.
- **Recaps** at end of task should be verbose and carry a completion timestamp.

---

## GDScript Style Guide

GDScript only. Conventions follow the
[official GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
except where noted below.

### Naming

| Kind | Convention | Example |
| :--- | :--- | :--- |
| Variables and functions | `snake_case` | `player_health`, `calculate_damage` |
| Classes and types | `PascalCase` | `EnemySpawner`, `GameState` |
| Constants | `SCREAMING_SNAKE_CASE` | `MAX_ENEMIES`, `BASE_MOVE_SPEED` |
| Booleans | prefix `is_` / `has_` / `can_` | `is_alive`, `has_shield`, `can_jump` |
| Signals | `snake_case`, **past tense** | `enemy_died`, `wave_completed`, `trap_placed` |
| Collections | plural nouns | `enemies`, `active_projectiles`, `spawn_points` |
| Node names | `PascalCase` | `GridCell`, `EnemySpawner`, `WaveManager` |
| Enums | `PascalCase` name, `SCREAMING_SNAKE_CASE` values | `enum PestType { ANT, CRICKET, RAT }` |

- **No abbreviations** unless universally understood — `pos` is fine, `plyr` is not.
- **If a variable needs a comment to explain what it holds, rename it instead.**

### Function design

- Each function does **exactly one thing** — if you need "and" to describe it, split it.
- Keep functions **under 30 lines**; extract named helpers if they grow beyond that.
- Name functions as **verb phrases** — `spawn_enemy`, not `enemy`.
- **Prefer early returns** over deeply nested conditionals.
- **No side effects** in functions whose names don't imply them.
- Parameters read naturally: `deal_damage(target, amount)`, not `deal_damage(amount, target)`.
- More than 3–4 parameters? Group them into a typed Dictionary or a dedicated class/resource.

```gdscript
# Prefer this:
func spawn_enemy(config: EnemyConfig) -> Enemy:

# Over this:
func spawn_enemy(type: int, x: float, y: float, health: float) -> Enemy:
```

### Constants & magic numbers

- **No magic numbers** — extract to named constants.
- Include units in the name where relevant, and group related constants in a top-of-file block:

```gdscript
const RESPAWN_DELAY_SEC: float = 3.0
const MAX_PROJECTILES_PER_FRAME: int = 5
const GRID_CELL_SIZE_PX: int = 44
```

> **American Tycoon overrides this with a stronger rule:** no *tuning* constants in code at all.
> See [American Tycoon Architecture](#american-tycoon-architecture).

### Structure & formatting

- **Maximum nesting depth: 3 levels** — extract to a named function if deeper.
- Blank lines between logical sections inside a function; keep related lines together.
- Always use explicit types on variables and function signatures where practical:

```gdscript
var health: int = 100
func take_damage(amount: int) -> void:
```

- Alias early to avoid repeated property chains — `var pos: Vector2 = enemy.global_position`.
- Use `@export` for values that should be tunable in the Godot editor.
- Use `@onready` for node references rather than fetching them mid-function.

### Comments

- Explain **WHY, not WHAT** — the code already shows what it does.
- Flag non-obvious decisions:
  ```gdscript
  # Using object pool here — instantiating during gameplay causes GC spikes on mobile
  ```
- **No commented-out code** — git history is the recovery mechanism.
- **No redundant comments** that restate the code (`# increment the player score by 1`).
- TODOs must state what is needed and why:
  ```gdscript
  # TODO: replace linear search with spatial hash once enemy count exceeds ~50
  ```

### What to avoid

- **Single-letter variable names**, even for loop indices — use `index` or `enemy_index`.
- **Clever one-liners** that trade readability for brevity.
- **Deep nested `if` chains** — early returns or extracted helpers.
- **Boolean parameters that flip behavior** — write two named functions instead:
  ```gdscript
  # BAD:  spawn_enemy(true)
  # GOOD: spawn_elite_enemy()
  ```
- **Implicit type coercion** — be explicit about types and conversions.
- **Mutating function arguments** — treat parameters as read-only unless the name implies mutation.
- **Direct node path strings** like `get_node("../../UI/HUD")` in logic code — use `@export` or
  `@onready` instead.

---

## File & Node Hierarchy

- **One class or major concept per file.**
- **Keep files under 300 lines** — split into smaller scripts beyond that.
- File names match their primary class — `EnemySpawner.gd` defines `EnemySpawner`.
- Scenes (`.tscn`) and their primary script share a name — `Arena.tscn` / `Arena.gd`.
- **One scene per major concept** — never combine unrelated systems into one scene.
- **Group related files in feature folders** — `/enemies`, `/ui`, `/audio`, `/traps`.
- Use Godot's node hierarchy intentionally: **scene structure reflects logical ownership.**
- **Scene ownership** — each scene is responsible for its own internal logic. Cross-scene
  communication goes through signals (or, where the project allows them, autoloads) — never through
  direct node paths.
- **Circular dependencies are never acceptable** — restructure, or use signals.
- Subsystem folders may carry their own `CLAUDE.md`. Those rules are **additive** — they extend,
  never replace, the project-level rules. Honor both.

---

## Signal Handling

Signals are the preferred way to communicate between decoupled nodes. Use them instead of direct
node references wherever the sender should not need to know about the receiver.

- **Declare signals at the top of the script, before variables.** Every script, no exceptions.
- **Signal names are past tense** and describe what just happened: `pest_reached_exit`, `trap_sold`,
  `wave_completed`.
- **Connect signals in the parent or a dedicated manager** — not inside the emitting node. The
  emitter should not know who listens.
- **Do not use signals for communication within a single tightly coupled class** — a direct call is
  clearer there, and a signal only adds indirection.
- Signals are the escape hatch for a would-be circular dependency: if A needs B and B needs A,
  one direction becomes a signal.
- A full-screen modal exposes a `signal closed` and an `open()` method; the host (`Main.gd`)
  instantiates it, adds it as a child, and connects `closed` — see [UI Rules](#ui-rules).

---

## UI Rules

**Standing rules from Tim — these are non-negotiable and apply to every project:**

- **LARGE text and LARGE tappable targets.** Tim is 49 with imperfect vision; default to generous
  sizing on all UI.
- **Never hide or show controls.** Keep them always visible in a gray disabled state (the
  frenzy-pop-button pattern). Moving UI is disorienting and costs a target.

**American Tycoon UI conventions** (`game/scripts/ui/`) — Godot `Control` scenes built in code, with
`scripts/Main.gd` as the root screen owning the tabs, HUD, and full-screen modals:

- **`UiPalette.gd` is the design system.** Use its named colors (`NAVY`, `CREAM`, `MUSTARD_GOLD`,
  `DARK_GOLD`, `MONEY_GREEN`, `ATOMIC_TEAL`, `KETCHUP_RED`, …) and its `FONT_*` size constants —
  **never hardcode a color or a font size.** Helpers: `apply_screen_bezel`,
  `make_screen_panel_style`, `make_tab_title`, `style_button`, `make_bold_font`.
- **Full-screen modal pattern** (`AboutScreen` / `StatsScreen` / `MinigameReviewScreen`):
  `extends ColorRect`, black background + bezel + panel, a top-left "◀ BACK" button, a
  `signal closed`, and an `open()` method. `Main.gd` instantiates and `add_child`s it, and opens it
  from a Settings button. Add it to Main's `modal_up` set if it should freeze the economy while up.
- **Minigame library** — `Minigame.gd` is the base type: `display_name()`, `begin(tuning)`,
  `get_performance() -> [0,1]` (the reward metric the host maps to a multiplier),
  `get_score() -> int`, `is_busy()`, a `challenge_mode` flag, and a `completed` signal.
  `MinigameScreen.gd` is the reward-agnostic host across six types (Match Three, Timing Bar, Catch
  the Money, Memory, Micro Basketball, Balance). **Reward-agnostic contract: a minigame reports only
  performance and score — it must never know what the reward is.**

**Godot UI gotchas that have bitten us (each cost a debugging session):**

| Gotcha | Rule |
| :--- | :--- |
| `RichTextLabel` in a `CanvasLayer` | Needs `custom_minimum_size` **and** `AUTOWRAP_OFF`, or it renders as stray pixels |
| `Label` autowrap + overrun trim | `AUTOWRAP_WORD` together with `OVERRUN_TRIM_ELLIPSIS` collapses min height to ~1px (invisible text). Use autowrap alone |
| Markers over a framed `ProgressBar` | Position with `frac × width − inset` (the *fill's* coordinates), not the inset track, or they sit 1–2px off the fill edge |
| Texture sizing | Always use `get_used_rect()` for aspect-ratio and layout math — canvases carry transparent padding. Crop with `AtlasTexture` when an icon must fill its box |
| Runtime `.svg` source reads | **Never.** Exported builds strip raw `.svg` source; a runtime `FileAccess` read crashed the device build (opened → minimized). Load the *imported* texture. Desktop and boot checks do not catch this |
| New project window setup | Set `window_width/height_override` (≤800px tall) and aspect `"expand"` for portrait — missing this bit both Blob Chain and American Tycoon |

**Audio gotchas:**

- Per-frame-polled state must never drive `stop()`/`play()` or tween rebuilds — this crashed a device.
- Loops need whole cycles in the buffer.
- WAV imports default to QOA compression and `loop_mode` may not survive an import.
- Autoload globals are absent under `--script` (see [Verification Gates](#verification-gates-unit-tests)).
- Before debugging latency, ask what the audio is playing *through*.

---

## American Tycoon Architecture

American Tycoon is a Godot 4 / GDScript idle-tycoon game. The Godot project is the `game/`
subfolder (`game/project.godot`, main scene `game/Main.tscn`). The repo root also holds `docs/`
(design canon), `Plans/` (design & implementation docs), and `claude/` (working files).

### Hard rules

1. **No tuning constants in code.** Costs, rates, multipliers, timings — all of it loads from
   `game/config/` (`tuning.tres` + `config/properties/*.tres`). The Balance Tuning dev panel edits
   them on device. A number baked into a `.gd` file cannot be tuned on the device, which defeats the
   whole loop.
2. **GDScript only.**
3. **Effectively no autoloads — there is exactly one deliberate exception.** Shared helpers are
   `class_name` static classes — `ConfigLoader`, `EpochCatalog`, `UiPalette`, `Money`,
   `SaveManager` — used directly, e.g. `ConfigLoader.load_tuning()`. The one autoload is
   **`Audio`** (`res://scripts/audio/Audio.gd`), added with the audio pass on 2026-08-10, because a
   sound system genuinely needs a persistent node owning audio players. Do not add a second without
   a reason of that weight. (The root `CLAUDE.md` still says "there are no autoloads" — it predates
   the audio pass. See `docs/ARCHITECTURE_AND_ROADMAP.md` §3.4.)

### Code map (`game/`)

| Path | Role |
| :--- | :--- |
| `scripts/core/` | Headless game state + rules. **No scene tree** — nothing here touches Nodes or UI |
| `scripts/ui/` | Screens, overlays, HUD, minigame library |
| `scripts/Main.gd` | The root screen; wires the UI to the core |
| `scripts/resources/` | `.tres`-backed data classes (`PropertyConfig.gd`, `TuningConfig.gd`) |
| `sim/` | Headless verification — `SceneTree` scripts |
| `config/` | `tuning.tres` and `properties/NN_*.tres` — the 326-property ladder over 27 epochs (Earth Blue/White Collar + 25 alien civs), in `ConfigLoader.PROPERTY_PATHS` order |

### State hierarchy (`scripts/core/`)

Pure logic, driven by *both* the balance simulator (`sim/`) and the UI (`Main.gd`) — which is
precisely why the two can never drift on rules.

- **`DynastyState`** — the dynastic layer *above* a single life. Owns the current `GameState`
  (`current`), the Legacy wallet/upgrades (`LegacyUpgrades`), staff retention, generation count,
  `lifetime_cash_earned`, best-vent-streak, and ancestors. It wraps the whole save
  (`to_save_dict`/`load_save_dict`) and pushes purchased upgrade effects onto each generation via
  `_apply_upgrade_effects`.
- **`GameState`** — one generation's run. Owns `EconomyState`, `WageState`, `FrenzyState`,
  `RushMomentumState`, `EpochState`. `SAVE_VERSION` lives here; a mismatched version loads with a
  warning (non-fatal).
- **`EconomyState` / `PropertyState`** — the property ladder; unit costs via `CostCurve`; income
  multipliers.

**To add a persisted field:** append it in `to_save_dict()`, read it back with a defaulted
`data.get(...)`, and bump `SAVE_VERSION`. Record the change in `docs/Save_Format_And_Migrations.md`.

### Core patterns & gotchas

- **Global multipliers must apply exactly ONCE.** Property income = Family Fortune
  (`LegacyUpgrades.property_income_multiplier`) surfaced through
  `DynastyState.get_legacy_income_multiplier()`. The passive tick reads that **method**; the
  rush-collect path reads each property's `legacy_income_multiplier` **field**, seeded from the same
  method. When adding a new global income/legacy multiplier, fold it into that single source so it
  lands once — never double, never miss. Trace `tick()`, `_apply_upgrade_effects`, and
  `get_draft_will` before you believe it.
- **Stateless catalogs configured from tuning.** Data + math tables are `class_name` statics whose
  `static var` config is pushed in from tuning by `DynastyState` (see
  `LegacyUpgradeCatalog.cost_multiplier`, `StaffRetention`). **Gotcha:** `DynastyState` re-pushes
  that config on *every* construction/load, so a sim wanting a custom value must set the **tuning
  field**, not the static — otherwise the next dynasty build overwrites it.
- **`EpochCatalog`** is the fixed table of the 6 alien epochs + per-property staffer rosters (pure
  data). **`ConfigLoader`** loads `tuning.tres` (plus optional user overrides) and the property
  `.tres` list. **`Money`** is big-number formatting/arithmetic. **`SaveManager`** is versioned JSON
  to `user://`.
- The estate waterfall grosses on **lifetime cash EARNED** (monotonic), not net worth.

### Large generated data — do not read wholesale into context

- `docs/civilizations_v2_draft.json` (~1.1MB, 26 civs / 326 staffers) — regenerated by
  `claude/civ_v2_regen/assemble.py`.
- `claude/civ_v2_regen/` — civ-pipeline inputs/outputs (~1.5MB of JSON). Ignore unless working on
  civ regeneration.

### `.import` files are gitignored — and that is a trap

Fine while a file's import settings are all **defaults**: CI regenerates them identically. **Not**
fine the moment you change one, because the setting then exists only on your machine — it works
locally and ships without it.

> **Change an import setting → `git add -f` that `.import` file.**

Everything under `game/audio/` is force-added for exactly this reason: the WAV importer defaults to
QOA compression and the SFX are PCM, so a lost setting would mean every sample decoding on the way
out. The art `.import` files that *are* tracked are the ones that once needed it; the rest sit at
defaults and can stay ignored.

---

## Build & Verify Commands

**Godot 4.5.1 is NOT on PATH.** Invoke it by absolute path:

```
D:\Downloads\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64_console.exe
```

| Task | Command |
| :--- | :--- |
| Parse-check one script | `<godot> --headless --path game --check-only --script res://scripts/….gd` |
| Run a sim / gate | `<godot> --headless --path game --script res://sim/SomeTest.gd` |
| Boot a few frames | `<godot> --headless --path game --quit-after 90` |
| Import the project (refresh class cache) | `<godot> --headless --editor --quit --path game` |
| Run the full gate sweep | `pwsh tools\run_gates.ps1` |

**Build gotchas that bite every time:**

- A **new `class_name` is not in the global class cache until a project import.** Run the editor
  import first, or `--script` fails with *"Could not resolve external class"*.
- That editor import **rewrites `game/project.godot`** (reorders sections, strips comments) —
  run `git restore game/project.godot` afterward so you don't ship the churn.
- **`game/config/tuning.tres` overrides the `@export` defaults in `TuningConfig.gd`.** A knob change
  only ships if the value isn't already baked into the `.tres` — grep `tuning.tres` before assuming
  a default change ships.
- A standalone `--check-only` on a single UI script reports spurious *"identifier not declared"* for
  `class_name`/preload references outside project context. **The editor import plus a
  `--quit-after 90` boot is the authoritative check**, not `--check-only` alone.

**Git commands:** always use `git -C "path"` rather than prefixing with `cd`, so calls match the
`PowerShell(git *)` allow list.

---

## Verification Gates ("Unit Tests")

`game/sim/` holds 27 standalone `SceneTree` scripts. Each loads the **same `ConfigLoader` the game
does**, so a sim and the game can never drift on rules or numbers.

**Two different kinds of thing live there, and confusing them has already cost us:**

- A **GATE** asserts and exits non-zero on failure. It is part of *"is this change safe."*
- A **TOOL/STUDY** prints numbers or writes a file. You run it when you have a question.

Running the studies as if they were tests produces noise. Running only *some* of the gates produces
false confidence — on **2026-08-10** a whole session's changes were verified against 9 of the 12
gates, with two (`MatchThreeTest`, `RushOverheatTest`) never run at all despite edits to the code
they cover. `tools\run_gates.ps1` exists to make that impossible.

### Running the gates

```powershell
pwsh tools\run_gates.ps1              # the 11 headless gates + a boot check
pwsh tools\run_gates.ps1 -All         # ...plus PortraitSheet, which needs a real window
pwsh tools\run_gates.ps1 -Only Audio  # substring filter on the gate name
```

One at a time, by hand:

```
D:\Downloads\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64_console.exe --headless --path game --script res://sim/MoneyTest.gd
```

**The runner judges by EXIT CODE, never by scraping output.** Every gate calls `quit(0)` or
`quit(1)` — the one signal that cannot drift. The human-readable summary lines *did* drift
(`MatchThreeTest` prints "ALL TESTS PASS", everything else prints "ALL CHECKS PASSED"), which is
precisely how a grep-based runner misses a gate while appearing to pass. **Any new gate must call
`quit(0)`/`quit(1)` and be added to the `$headless` list in `tools\run_gates.ps1`.**

### The gates

| Gate | Covers |
| :--- | :--- |
| `MoneyTest` | Number formatting across all three display modes |
| `EpochTest` | Epoch staffing, the 27-tier ladder, save migration |
| `ChallengeGoalsTest` | Challenge tier ladders, both reward tracks, the met-minigame set |
| `MatchThreeTest` | `MatchThreeBoard`'s pure logic — matching, cascades, Legacy gems |
| `RushOverheatTest` | The push-your-luck heat model: bands, vents, overheat, re-arm |
| `AutoPurchaseTest` | The Acquisitions Desk's buying policy and its lockouts |
| `MomentumBarStateTest` | The bar paints the state Main pushed it, never its own guess |
| `ScrollEdgeFadeTest` | List fade against an unlaid-out viewport (invisible-content bug) |
| `IncomeReadoutTest` | What a property row displays: the income label and the cycle bar |
| `AudioSettingsTest` | Every `ui_` preference survives a save **and** a succession |
| `AudioCoreTest` | The audio system's rules: mute, voice pool, pitching, cue coverage |
| `PortraitSheet` ⚠ | Renders all 25 alien civs and checks them — **needs a real renderer** |

⚠ `PortraitSheet` cannot run headless — with no framebuffer to capture, `get_image()` returns null.
It needs `--rendering-driver opengl3`, opens a window for ~30s, and is opt-in via `-All`.

### The studies — run when you have a question, not to verify a change

| Tool | Answers |
| :--- | :--- |
| `Sim` | The balance simulator entry point (Mechanics Spec §13) |
| `PaceStudy` | The two-clock tuning readout (`Plans/Core_Pace_Study.md`) |
| `PaybackStudy` | Property self-funding: how long a rung takes to pay for itself |
| `PrestigeStudy` | Prestige yield vs. cost — the "reward pushing a run" re-tune |
| `DynastyArcStudy` | The endgame economy's primary fit instrument (fitted the deep-band constants) |
| `AutoPurchaseCostStudy` | Fitted the two Acquisitions Desk upgrade curves |
| `BlueCollarStudy` | The Blue Collar epoch threshold |
| `EpochPaceStudy` | How long each epoch takes to clear, at different Legacy stacks |
| `EpochPhaseStudy` | Inside one epoch: how much time is unlocking vs. stacking |
| `EpochCadenceStudy` | Whether a per-epoch income decay creates the intended cadence |
| `EpochDepthCheck` | Reachability of the deep ladder |
| `UnlockCadence` | How often the player gets a NEW PROPERTY beat |
| `DumpLiveCivData` | Exports the live property ladder + staffer rosters |
| `AudioCueDoc` | **Writes** `game/audio/README.md` from the cue table — a generator, not a test |
| `BubbleProbe` | Throwaway probe kept for reference |

### Sim gotchas

- Sims call `ConfigLoader.load_tuning(false)` so they measure the **baked** defaults, never a
  device's user overrides.
- To test a custom tuning value, set the **tuning field** and *then* build the dynasty — never poke
  a catalog's `static var` directly, because `DynastyState` re-pushes tuning on construction and
  would overwrite it.
- A new `class_name` used by a sim needs an editor import first, or `--script` errors *"Could not
  resolve external class."*
- **Autoload globals are not in scope under `--script`.** The script passed to `--script` compiles
  before autoloads register, so a sim cannot name `Audio` directly — resolve it with
  `root.get_node_or_null(^"Audio")` *after* awaiting a frame. (During `_initialize()` `root` is not
  yet in the tree, so an absolute path errors.) A scene instantiated later, like `Main.tscn`, uses
  the global name freely.
- During `_initialize()` `root` is not in the tree, so `add_child` does **not** run `_ready`. Await
  a frame before touching anything a node builds there.
- `ObjectDB instances leaked / resources still in use at exit` is normal `SceneTree`-script teardown
  noise, not a failure.

---

## Export Presets

American Tycoon ships two presets, both defined in `game/export_presets.cfg`.

| | Preset 0 | Preset 1 |
| :--- | :--- | :--- |
| Name | `Windows Desktop` | `Android` |
| Export path | `../dist/american_tycoon_win.exe` | `../dist/american_tycoon.apk` |
| Architectures | — | `arm64-v8a` only (v7a, x86, x86_64 all off) |
| Signing | — | Release keystore `../build/android_release.keystore`, user `american_tycoon` |
| Package | — | `com.timgoergen.americantycoon` |

**Rules for touching export presets:**

- **`version/code` must be a plain positive integer that increments with every release.** CI stamps
  it from `GITHUB_RUN_NUMBER`.
- **`version/name`** is the human-readable string shown in Firebase and Android settings. Format is
  `MAJOR.MINOR.PATCH.BUILD` — CI stamps `0.0.0.NNNN` from the build number and keeps
  `project.godot`'s `config/version` (shown on the in-game About screen) in sync with it.
- **Never commit the keystore password.** `keystore/release_password` stays empty in the repo; CI
  decodes the keystore from a secret and injects the password into the preset at build time.
- Both presets leave `include_filter`, `exclude_filter`, and `custom_features` empty. If you need to
  filter, say why in a comment — a silent filter is how assets go missing in a release build only.
- Local export uses the same commands CI does:
  `<godot> --headless --export-release "Windows Desktop" "../dist/american_tycoon_win.exe"`

**CI pipeline** (`.github/workflows/build.yml`, cloned from the proven Critter Quitters pipeline):

- Triggers on pushes to `main` and `feature/**`.
- Godot `4.5.1-stable`, Java 17, Ubuntu runner; the Godot binary and export templates are cached.
- `feature/**` → Android APK exported, signed, and shipped to Firebase App Distribution (the Windows
  exe is not uploaded on feature branches — nothing downloads it and it costs ~44MB of artifact
  storage).
- `main` → full release: Windows installer + signed APK + a GitHub pre-release.
- To change the Godot version, edit `GODOT_VERSION` in the workflow **and clear the Actions cache**.

---

## Git & Branching

- **`main` is the stable default branch.** Per-feature branches off it; the `release` branch was
  retired 2026-06-22.
- Every push to a `feature/**` branch builds and ships a Firebase APK — Tim can test on device
  without merging. A push to `main` runs a full release build.
- **Claude may commit at any time and push feature branches freely. Confirm before pushing `main`.**
- Delete merged branches (local + remote + worktree); keep shelved ones.
- Use `git -C "path"` — never `cd` first.
- Versioning format is `MAJOR.MINOR.PATCH.BUILD`. Critter Quitters shipped at 0.1.0; Blob Chain
  starts at 0.0.0.
- Plans go in `<project>\Plans\`; design canon in `<project>\docs\`.

---

## Per-Project Deltas

| | American Tycoon | Critter Quitters | Blob Chain |
| :--- | :--- | :--- | :--- |
| Genre | Idle/tycoon | Tower defense | Chain-reaction puzzle |
| Status | **Active** | On hold (v0.1.0 shipped 2026-06-08) | On hold (Phase 1 scaffold) |
| Project root | `C:\Claude\American Tycoon\` | `C:\Claude\Critter Quitters\` | `C:\Claude\Blob Chain\` |
| Godot project | `…\game\` | `…\game\` | `…\game\` |
| GitHub | `TimGoergen/american-tycoon` | `TimGoergen/critter-quitters` | `TimGoergen/blob-chain` |
| **Autoloads** | **One only** (`Audio`) — everything else is a `class_name` static | **Allowed** for truly global state (`GameState`, `RunManager`); do not overuse | inherits AT's preference |
| **Tunables** | **Never in code** — `config/*.tres`, edited on device | `@export` in the editor | `@export` in the editor |
| Renderer | — | **Mobile renderer** (iOS/Android/Web) | — |

**Critter Quitters folder map** (`game/`, scenes and scripts co-located by feature):

| Folder | Contents |
| :--- | :--- |
| `arena/` | Grid, pathfinding, arena evolution, blocking terrain |
| `traps/` | All trap types and their behaviour |
| `enemies/` | All pest types and their behaviour |
| `ui/` | HUD, store, context panels, The Truck hub |
| `core/` | Game state, wave manager, run manager, economy |
| `assets/` | Fonts, textures, audio |

**Critter Quitters renderer constraints:** Mobile renderer targeting iOS, Android, and Web. Avoid
shader features unsupported by mobile GL (complex lighting, screen-space effects). All 3D objects
are billboarded — `MeshInstance3D` with a `QuadMesh` facing the camera. The camera is fixed
orthographic top-down; add no camera controls beyond debug pan/zoom.

**Shared tool paths:**

| Tool | Path |
| :--- | :--- |
| Godot 4.5.1 | `D:\Downloads\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64_console.exe` |
| gh CLI | `C:\Program Files\GitHub CLI\gh.exe` |

> Note: the game repos moved from `D:\Claude\` to `C:\Claude\` (NVMe) on 2026-06-29. Old `D:\Claude`
> paths in older transcripts and docs are stale. The **Godot binary is still on `D:\`.**

---

## Self-Review Checklist

Before considering any implementation complete, verify:

- [ ] Every function name describes what it does as a verb phrase
- [ ] No function exceeds 30 lines
- [ ] No magic numbers remain in logic — all extracted to named constants
      (American Tycoon: no *tuning* numbers in code at all — they live in `config/*.tres`)
- [ ] No abbreviations that would confuse a new developer
- [ ] Comments explain **why**, not what
- [ ] No commented-out code
- [ ] Nesting depth is 3 or fewer levels
- [ ] File is under 300 lines (split if not)
- [ ] Signals are declared at the top of the script and used for cross-node communication rather
      than direct references
- [ ] Types declared on all variables and function signatures
- [ ] Colors and font sizes come from `UiPalette`, never hardcoded
- [ ] Controls stay visible-and-disabled rather than hidden; text and tap targets are large
- [ ] If an import setting changed, the `.import` file was `git add -f`'d
- [ ] `pwsh tools\run_gates.ps1` passes — **all** gates, not the ones you remembered
- [ ] The GDD and any affected canon docs were updated
- [ ] Would a thoughtful non-expert understand what this file does and why?
