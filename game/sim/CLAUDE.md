# sim/ — verification gates and study tools

Each script is a `SceneTree` run standalone. It loads the SAME `ConfigLoader` the game does, so a sim
and the game can never drift on rules or numbers.

**Two kinds of thing live here, and mixing them up has already cost us.** A GATE asserts and exits
non-zero on failure; it is part of "is this change safe". A TOOL prints numbers or writes a file and
is run when you have a question. Running the tools as if they were tests produces noise; running only
*some* of the gates produces false confidence — on 2026-08-10 a whole session's changes were verified
against 9 of the 12 gates, with two never run at all despite edits to the code they cover.

## Running the gates

    pwsh tools\run_gates.ps1           # the 11 headless gates + a boot check
    pwsh tools\run_gates.ps1 -All      # ...plus PortraitSheet, which needs a window
    pwsh tools\run_gates.ps1 -Only Audio

The runner judges by **exit code**, never by scraping output — every gate calls `quit(0)`/`quit(1)`,
and that is the one signal that cannot drift. (The human-readable summary lines *did* drift, which is
exactly how a grep-based runner misses a gate while appearing to pass.)

One at a time, by hand:

    D:\Downloads\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64_console.exe --headless --path game --script res://sim/MoneyTest.gd

## The gates

| Gate | Covers |
|---|---|
| `MoneyTest` | Number formatting across all three display modes |
| `EpochTest` | Epoch staffing, the 27-tier ladder, save migration |
| `ChallengeGoalsTest` | Challenge tier ladders, both reward tracks, the met-minigame set |
| `MatchThreeTest` | `MatchThreeBoard`'s pure logic — matching, cascades, Legacy gems |
| `RushOverheatTest` | The push-your-luck heat model: bands, vents, overheat, re-arm |
| `AutoPurchaseTest` | The Acquisitions Desk's buying policy and its lockouts |
| `MomentumBarStateTest` | The bar paints the state Main pushed it, never its own guess |
| `ScrollEdgeFadeTest` | List fade against an unlaid-out viewport (invisible-content bug) |
| `IncomeReadoutTest` | What a property row displays: the income label and the cycle bar |
| `AudioSettingsTest` | Every `ui_` preference survives a save AND a succession |
| `AudioCoreTest` | The audio system's rules: mute, voice pool, pitching, cue coverage |
| `PortraitSheet` ⚠ | Renders all 25 alien civs and checks them — **needs a real renderer** |

⚠ `PortraitSheet` cannot run headless: there is no framebuffer to capture, so `get_image()` returns
null. It needs `--rendering-driver opengl3` and opens a window for ~30s. `run_gates.ps1 -All`.

## The tools — run these when you have a question, not to verify a change

| Tool | Answers |
|---|---|
| `Sim` | The balance simulator entry point (Mechanics Spec §13) |
| `PaceStudy` | The two-clock tuning readout (`Plans/Core_Pace_Study.md`) |
| `PaybackStudy` | Property self-funding: how long a rung takes to pay for itself |
| `PrestigeStudy` | Prestige yield vs cost — the "reward pushing a run" re-tune |
| `DynastyArcStudy` | The endgame economy's primary fit instrument (fitted the deep-band constants) |
| `AutoPurchaseCostStudy` | Fitted the two Acquisitions Desk upgrade curves |
| `BlueCollarStudy` | The Blue Collar epoch threshold |
| `EpochPaceStudy` | How long each epoch takes to clear, at different Legacy stacks |
| `EpochPhaseStudy` | Inside one epoch: how much time is unlocking vs stacking |
| `EpochCadenceStudy` | Whether a per-epoch income decay creates the intended cadence |
| `EpochDepthCheck` | Reachability of the deep ladder |
| `UnlockCadence` | How often the player gets a NEW PROPERTY beat |
| `DumpLiveCivData` | Exports the live property ladder + staffer rosters |
| `AudioCueDoc` | **Writes** `game/audio/README.md` from the cue table — a generator, not a test |
| `BubbleProbe` | Throwaway probe kept for reference |

## Gotchas

- Sims call `ConfigLoader.load_tuning(false)` so they measure the BAKED defaults, never a device's
  user overrides.
- To test a custom tuning value, set the TUNING field and THEN build the dynasty — do not poke a
  catalog's `static var` directly, because `DynastyState` re-pushes tuning on construction and would
  overwrite it.
- A new `class_name` used by a sim needs an editor import first (root `CLAUDE.md`), or `--script`
  errors "Could not resolve external class". A standalone `--check-only` on one UI script also
  reports spurious "identifier not declared" for `class_name`/preload refs outside project context —
  the editor import plus a `--quit-after 90` boot is the authoritative check.
- **Autoload globals are not in scope under `--script`.** The script given to `--script` is compiled
  before autoloads register, so a sim cannot name `Audio` directly: resolve it with
  `root.get_node_or_null(^"Audio")` *after* awaiting a frame (during `_initialize()` `root` is not yet
  in the tree, so an absolute path errors). A scene instantiated later, like `Main.tscn`, uses the
  global name freely.
- During `_initialize()` `root` is not in the tree, so `add_child` does **not** run `_ready`. Await a
  frame before touching anything a node builds there.
- `ObjectDB instances leaked / resources still in use at exit` is normal SceneTree-script teardown
  noise, not a failure.
