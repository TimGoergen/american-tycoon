# Challenge Mode Gating — Implementation Plan

Graduates **Roadmap §5** (Challenge Mode gated until after the first prestige) and **Roadmap §8**
(only show minigames you have met). Branch: `feature/challenge-mode-gating`, cut from `main`.

Both entries are Tim's and fully decided; this document adds the implementation shape, one
simplification found in the code, and one gap the Roadmap did not cover.

Together the two gates turn CHALLENGES from a list handed over up front into a trophy case of
games you have earned, with each new one appearing as a small reward in itself.

---

## The simplification: "Challenge Mode must not count as an encounter" is free

Roadmap §8 worries that a game met inside Challenge Mode would circularly unlock itself there,
and points at `MinigameScreen.start_game`'s `forced_type` path as the place to tell real
encounters from review ones.

In the shipped code the separation is cleaner than that: **Challenge Mode does not go through
`start_game` at all.** It uses a separate entry point, `MinigameScreen.start_challenge(type_script)`
(`MinigameScreen.gd:1314`). So marking encounters inside `start_game` — and simply never touching
`start_challenge` — gives the required behaviour by construction rather than by a conditional.

Within `start_game`, the mark still goes in the `forced_type == null` branch
(`MinigameScreen.gd:1218-1229`), so a **review** round from the Minigame Tuning screen (which
passes an explicit type) also does not count. Only a real transition deals a random game, and only
that path marks.

---

## The gap: what happens to a save that predates the feature

Roadmap §8 does not say. Left alone, an absent encounter set defaults to empty — so an existing
player who has already met every game would open CHALLENGES and find **everything locked**, having
lost access to games they demonstrably met.

That is the exact failure mode §8 itself rejects when it rules out per-generation scoping: a player
who prestiged "would lose access to games they had demonstrably met while their SCORES for those
games stayed on screen — a rule that reads as a bug."

**Resolution: seed the set on first load from the bloodline's own evidence.** When the
`met_minigames` key is absent, seed it with the keys of `challenge_highest_tiers` — you cannot have
banked a cleared tier in a game without having played it. This is generous, in-save, uses the same
dynasty-scoped record, and needs no new data. A fresh dynasty has an empty
`challenge_highest_tiers`, so it correctly starts with nothing met.

---

## Part A — §5: gate the screen behind the first prestige

The gate signal already exists as a named helper: `Main._ledger_unlocked()` (`Main.gd:1984`),
which is `dynasty.ancestors.size() > 0` — literally what §5 specifies, and already the Ledger
tab's own gate.

- The Settings CHALLENGES button is currently created inline with no reference kept
  (`Main.gd:1581`). Capture it in a member so its state can be refreshed.
- Per the no-moving-UI rule it **grays in place, never hides**, with the reason on a second line:
  `CHALLENGES` / `AFTER YOUR FIRST SUCCESSION`. The two-line-label-on-a-disabled-button pattern is
  already used by the retention rows (`LegacyScreen.gd:717`) and PASS THE TORCH (`Main.gd:2172`).
- **A disabled `Button` needs its own gray `disabled` stylebox**, or only the text grays. Use the
  locked-tab treatment (`LIGHT_GRAY` bg / `MID_GRAY` border, `Main.gd:1793-1796`).

Note this is the ordinary gray-in-place case, NOT the hide-until-unlocked exception Tim made for
the AUTO-BUY and HIRE toggles on 2026-08-01. That exception existed because those buttons had no
room for a reason and it had ended up in a tooltip, which is invisible on touch. Here there is
room for the reason on the button itself, so the standing rule applies.

---

## Part B — §8: show only games you have met

### The encounter set

A new dynasty-scoped field beside `challenge_highest_tiers` (`DynastyState.gd:55`), which §8 names
as the placement precedent:

```gdscript
var met_minigames: Dictionary = {}   # {display_name(): true} — a set; the value is never read
```

- Keyed by `Minigame.display_name()`, the same key `ChallengeGoals`, `ChallengeScores` and
  `challenge_highest_tiers` all use (`ChallengeGoals.gd:32-35`). Anything else would drift.
- Written in `to_save_dict` beside `challenge_highest_tiers` (`DynastyState.gd:477`), read back in
  `load_save_dict` (`:500`) with `.duplicate()` — the house rule there is that the loaded dynasty
  must own its own container, not the save's.
- **No `SAVE_VERSION` bump.** An absent, safely-defaulted additive key needs none; that is the
  precedent set by `ui_currency_format` on 2026-08-05. (`game/scripts/core/CLAUDE.md:12-13` still
  states the older always-bump rule — worth reconciling one day, but not in this change.)
- Scoped to the DYNASTY: prestige does not clear it, only wiping the save does. That falls out of
  the placement for free rather than needing its own reset path.

### Marking an encounter

In `MinigameScreen.start_game`, inside the `forced_type == null` branch, after the type is chosen
(`MinigameScreen.gd:1229`), mark `_active_minigame.display_name()`. The instance already exists
there, so no probe is needed.

### Rendering a locked game

`ChallengesScreen._make_game_panel` (`ChallengesScreen.gd:294`) already computes `game_key`
(`:284`) and already stacks two info labels in a VBox (`:343-351`) inside a 180px-tall row — so a
third "reason" line is a small insert with room to spare.

- Locked games stay **VISIBLE and grayed in place** with the reason `MEET THIS GAME AT A TRANSITION`
  — never hidden. Besides the no-moving-UI rule, this is what preserves the trophy-case read: you
  can see what you have not met yet.
- **`ChallengesScreen` currently registers the SAME green plate for `disabled` as for `normal`**
  (`:307-311`). Setting `disabled = true` would gray only the text and leave the plate looking
  live — the exact "unresponsive live-looking control reads as a bug" failure. A real gray
  `disabled` stylebox is required.

### The Balance Tuning override

Required, not a nicety: with six games dealt at random, testing one specific game otherwise means
replaying transitions until it comes up — the workflow this gate would make worse.

- `DevTuningPanel` is pure reflection over `TuningConfig` and **only renders INT and FLOAT
  properties** (`DevTuningPanel.gd:808-819`), so a `bool` export would be silently skipped. The
  house convention is a 0/1 float knob read as `> 0.5` (`carb_debug_overlay`, `PropertyRow.gd:1272`).
- Name it `challenge_show_all_games`. Anything prefixed `challenge_` falls through to the panel's
  catch-all section, which is titled "Challenge Mode" (`DevTuningPanel.gd:306`) — so it lands in
  the right section with **zero panel edits**.
- **Display override ONLY.** It must never write to the encounter set, or one testing session
  permanently unlocks everything and the gate can never be seen again.
- `ChallengesScreen.setup` already receives `tuning` but does not store it (`:92`) — it needs a
  `_tuning` field.

---

## Verification

- Extend `sim/ChallengeGoalsTest.gd` (permanent tooling — extend, do not add a sibling), which
  already has a save round-trip including an "old save missing the key" case (`:311-353`).
- Assertions: an absent key seeds from `challenge_highest_tiers`; a fresh dynasty starts empty;
  the set survives a succession; a marked game persists through save/load; and the override never
  mutates the set.
- Parse-check every touched script; boot headless; re-run `MoneyTest` and `EpochTest`.

---

## Open question for Tim

**Should the dev Reset clear the encounter set?** `Main.gd:2101-2109` currently clears
`ChallengeScores` and `TutorialProgress`. §8 says "only wiping the full game save" clears
encounters, and the set lives in the dynasty save — so a save wipe already handles it. The dev
Reset is a different, narrower path. Recommendation: leave it alone, so Reset stays a scores/tips
reset rather than quietly becoming a save wipe.
