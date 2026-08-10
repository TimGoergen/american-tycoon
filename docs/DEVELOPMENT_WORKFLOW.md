# Development Workflow — every command, written out

**Snapshot: 2026-08-10.** Godot **4.5.1-stable**, Windows 11, PowerShell 5.1.

This is the copy-paste reference: every verification command, every export command, every git command
this project actually uses. Nothing here is summarized — if a command has a flag, the flag is
written out, because the failure mode this document exists to prevent is someone approximating a
command and getting a misleading pass.

**Companion documents:** `PROJECT_GUIDELINES.md` (conventions) · `ARCHITECTURE_AND_ROADMAP.md` (what
the code is) · `CI_CD_FIREBASE.md` (what happens after you push).

---

## Contents

1. [Prerequisites & Paths](#1-prerequisites--paths)
2. [The Daily Loop](#2-the-daily-loop)
3. [Unit Tests — The Verification Gates](#3-unit-tests--the-verification-gates)
4. [The Study Tools](#4-the-study-tools)
5. [Writing a New Gate](#5-writing-a-new-gate)
6. [Godot CLI Reference](#6-godot-cli-reference)
7. [Export & Build Commands](#7-export--build-commands)
8. [Git Workflow](#8-git-workflow)
9. [Pre-Migration Checklist (Antigravity)](#9-pre-migration-checklist-antigravity)

---

## 1. Prerequisites & Paths

| Tool | Location | On PATH? |
| :--- | :--- | :---: |
| Godot 4.5.1 (console build) | `D:\Downloads\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64_console.exe` | ❌ **No** |
| Repository root | `C:\Claude\American Tycoon\` | — |
| Godot project root | `C:\Claude\American Tycoon\game\` | — |
| gh CLI | `C:\Program Files\GitHub CLI\gh.exe` | ✅ |
| Inno Setup 6 | `C:\Program Files (x86)\Inno Setup 6\ISCC.exe` | ❌ (called by path) |

> **Godot is deliberately not on PATH.** Every command below invokes it by absolute path. Note the
> **`_console.exe`** variant — the plain `.exe` detaches from the terminal and you lose all output,
> which makes a headless run look like it did nothing.

**Set this once per PowerShell session** and every later command in this document works verbatim:

```powershell
$GODOT = "D:\Downloads\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64_console.exe"
cd "C:\Claude\American Tycoon"
```

Note the repo layout: **`--path game`** points Godot at the project, which is the `game/`
subdirectory, not the repository root. Getting this wrong produces "cannot open project" rather than
anything informative.

---

## 2. The Daily Loop

The order matters. Steps 1 and 2 exist because of engine quirks, not ceremony.

```powershell
# 1. If you ADDED a new class_name this session — refresh the global class cache.
#    Skip this and --script fails with "Could not resolve external class".
& $GODOT --headless --editor --quit --path game

# 2. That import REWRITES game/project.godot (reorders sections, strips comments). Undo it.
git -C "C:\Claude\American Tycoon" restore game/project.godot

# 3. Parse-check the file you just edited (fast, ~1s).
& $GODOT --headless --path game --check-only --script res://scripts/core/GameState.gd

# 4. Boot the real project for a few frames — catches what the gates cannot.
& $GODOT --headless --path game --quit-after 90

# 5. Run every gate before you call anything done.
pwsh tools\run_gates.ps1
```

**Why step 4 is not redundant with step 5.** A bad autoload, a missing resource, or a parse error in
a scene no gate touches will pass all twelve gates and still fail the moment the real project starts.
`run_gates.ps1` folds a 150-frame boot check in for exactly this reason.

**A caution about step 3.** A standalone `--check-only` on a single **UI** script reports spurious
*"identifier not declared"* for `class_name` and preload references, because the file is compiled
outside project context. On UI scripts, treat a clean editor import plus a successful boot as the
authoritative answer — not `--check-only` alone.

---

## 3. Unit Tests — The Verification Gates

The equivalent of a unit test suite here is `game/sim/`: standalone `SceneTree` scripts that load the
**same `ConfigLoader` the game does**, so a test and the game can never drift on rules or numbers.

**28 scripts live in `sim/`. Only 12 are tests.** The rest are studies (§4) that print numbers and
are not pass/fail. Running a study as if it were a test produces noise; running *some* of the gates
produces false confidence.

### 3.1 Run the suite

```powershell
pwsh tools\run_gates.ps1              # 11 headless gates + the boot check   ← the default
pwsh tools\run_gates.ps1 -All         # ...plus PortraitSheet (opens a window, ~30s)
pwsh tools\run_gates.ps1 -Only Audio  # substring filter: runs AudioSettingsTest + AudioCoreTest
pwsh tools\run_gates.ps1 -Godot "C:\other\path\godot_console.exe"   # override the binary
```

**Exit code 0 = all green. 1 = something failed. 2 = Godot binary not found.**

Output is deliberately quiet: one `PASS`/`FAIL` line per gate, and **only failures print their last
25 lines of output**. A passing gate's chatter is what makes people stop reading the summary.

> **The runner judges by exit code, never by scraping output.** Every gate calls `quit(0)` or
> `quit(1)`, which is the one signal that cannot drift. The human-readable summary lines already
> *did* drift — `MatchThreeTest` prints "ALL TESTS PASS" while everything else prints "ALL CHECKS
> PASSED" — and that is precisely how a grep-based runner misses a gate while appearing to pass.

### 3.2 Run one gate by hand

Generic form:

```powershell
& $GODOT --headless --path game --script res://sim/<GateName>.gd
echo $LASTEXITCODE     # 0 = pass, 1 = fail
```

Every gate, written out:

```powershell
& $GODOT --headless --path game --script res://sim/MoneyTest.gd
& $GODOT --headless --path game --script res://sim/EpochTest.gd
& $GODOT --headless --path game --script res://sim/ChallengeGoalsTest.gd
& $GODOT --headless --path game --script res://sim/MatchThreeTest.gd
& $GODOT --headless --path game --script res://sim/RushOverheatTest.gd
& $GODOT --headless --path game --script res://sim/AutoPurchaseTest.gd
& $GODOT --headless --path game --script res://sim/MomentumBarStateTest.gd
& $GODOT --headless --path game --script res://sim/ScrollEdgeFadeTest.gd
& $GODOT --headless --path game --script res://sim/IncomeReadoutTest.gd
& $GODOT --headless --path game --script res://sim/AudioSettingsTest.gd
& $GODOT --headless --path game --script res://sim/AudioCoreTest.gd

# PortraitSheet is the exception — it CANNOT run headless.
& $GODOT --rendering-driver opengl3 --path game --script res://sim/PortraitSheet.gd
```

### 3.3 What each gate covers

| Gate | Covers | Run it when you touch… |
| :--- | :--- | :--- |
| `MoneyTest` | Number formatting across all three display modes | `Money.gd`, any currency format work |
| `EpochTest` | Epoch staffing, the 27-tier ladder, **save migration** | `EpochCatalog`, `EpochState`, anything with `SAVE_VERSION` |
| `ChallengeGoalsTest` | Challenge tier ladders, both reward tracks, the met-minigame set | `ChallengeGoals`, `ChallengeScores` |
| `MatchThreeTest` | `MatchThreeBoard`'s pure logic — matching, cascades, Legacy gems | `MatchThreeBoard.gd` |
| `RushOverheatTest` | The push-your-luck heat model: bands, vents, overheat, re-arm | `RushMomentumState.gd` |
| `AutoPurchaseTest` | The Acquisitions Desk's buying policy and its lockouts | `AutoPurchaseState.gd` |
| `MomentumBarStateTest` | The bar paints the state Main pushed it, never its own guess | `MomentumBar.gd`, `Main.gd`'s bar wiring |
| `ScrollEdgeFadeTest` | List fade against an unlaid-out viewport (the invisible-content bug) | Scroll containers, edge fades |
| `IncomeReadoutTest` | What a property row displays: income label and cycle bar | `PropertyRow.gd` |
| `AudioSettingsTest` | Every `ui_` preference survives a save **and** a succession | **Any new player preference** |
| `AudioCoreTest` | Mute, voice pool, pitching, cue coverage | `Audio.gd` |
| `PortraitSheet` ⚠ | Renders all 25 alien civs and checks them | `StafferFace.gd` |

⚠ **`PortraitSheet` cannot run headless.** With no framebuffer there is nothing to capture and
`get_image()` returns null. It needs `--rendering-driver opengl3`, opens a window for ~30 seconds, and
is opt-in via `-All`.

**`AudioSettingsTest` deserves special mention.** It asserts generically against the property list
rather than a fixed set of fields, so a preference added later is covered without editing the test.
It guards a bug class that has actually bitten: `DynastyState._new_generation` builds a brand-new
`GameState`, so any player choice parked there silently reverts on every prestige unless
`_carry_player_settings_to_heir` copies it. `ui_buy_mode` and `ui_minigame_enabled` were lost that way
for months.

### 3.4 Gotchas when running or writing tests

- **Sims load the BAKED defaults** — `ConfigLoader.load_tuning(false)` — never a device's user
  overrides. A study measures the authored curve, not whatever your phone happens to have.
- **To test a custom tuning value, set the TUNING FIELD and *then* build the dynasty.** Poking a
  catalog's `static var` directly does nothing: `DynastyState` re-pushes tuning config on every
  construction and overwrites it.
- **Autoload globals are not in scope under `--script`.** The script passed to `--script` compiles
  before autoloads register, so a sim cannot name `Audio` directly:
  ```gdscript
  # WRONG — Audio is not a known identifier here
  Audio.play_cue("buy_success")

  # RIGHT — resolve it after awaiting a frame
  await process_frame
  var audio := root.get_node_or_null(^"Audio")
  ```
  During `_initialize()` the root is not yet in the tree, so an absolute path errors. A scene
  instantiated later, like `Main.tscn`, uses the global name freely.
- **During `_initialize()`, `add_child` does not run `_ready`** — the root is not in the tree yet.
  Await a frame before touching anything a node builds there.
- **`ObjectDB instances leaked / resources still in use at exit` is normal** `SceneTree`-script
  teardown noise, not a failure.
- **A new `class_name` used by a sim needs an editor import first**, or `--script` errors "Could not
  resolve external class."

---

## 4. The Study Tools

**Run these when you have a question — never to verify a change.** They print numbers or write files;
they do not assert.

```powershell
& $GODOT --headless --path game --script res://sim/<StudyName>.gd
```

| Study | Answers |
| :--- | :--- |
| `Sim` | The balance simulator entry point (Mechanics Spec §13) |
| `PaceStudy` | The two-clock tuning readout (`Plans/Core_Pace_Study.md`) |
| `PaybackStudy` | How long a rung takes to pay for itself |
| `PrestigeStudy` | Prestige yield vs. cost — the "reward pushing a run" re-tune |
| `DynastyArcStudy` | The endgame economy's primary fit instrument (fitted the deep-band constants) |
| `AutoPurchaseCostStudy` | Fitted the two Acquisitions Desk upgrade curves |
| `BlueCollarStudy` | The Blue Collar epoch threshold |
| `EpochPaceStudy` | How long each epoch takes to clear, at different Legacy stacks |
| `EpochPhaseStudy` | Inside one epoch: how much time is unlocking vs. stacking |
| `EpochCadenceStudy` | Whether a per-epoch income decay creates the intended cadence |
| `EpochDepthCheck` | Reachability of the deep ladder |
| `UnlockCadence` | How often the player gets a NEW PROPERTY beat |
| `VentBonusStudy` | The vent-bonus ladder (modelled 2026-08-10) — **newest; not yet in `sim/CLAUDE.md`** |
| `DumpLiveCivData` | Exports the live property ladder + staffer rosters |
| `AudioCueDoc` | **Writes** `game/audio/README.md` from the cue table — a generator, not a test |
| `BubbleProbe` | Throwaway probe kept for reference |

**Regenerating the audio cue documentation** — the one study with a side effect:

```powershell
& $GODOT --headless --path game --script res://sim/AudioCueDoc.gd
```

Edit `CUES` in `scripts/audio/Audio.gd` (and `TRIGGERS` in `sim/AudioCueDoc.gd` for the
descriptions), then re-run the above. **Never hand-edit `game/audio/README.md`** — it is generated
and your edit will be overwritten.

---

## 5. Writing a New Gate

A new test is not part of "is this change safe" until **both** of these are true:

1. **It calls `quit(0)` on success and `quit(1)` on failure.** The runner judges by exit code and
   nothing else. A test that prints "FAILED" and exits 0 is invisible.
2. **Its name is added to the `$headless` array in `tools\run_gates.ps1`.** A gate the runner does
   not know about is a gate nobody runs.

Skeleton:

```gdscript
extends SceneTree

# One-line statement of what this gate protects and why it exists.

func _initialize() -> void:
    var failures := 0

    var tuning := ConfigLoader.load_tuning(false)   # false = baked defaults, not user overrides
    var dynasty := DynastyState.new(tuning)

    if some_condition_that_should_hold():
        print("  OK: the thing holds")
    else:
        push_error("FAIL: the thing did not hold")
        failures += 1

    if failures == 0:
        print("ALL CHECKS PASSED")
        quit(0)
    else:
        print("FAILURES: %d" % failures)
        quit(1)
```

Then:

```powershell
& $GODOT --headless --editor --quit --path game    # if the gate uses a new class_name
git -C "C:\Claude\American Tycoon" restore game/project.godot
& $GODOT --headless --path game --script res://sim/MyNewTest.gd
echo $LASTEXITCODE
pwsh tools\run_gates.ps1 -Only MyNew
```

Godot 4.4+ also writes a `.gd.uid` sidecar next to the new script. **Commit it** — 96 `.uid` files
are tracked in this repo, and leaving one out is an inconsistency the next machine will trip over
(see [§9](#9-pre-migration-checklist-antigravity)).

---

## 6. Godot CLI Reference

Every invocation this project uses, with what each flag is for.

| Purpose | Command |
| :--- | :--- |
| **Parse-check one script** | `& $GODOT --headless --path game --check-only --script res://scripts/…gd` |
| **Run a gate or study** | `& $GODOT --headless --path game --script res://sim/….gd` |
| **Run a gate needing a renderer** | `& $GODOT --rendering-driver opengl3 --path game --script res://sim/PortraitSheet.gd` |
| **Boot check (headless)** | `& $GODOT --headless --path game --quit-after 90` |
| **Boot check (the runner's depth)** | `& $GODOT --headless --path game --quit-after 150` |
| **Refresh the class cache** | `& $GODOT --headless --editor --quit --path game` |
| **Open the editor normally** | `& $GODOT --path game --editor` |
| **Run the game on desktop** | `& $GODOT --path game` |
| **Export Windows** | `& $GODOT --headless --export-release "Windows Desktop" "../dist/american_tycoon_win.exe"` *(from `game/`)* |
| **Export Android** | `& $GODOT --headless --export-release "Android" "../dist/american_tycoon.apk"` *(from `game/`)* |
| **Export a debug build** | same as above with `--export-debug` |

| Flag | Does |
| :--- | :--- |
| `--headless` | No window, no renderer. Required for gates; **breaks anything calling `get_image()`** |
| `--path game` | Points at the project directory — this repo's project is `game/`, not the root |
| `--script res://…` | Runs a `SceneTree` script standalone. **Autoloads are not registered when it compiles** |
| `--check-only` | Parse without running. Unreliable alone on UI scripts (see §2) |
| `--quit-after N` | Runs N frames then exits — the boot check |
| `--editor --quit` | Imports the project and exits. **Rewrites `project.godot`** |
| `--rendering-driver opengl3` | Forces a real renderer; opens a window |
| `--export-release "<preset>"` | Preset name must match `export_presets.cfg` exactly: `Windows Desktop` or `Android` |

**The two commands that must always travel together:**

```powershell
& $GODOT --headless --editor --quit --path game
git -C "C:\Claude\American Tycoon" restore game/project.godot
```

The import rewrites `project.godot` — reordering sections and stripping comments — every single time.
Restoring it immediately is the only way not to ship the churn.

---

## 7. Export & Build Commands

### 7.1 One-off export by hand

```powershell
cd "C:\Claude\American Tycoon\game"
New-Item -ItemType Directory -Force ..\dist | Out-Null

& $GODOT --headless --export-release "Windows Desktop" "..\dist\american_tycoon_win.exe"
& $GODOT --headless --export-release "Android"         "..\dist\american_tycoon.apk"
```

Android requires `build/android_release.keystore` present **and** the keystore password written into
`game/export_presets.cfg` (it ships blank).

### 7.2 The full local build

```powershell
cd "C:\Claude\American Tycoon"
build\build.bat
```

Three steps — Windows export → Inno Setup installer → Android APK — with output in `dist\`.

**Two prerequisites the script assumes and this machine does not satisfy by default:**

1. **`build.bat` expects `godot` on PATH**, unlike every other command in this document. Either add
   it to PATH or edit the `set GODOT=` line to the absolute path.
2. **The keystore password must be in `game/export_presets.cfg`.** Protect it:
   ```powershell
   git -C "C:\Claude\American Tycoon" update-index --skip-worktree game/export_presets.cfg
   ```
   Remember you did this — `skip-worktree` also silently ignores *legitimate* later changes to the
   preset, which is its own trap. To undo: `--no-skip-worktree`.

> ⚠️ **A local APK will usually refuse to install over a CI build.** `build.bat` does not stamp
> `version/code`, so local builds stay at `1` and Android treats them as a downgrade. Uninstall
> first, or stamp it by hand.

### 7.3 Building through CI instead (recommended)

Pushing is the supported path — it stamps versions correctly, signs reproducibly, and puts the APK on
your phone:

```powershell
git -C "C:\Claude\American Tycoon" push origin feature/my-branch
```

Watch it, using the gh CLI:

```powershell
& "C:\Program Files\GitHub CLI\gh.exe" run list --limit 5
& "C:\Program Files\GitHub CLI\gh.exe" run watch
& "C:\Program Files\GitHub CLI\gh.exe" run view --log-failed
```

Full pipeline details in `CI_CD_FIREBASE.md`.

---

## 8. Git Workflow

**Always use `git -C "<path>"` — never `cd` first.** This matches the `PowerShell(git *)` allow list,
so the commands run without a permission prompt.

```powershell
$REPO = "C:\Claude\American Tycoon"

git -C $REPO status --short
git -C $REPO branch --show-current
git -C $REPO checkout -b feature/my-thing
git -C $REPO add -A
git -C $REPO commit -m "A sentence describing what changed"
git -C $REPO push -u origin feature/my-thing
```

**Rules:**

- `main` is the stable default branch. **Confirm before pushing `main`** — a push there cuts a full
  release (installer + APK + GitHub pre-release).
- Feature branches push freely; every push ships a Firebase APK to the phone.
- Delete merged branches (local + remote + worktree); keep shelved ones.
- **Changed an import setting? Force-add the `.import` file** — they are gitignored:
  ```powershell
  git -C $REPO add -f game/audio/cues/my_cue.wav.import
  ```
  This is not optional. The WAV importer defaults to QOA compression and these samples are PCM; a
  lost import setting means every sample decodes on the way out, and it *works on your machine*
  while shipping broken.

---

## 9. Pre-Migration Checklist (Antigravity)

Four things in the working tree should be resolved before the repo moves to another tool. None is
urgent for the game; all three of the first are the kind of thing that reads as "the migration broke
it" when discovered later.

### 9.1 95 phantom-modified files — no `.gitattributes` (do this first)

`git status` currently shows **95 modified `.import` files with zero content difference.** They are
line-ending noise: `core.autocrlf=true` is set globally, the repo has **no `.gitattributes`**, and
Godot writes these files with LF. Git wants CRLF in the working tree, so it flags every one as
modified while `git diff` produces no hunks at all.

This matters for a migration specifically: a new tool, a fresh clone, or a second machine will
produce a different phantom-diff set, and the first person to `git add -A` commits 95 meaningless
line-ending changes that bury the next real diff.

**The fix is a `.gitattributes` at the repo root** — I have not created one, since it rewrites how
git normalizes every file in the project and that is your call:

```gitattributes
* text=auto

# Godot text formats — keep LF, which is what the engine writes
*.gd        text eol=lf
*.tres      text eol=lf
*.tscn      text eol=lf
*.import    text eol=lf
*.godot     text eol=lf
*.cfg       text eol=lf
*.uid       text eol=lf

# Windows-native tooling
*.ps1       text eol=crlf
*.bat       text eol=crlf
*.iss       text eol=crlf

# Binary — never normalize
*.png binary
*.jpg binary
*.svg text eol=lf
*.wav binary
*.ogg binary
*.keystore binary
```

Then renormalize once, in its own commit so it never obscures a real change:

```powershell
git -C $REPO add .gitattributes
git -C $REPO commit -m "Add .gitattributes: pin Godot text formats to LF"
git -C $REPO add --renormalize .
git -C $REPO commit -m "Renormalize line endings"
```

### 9.2 One untracked `.uid` file

`game/sim/VentBonusStudy.gd.uid` is untracked while **96 other `.uid` files are tracked**. Godot 4.4+
generates these as stable resource identifiers; an inconsistent set causes avoidable reimport churn.

```powershell
git -C $REPO add game/sim/VentBonusStudy.gd.uid
```

### 9.3 `sim/CLAUDE.md` says 27 scripts; there are 28

`VentBonusStudy` (added by `887a36b`, "the vent ladder measured") appears in **neither**
`game/sim/CLAUDE.md`'s inventory **nor** `tools/run_gates.ps1`. It is a study, not a gate, so its
absence from the runner is correct — but its absence from the inventory is exactly the ambiguity that
document exists to eliminate. It is listed in [§4](#4-the-study-tools) of this document.

### 9.4 Three new docs are uncommitted

`docs/PROJECT_GUIDELINES.md`, `docs/ARCHITECTURE_AND_ROADMAP.md`, `docs/CI_CD_FIREBASE.md`, and this
file are untracked on `main`. They are the migration payload — commit them before the move.

### 9.5 What carries the context after the move

The `CLAUDE.md` files are Claude Code-specific. **Their content is now consolidated into `docs/`,
which is tool-neutral** — that consolidation *is* the migration work:

| Was | Is now |
| :--- | :--- |
| 9 × `CLAUDE.md` (global, project, 3 subsystem, 2 backup) | `docs/PROJECT_GUIDELINES.md` |
| Tribal knowledge of the code map | `docs/ARCHITECTURE_AND_ROADMAP.md` |
| Pipeline knowledge in workflow comments | `docs/CI_CD_FIREBASE.md` |
| Remembered command incantations | **this file** |

**Do not delete the `CLAUDE.md` files** as part of the migration. They remain authoritative for their
own folder, they are where a subsystem rule naturally belongs, and `PROJECT_GUIDELINES.md` records
that folder-level rules are *additive*. Point the new tool at `docs/` and leave the source files
alone.

Two known contradictions between those files and the code are documented in
`ARCHITECTURE_AND_ROADMAP.md` §3.4 and worth fixing before anyone new reads them: the root
`CLAUDE.md` claims there are no autoloads (there is one — `Audio`), and it still calls the M1 brief
"canon for the current milestone scope."
