# Minigame Polish Pass — Plan

**Created:** 2026-06-29
**Status:** **BUILT 2026-06-29** on `feature/minigame-polish-pass` (host shell + all six games +
the themed backdrop / translucent-card visual treatment Tim added during the pass). Decisions
locked 2026-06-29 (see §5). **Only step 5 remains: the on-device difficulty re-tune** — every
difficulty constant shipped is a first-pass hypothesis to confirm on the Pixel via Settings →
Minigame Tuning.
**As-built deltas from the plan:** (1) Tim added a full-bleed themed "Riches & Rolls" backdrop
behind both the minigame screen and the Tuning screen, with a 50%-alpha, smaller card — beyond
the original visual scope. (2) Match Three combo bonus left intentionally **unbounded** (a lucky
long cascade ending early is pure upside; you can never lose points). (3) Memory added an
`is_busy()` override so the host holds its countdown through the new end-beat/celebration.
**Scope (Tim's call):** The host shell (`MinigameScreen`) **and** each of the 6 individual
minigames.
**Focus areas (Tim's call):** Visual / layout · Juice / feedback · Feel / difficulty tuning.
*(Copy/clarity is out of scope as a primary goal, though some items touch wording.)*

---

## 0. Why this pass

The minigame library reached feature-complete across several earlier sprints (host shell, 6
types, 3 reward sites, the Tuning review screen). What it has **not** had is a deliberate
polish-and-feel pass: most scoring constants are flagged first-pass / un-playtested, and the
"juice" (animation, hit/miss emphasis, celebration) is uneven — some games (Basketball,
TimingBar) are richly animated, others (CatchMoney, Memory) are nearly static. This pass makes
the games feel consistent, readable, and good in the hand.

**Hard constraint:** the reward MATH is reward-agnostic and must stay so. Every game only
reports `get_performance() -> [0,1]`; the host maps that to the multiplier. Nothing in this
pass should change that contract — only how a round looks, feels, and how hard it is to score.

**Device-feel-test gate:** all difficulty constants below are tuned blind today. Nothing in the
"Feel / difficulty" sections should be considered final until Tim plays it on the Pixel. Treat
each numeric change as a hypothesis to confirm on hardware.

---

## 1. Host shell — `MinigameScreen.gd`

The shared frame every round runs inside: card/bezel, timer, keep-spectrum bar, Begin gate,
result reveal, skip/opt-out.

### Visual / layout
- **Timer prominence** (`~line 178`): currently FONT_SUBHEAD red text, easy to miss. Make it a
  real focal point (larger, more central) so time pressure reads.
- **Result-view transition** (`~line 574`): the play→result swap is an instant flip. Add a
  short fade/slide so the reveal feels like a payoff, not a cut.
- **Begin-gate dismiss** (`~line 443`): the cream scrim vanishes instantly on BEGIN; fade or
  slide it off to unmask the game.
- **Keep-bar edge** (`~line 535`): hard navy fill edge; consider a soft glow/cap at the fill
  edge that intensifies as performance climbs into bonus.
- **DECISION — strip the numbers off the spectrum bar** (`~lines 510–521`): the live keep
  readout (`"12 of 50"`, `"60 (+10 bonus)"`) goes away. The bar communicates by **fill + color
  only** (warm→green→cool). This keeps it clean and avoids exposing raw scoring internals that
  differ per game. The *result* screen still shows the concrete reward; the in-round bar does
  not.

### Juice / feedback
- **Keep-bar fill** (`~line 536`): jumps instantly to `fill_frac`. Lerp it so it glides as
  performance updates — the single most-visible shared element, worth smoothing once here.
- **Timer warning state** (`~lines 458–459`): no change as time runs low. Add a ≤10s (and
  ≤3s) state — color pulse / blink / scale — shared by every game for free.
- **1.0× threshold crossing** (`~lines 515–521`): the warm→green color jump is good but silent;
  add a small pop/flash when the keep label first crosses into "full", and again into bonus.
- **Result multiplier reveal** (`~lines 555–566`): final number appears instantly. Count-up /
  color-bloom the multiplier and amount for the payoff beat.
- **Frozen-clock indicator** (`~line 454`): `is_busy()` pauses the countdown during
  cascades/freezes, but the player gets no cue the clock is held. Small "paused" tick on the
  timer so a stalled countdown doesn't read as a bug.

### Feel / difficulty (shared knobs)
- **DECISION — per-game timing & end states are sanctioned** (`minigame_duration_seconds` +
  `extra_seconds()`, `~lines 392, 424`): games do **not** all have to run the same 20s or end
  the same way. Match-3 ending early at `SCORE_MAX`, Balance/Catch running to the countdown,
  Basketball/Memory ending at a target count — all kept. Where a game wants a different round
  length, use/extend the per-type hook (today `extra_seconds()`; widen it to a full per-type
  "preferred duration + end condition" if needed). The host must keep treating every game
  through the same `get_performance()` contract regardless of how/when it ends.
- **DECISION — the SKIP button shows the reward, not the numbers** (`~line 206`): replace
  "SKIP (keep the minimum)" with the concrete kept reward the skip banks (e.g. the keep-floor
  amount / "keep 50%"). This is the one place the floor is made legible now that the spectrum
  bar's numbers are gone. The reward shown should read from the same keep-floor the host already
  applies on skip (`~line 590`).
- **Bonus-cap visibility** (`_bonus_max`, `~line 391`): with bar numbers gone, do NOT add a
  numeric cap marker — keep the bar clean. (Superseded by the strip-the-numbers decision.)

> Doing the timer-warning, keep-bar lerp, and result reveal **once in the host** lifts all six
> games at once — start here before per-game work.

---

## 2. Per-game polish

For each game: **V** = visual/layout, **J** = juice/feedback, **F** = feel/difficulty. Constants
cited from the inventory; line numbers are approximate.

### DECISION — per-game difficulty direction
Difficulty is **not** moved uniformly. Each game gets its own direction (Tim, 2026-06-29);
"clearer" means readability/feedback work, not necessarily a difficulty change. These are
hypotheses to confirm on hardware in the §3 step-5 device session.

| Game | Direction | Why |
|---|---|---|
| Match Three | **Clearer** (hold difficulty) | Already deep; the avoid-gem rule and cascades are confusing, not too easy. Make the rules read; re-anchor scores but don't crank. |
| Timing Bar | **Harder** | Gentle zone-shrink (0.06 floor = half) and speed-ramp (1.06×); steepen for real tension. |
| Catch Money | **Harder + clearer** | Flat, lenient, and nearly invisible feedback. Make coins readable AND make the round escalate. |
| Memory | **Clearer / confirm** | 8 rounds is fine; mostly confirm flash speed is followable and add a game-over/clear beat. |
| Balance | **Slightly harder / confirm** | Confirm the drift is controllable-but-tense; nudge drift up only if it feels floaty. |
| Basketball | **Hold (celebration only)** | Most playtested; physics feels right. Add the win celebration, leave difficulty. |

### 2.1 Match Three — `MatchThreeMinigame.gd` (+ `core/MatchThreeBoard.gd`)
Drag-swap gems; one "avoid" gem per round (clean match ×1.15, avoid match ×0.40); cascades earn
a rising combo multiplier; round ends early at `SCORE_MAX`. Already the most-animated game
(flash/clear/fall/spawn/swap tweens, rising score badges).
- **V**: drag highlight (modulate 1.35× + scale 1.08×, `~325`) reads weakly on cream — make
  "selected" obvious. AVOID banner (`~183`) is static; animate it on round start.
- **J**: cascades have no chain signal (`~444`) — add a connecting glow / combo-step flourish.
  No celebration when score hits `SCORE_MAX` (`~451`) — the round just ends.
- **F**: `POINTS_PER_GEM` trimmed 10.0→9.5 without re-tuning `SCORE_FULL` (300) / `SCORE_MAX`
  (1000) (`~49–55`) — re-anchor the three together on hardware. Combo bonus is unbounded
  (`~42`); a long cascade can instantly end the round — decide if that's desirable.

### 2.2 Timing Bar — `TimingBarMinigame.gd`
Tap LOCK to catch a sweeping marker in a shrinking gold zone; 10 locks; accuracy = center
distance; marker speeds up each lock; miss costs a lock. Rich freeze-burst feedback already.
- **V**: zone-shrink and speed-ramp are invisible until felt (`~203`, `~180`) — add a cue.
  Click-feedback lines are all white (`~236`); color them green-hit / red-miss.
- **J**: miss burst (gray, `~251`) is weaker than the hit burst — give misses a shake/grow so
  the −1-lock penalty (`~168`) actually stings and reads.
- **F**: re-playtest `TARGET_LOCKS` 10 with the 0.5s freeze + countdown interaction (`~18`).
  `ZONE_HALF_MIN` (0.06, half the start) and `SPEED_RAMP` (1.06×) are gentle — candidates to
  steepen for a difficulty spike, on hardware.

### 2.3 Catch Money — `CatchMoneyMinigame.gd`
Coins fall every 0.55s; tap to catch (+1) or let drop (−0.5); coins shrink 5% per catch; 18
coins. **Currently the least-juiced game — no catch/miss feedback at all.**
- **V**: coins are bare "$" buttons with no outline (`~113`), hard to see against mustard. Add
  an outline/glint and a spawn entrance.
- **J**: **highest-value target of the pass** — catch has no popup/glow/particle (`~121`), miss
  vanishes silently (`~94`). Add "+1" pops, a catch flash, and a miss cue.
- **F**: difficulty is flat (constant `SPAWN_INTERVAL` 0.55, gradual shrink). `MISS_PENALTY`
  0.5 is lenient. Consider a gentle spawn ramp or late-round "rush" so the round escalates.

### 2.4 Memory — `MemoryMinigame.gd`
Simon-style recall; watch a growing sequence flash across four pads, repeat it; 8 rounds.
Pads light by color/border swap only.
- **V**: lit pad is just `lightened(0.45)` + thicker border (`~85`) — add scale/bounce on flash
  so playback reads at a glance.
- **J**: no game-over beat on a wrong tap (`~142`) and no round-clear celebration. The status
  label ("Watch…/Your turn…") could animate in.
- **F**: `TARGET_ROUNDS` 8, `FLASH_ON` 0.42s, `FLASH_GAP` 0.18s are first-pass (`~11–16`) —
  confirm the sequence speed feels fair (not too fast to follow, not sleepy) on hardware.

### 2.5 Balance the Books — `BalanceMinigame.gd`
Hold LEFT/RIGHT to keep a drifting marker inside a wandering gold zone; performance = time in
zone; host countdown ends it. Smooth zone easing already.
- **V**: 14px marker (`~162`) is thin/hard to track — enlarge, add a shadow/trail.
- **J**: zone boundary is static — brighten/pulse it as the marker nears the edge (`~142`);
  bounce/pulse the marker while it's safely in-zone; scale the ◄ ► buttons on press (`~66`).
- **F**: `ZONE_HALF` 0.13, `DRIFT_MAX` 0.9, `DAMPING` 2.4 etc. (`~13–23`) un-flagged but
  un-playtested — confirm the drift is controllable-but-tense, not floaty or twitchy.

### 2.6 Micro Basketball — `BasketballMinigame.gd`
Slingshot a ball through a moving hoop; freeze-and-reshoot mid-air; 6 baskets. **Most polished
game already** (rim flash, spin, aiming guide, tuned physics) — use it as the quality bar.
- **V**: caught ball snaps to 1.12× (`~406`) — tween it.
- **J**: a made basket only flashes the rim (`~280`) — add a real celebration (net swing,
  score pop, small particle spray). Near-miss rim bounces (`~292`) could splash on impact.
- **F**: `TARGET_BASKETS` 6 is explicitly FEEL-TUNE-flagged (`~19`); physics is the most
  playtested in the set — likely the least-needy on difficulty, most-needy on celebration.

---

## 3. Suggested sequencing

1. **Host shared juice first** — timer warning state, keep-bar lerp, result-reveal transition,
   frozen-clock cue. One change, all six games benefit.
2. **Catch Money + Memory** — the two least-juiced games; biggest perceived-quality jump per
   hour. Bring them up to the Basketball/TimingBar bar.
3. **Match Three + Timing Bar** — already animated; add the missing celebration/chain cues and
   the difficulty-cue visuals.
4. **Balance + Basketball** — smallest gaps; marker/visibility (Balance) and celebration
   (Basketball).
5. **Difficulty re-tune on hardware** — once the visuals/juice are in, do ONE device session
   re-anchoring every flagged constant (Match-3 score thresholds, Timing zone/speed, Catch
   ramp/penalty, Memory flash speed, Balance drift, Basketball target count). The Minigame
   Tuning review screen (Settings) is the tool for this — each type is previewable there.

## 4. Cross-cutting notes
- **Consistency is the real goal**: the six games were built in different sittings, so framing,
  banner styling, and celebration weight vary. A shared "win burst" and "miss cue" vocabulary
  (even if each game renders it slightly differently) will make the library feel authored.
- **Audio is unaddressed everywhere** — none of the games have SFX hooks. Out of scope for a
  pure visual/feel pass, but flag it: a lock chime / catch pop / cascade trill is where the next
  big juice gain lives, deferred to the M3 audio pass.
- **Low-vision first** (Tim's standing UI rule): keep targets large and high-contrast; several
  items above (coin outlines, bigger Balance marker, Match-3 drag highlight) are readability
  wins as much as polish.

## 5. Decisions (locked 2026-06-29)
1. **Per-game timing & end states are allowed.** Games keep their own round lengths and end
   conditions (early-end, countdown, target-count); the host still scores them all through the
   one `get_performance()` contract. See §1 Feel.
2. **Spectrum bar shows fill + color only — no numbers.** The in-round numeric keep readout is
   removed. The legibility of "what you'd keep" moves to the **SKIP button**, which now shows
   the concrete reward it banks. See §1 Visual + §1 Feel.
3. **Difficulty direction is per-game, not uniform.** Some games get harder (Timing Bar, Catch
   Money), some get clearer/confirmed (Match Three, Memory, Balance), Basketball holds. See the
   direction table at the top of §2.
