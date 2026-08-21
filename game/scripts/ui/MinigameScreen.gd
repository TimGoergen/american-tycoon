class_name MinigameScreen
extends ColorRect

# The minigame HOST (GDD §5.5). It picks a random minigame TYPE from the library, runs it,
# and converts its performance (0..1) into the universal outcome multiplier shared by every
# minigame: 0.5x (keep floor / skip) -> 1.0x (full) -> up to 1.0 + bonus_max (extra-high,
# bonus cap from the Family Reputation upgrade). The host owns everything common — the
# countdown, the live "kept" spectrum bar, the result, and the skip/opt-out — so all
# types behave identically; a type owns only its gameplay (see Minigame).
#
# The host is REWARD-AGNOSTIC: it only produces a multiplier (see `finished`) and shows a
# configurable reward noun, so the same minigames scale Legacy at the prestige site and the
# cash pile at the welcome-back site. The caller describes the reward via a context built by
# `legacy_reward` / `offline_pile_reward` (or `make_reward`) and passed to `start_game`.

## Emitted when the round ends (Continue or Skip). `multiplier` is the universal outcome
## multiplier (~0.5x .. 1.25x); the CALLER decides what it scales (the run's Legacy at
## prestige, the offline pile at welcome-back). `opt_out` true if the player asked to
## auto-skip future minigames.
signal finished(multiplier: float, opt_out: bool)

## Emitted only in review mode (Settings → Minigame Tuning) when the player taps the Back
## button to abandon the round and return to the review list. Carries no result — review
## play never affects the run's Legacy.
signal back_pressed

## Emitted alongside `finished` when the player collected a Legacy gem this round and the result
## wasn't bad — `amount` is the already-computed unearned Legacy to grant (see Plans/Legacy_Bonus_
## System.md). Main banks it to the dynasty wallet. Never emitted in review/Challenge or on Skip.
signal legacy_bonus_earned(amount: int)

## Emitted when a CHALLENGE run ends (DONE or Back), carrying the game's key (its display_name()) and
## the final Minigame.get_score() (Plans/Challenge_Mode.md §5 step 2). The host has NO dynasty, so it
## only reports the raw result — Main credits any newly-cleared tiers into the dynasty bonus and hands
## the outcome back via show_challenge_credit for the "NEW TIER" feedback. This is separate from the
## arcade high-score store (ChallengeScores), which _end_challenge still updates directly.
signal challenge_finished(game_key: String, final_score: int)

## Emitted when a REAL transition round deals a game, carrying that game's key (its display_name()) —
## the player has now MET it (Roadmap §8, Plans/Challenge_Mode_Gating.md). The host has NO dynasty
## (same reason challenge_finished exists), so it only reports the encounter; Main marks it on the
## dynasty via DynastyState.note_minigame_met and saves.
##
## Emitted ONLY from start_game's random-deal branch. See the emit site for why that placement gives
## the required "Challenge Mode must not unlock itself" behaviour for free.
signal minigame_met(game_key: String)

# The minigame library — the host draws one at random each round so the player doesn't know
# which they'll get. Add new types here (Phase 2).
const MINIGAME_TYPES := [
	preload("res://scripts/ui/MatchThreeMinigame.gd"),
	preload("res://scripts/ui/TimingBarMinigame.gd"),
	preload("res://scripts/ui/CatchMoneyMinigame.gd"),
	preload("res://scripts/ui/MemoryMinigame.gd"),
	preload("res://scripts/ui/BalanceMinigame.gd"),
	preload("res://scripts/ui/BasketballMinigame.gd"),
]

## The last randomly-dealt type, excluded from the next deal so the same minigame never
## comes up twice in a row (Tim, 2026-07-27). STATIC on purpose: prestige reloads the whole
## scene between transition rounds, and an instance field would forget the last deal exactly
## when it matters.
## Forced/review rounds neither read nor update it (they aren't random deals).
##
## PERSISTED since 2026-07-31 (Tim: "it seems common to be presented the same minigame at two
## transitions in a row"). It used to be memory-only, with an app restart clearing it and a
## repeat across that boundary written off as acceptable — but with six types that is a 1-in-6
## chance every launch, and short device-testing sessions cross that boundary constantly, so
## "possible" was showing up as "common". The last deal now survives a restart.
static var _last_dealt_type: Script = null

## Where the last deal is remembered between launches. Its own tiny file rather than a field in
## the dynasty save: this is a presentation detail, it must outlive any single dynasty, and it
## has no business forcing a save-format migration. Same pattern as TutorialProgress.
const LAST_DEALT_PATH := "user://minigame_history.json"

## The default purpose blurb shown in the play view's top section outside review mode. Each
## site passes its own line through its reward context (see `make_reward`); this is the
## prestige default, used when a reward omits a purpose.
const DEFAULT_PURPOSE := "Grow the inheritance"

## The full-bleed themed backdrop shown behind the card (Tim, 2026-06-29): a casino/library
## "Riches & Rolls" scene with an ornate empty frame in its center that the (now semi-transparent)
## card floats over. Sits inside the black screen bezel like every other screen's background.
const BACKGROUND_IMAGE := "res://art/backgrounds/minigame_background.png"

## The Legacy gem art for the shared "gem earned" badge (see _gem_badge) — the same gem used for the
## currency everywhere, so it reads instantly.
const LEGACY_GEM_TEXTURE := preload("res://art/icons/legacy_gem.svg")

## The centered panel that frames every minigame, as anchor fractions of the full-screen scrim, so
## it stays centered and scales with the screen. Shrunk 2026-06-29 (Tim): 20% shorter and 10%
## narrower than the original 0.84 tall / 0.95 wide, so more of the backdrop shows around it.
const PANEL_WIDTH_FRACTION := 0.855   # 0.95 * 0.90  (10% narrower)
const PANEL_HEIGHT_FRACTION := 0.672  # 0.84 * 0.80  (20% shorter)
## Thickness of that black outline. It is the ONLY thing setting the card apart from the cream
## background behind it (same fill), so it is deliberately thick and well above the 2px screen
## bezel frame.
const PANEL_BORDER_WIDTH := 8

## The SKIP / DONE control floats BELOW the card in the scrim (Tim, 2026-07-02).
const SKIP_BUTTON_HEIGHT := 101              # 72 * 1.4 — 40% taller
const SKIP_GAP_BELOW_PANEL := 16.0

## A generous, consistent margin between the chrome (Back / timer, spectrum bar, SKIP button) and the
## card edges (Tim, 2026-07-09) — beyond the card's own content margin. The play board still fills.
const CHROME_MARGIN := 28

## The "best" sub-lines in the two-corner Challenge header read in a darker gray beneath the black
## Score / Tier primaries (Tim, 2026-07-22), so the current value dominates and the record sits quietly
## under it. Darker than UiPalette.DARK_GRAY (#6E6E6E) so it still reads on the translucent cream card.
const CHALLENGE_BEST_GRAY := Color("#4A4A4A")

## How fast the spectrum bar's fill glides toward its true value (per-second lerp weight). The
## bar tracks a smoothed `_display_mult` rather than the raw live multiplier so it reads as a
## sweep, not a jitter — the single most-visible shared element, smoothed once here for all six
## games (plan §1 juice).
const KEEP_BAR_LERP_SPEED := 8.0
## For the last few seconds the shared timer PULSES once per second — bigger and brighter on each
## tick — so the countdown reads as real urgency (Tim, 2026-07-09). Shared by every game for free.
const TIMER_PULSE_SECONDS := 5.0

## Every line on the "Get Ready" gate is scaled up by this factor (Tim, 2026-07-10) so the pre-round
## text reads comfortably at arm's length. Applied to each label's font size and the BEGIN button.
## 1.4 landed between "didn't look bigger" (1.3) and "too big" (1.6) on device.
const GET_READY_TEXT_SCALE := 1.4

var _tuning: TuningConfig
## The pre-minigame base reward being scaled (Legacy count at prestige, cash pile at
## welcome-back). Kept as a float so it can hold either a small Legacy count or a large
## cash pile; the display formats it per `_format_as_money`.
var _base_amount: float = 0.0
## How the host words the reward: the singular noun (e.g. "Legacy") for plain counts, the
## result-screen heading, and whether amounts are formatted as dollars instead of a count.
var _reward_noun: String = "Legacy"
var _result_heading: String = "THE INHERITANCE"
## Result-screen row labels so the outcome reads as a context-specific STATEMENT (Tim, 2026-07-10):
## `_base_label` names the pre-minigame amount ("Earned while away"), `_total_label` names the final
## banked amount ("Total banked"). Set per site from the reward context; both amount-scaling sites
## and First Contact use them.
var _base_label: String = "Base"
var _total_label: String = "Total"
var _format_as_money: bool = false
## Upside-only mode (First Contact, GDD §5.5 site 2): the floor is the base — a weak run or a Skip
## costs nothing, and a good run adds a BUCKETED bonus (low/med/high) rather than a continuous
## multiplier. Changes the SKIP label, the stakes blurb, and the result screen to match.
var _upside_only: bool = false
var _bonus_max: float = 0.25
## The dynasty's lifetime-earned Legacy, set by Main before a real round so the host can size the
## Legacy-gem bonus (0.1% of this per gem). Stays 0 in review/Challenge → no bonus is ever granted.
var _legacy_lifetime: int = 0
## Site-specific multiplier on the Legacy-gem grant (1.0 by default; First Contact sets it higher so
## the epoch-transition gem is a bigger windfall). Reset to 1.0 by set_legacy_lifetime so it can
## never leak from one site's minigame to the next.
var _legacy_bonus_multiplier: float = 1.0
var _seconds_left: float = 0.0
var _playing: bool = false
var _opt_out: bool = false
var _active_minigame: Minigame
var _purpose: String = DEFAULT_PURPOSE

## Review mode (Settings → Minigame Tuning): a Back button is shown so a tester can bail
## out at any time. False for the real prestige round, where there is no Back.
var _review_mode: bool = false
## The Back buttons (one per view), shown only in review mode. Tracked so start_game can
## flip their visibility for the chosen mode.
var _back_buttons: Array = []
## The play view's centered "purpose" blurb (e.g. "Grow the inheritance"), shown ONLY outside
## review mode — in the tuner the top section is just the Back button instead.
var _purpose_label: Label

var _play_view: Control
var _result_view: Control
var _timer_label: Label
## The spectrum bar communicates by fill + color ONLY — no numeric "kept" readout (plan §1,
## decision 2026-06-29). What you'd keep on a skip is made legible on the SKIP button instead.
var _keep_bar: Control
## The skip control, kept as a field so start_game can label it with the concrete reward a skip
## banks (the keep floor), now that the spectrum bar shows no numbers.
var _skip_button: Button
## The smoothed multiplier the spectrum bar actually draws — lerped toward the live multiplier
## each frame so the fill glides (see KEEP_BAR_LERP_SPEED).
var _display_mult: float = 0.5
## Each segment fires a brief flash the moment it FIRST fills completely (Tim, 2026-07-09). We track
## whether each is currently full (to fire once per crossing) and a decaying [0,1] flash intensity.
var _left_seg_full: bool = false
var _right_seg_full: bool = false
var _left_seg_flash: float = 0.0
var _right_seg_flash: float = 0.0
## The two-segment bar's styleboxes, built once and reused so no StyleBoxFlat is allocated per frame
## (minigame-lag rule). Dark "track" + bright "fill" per segment, plus a shared white flash box.
var _seg_track_left: StyleBoxFlat
var _seg_track_right: StyleBoxFlat
var _seg_fill_left: StyleBoxFlat
var _seg_fill_right: StyleBoxFlat
var _seg_flash_box: StyleBoxFlat
var _play_area: Control
## The shared "Legacy gem earned!" badge: floats at the top of the play area and appears on EVERY
## game the moment a Legacy gem is collected this round (polled in _process). Hidden until then.
var _gem_badge: Control
var _result_heading_label: Label
## The one-word verdict of how the round went ("GREAT ROUND" / "FULL" / "WEAK ROUND" / a First
## Contact bucket), colored by tier — the headline of the result statement.
var _result_verdict_label: Label
## The result STATEMENT: labelled key/value rows so the outcome reads as a clear, context-specific
## ledger (Tim, 2026-07-10) — base amount, the minigame's impact, then the final total. Each row is a
## left-aligned key + a right-aligned value; the total row is larger and bold. Populated per site.
var _stat_base_key: Label
var _stat_base_val: Label
var _stat_impact_key: Label
var _stat_impact_val: Label
## A second impact row, used only where a site has two effects to show (First Contact: income boost
## AND cycle speed). Hidden for the amount-scaling sites, which have a single impact.
var _stat_impact2_key: Label
var _stat_impact2_val: Label
var _stat_impact2_row: Control
var _stat_divider: Control
var _stat_total_key: Label
var _stat_total_val: Label
## A type-specific line on the result screen ("Scored 1,240 points", "Caught 14 of 18"), so the
## paused result clearly reflects the game just played. Hidden when the type provides none.
var _result_summary_label: Label
## The Legacy-gem bonus line ("LEGACY BONUS +N gems" / "gems lost"), shown only when the player
## collected a gem this round. See _show_result / _legacy_bonus_amount.
var _result_legacy_label: Label

## The "Get Ready / BEGIN" gate shown over the card at the start of every round. The clock and the
## chosen type both stay frozen until the player presses Begin, so no round ever starts the instant
## the screen appears (Tim, 2026-06-26). `_begin_title` names the drawn type on that gate.
var _begin_overlay: Control
var _begin_title: Label
## The "how to play" goal line on the Get Ready gate — the active type's own one-liner (set per
## round in start_game), so the player learns the goal BEFORE the clock starts (Tim, 2026-06-29).
var _begin_howto: Label

## The full-bleed themed backdrop. Its rounded corners are CPU-BAKED at the displayed size (see
## _rebake_backdrop) so the bright bottom-corner art doesn't poke past the screen's rounded frame —
## clip_children can't do it here (the project supports only one clip stencil, and Main owns it).
var _backdrop: TextureRect
## The WHOLE-PIXEL size the backdrop was last baked for, so we only re-bake when it
## actually changes. Integer pixels, not the float size (Tim, 2026-07-07): sub-pixel
## layout jitter defeated an exact float compare and could re-run the expensive bake
## every frame — the same trap that lagged the basketball board (see BasketballMinigame).
var _baked_backdrop_px: Vector2i = Vector2i.ZERO

## Challenge Mode (Tim, 2026-06-30): a free-play arcade mode launched from the Minigame Tuning
## screen. No time limit, no win/loss reward — the chosen type runs endlessly and we track the raw
## score, saving a per-type high score. When true the host hides the timer/spectrum/skip reward
## chrome and shows a live score + best readout, and DONE ends the run (saving the high score).
var _challenge_mode: bool = false
var _score_label: Label
var _highscore_label: Label
## The two-corner Challenge Mode header (Tim, 2026-07-22): a MarginContainer holding two equal-width
## columns — Score over Best score (top-left, black) and current Tier over Best tier (top-right, dark
## gray). REPLACES the earlier centered "Score  Best" row and the centered "TIER x / y" line. Kept as a
## field so _set_challenge_chrome can show/hide the whole header as one unit.
var _challenge_header: Control
## The CHALLENGE end view — shown when a run ends (DONE/Back) INSTEAD of closing straight away, so the
## tier-credit feedback has somewhere to land (Challenge Mode Phase 2). A dedicated view, deliberately
## separate from the reward `_result_view` (the reward statement must not carry challenge feedback).
## `_challenge_score_label` shows the final score; `_challenge_credit_label` is filled by
## show_challenge_credit with the "NEW TIER" line once Main reports the credit back.
var _challenge_end_view: Control
var _challenge_score_label: Label
var _challenge_credit_label: Label
## The best score to beat this run — starts at the saved high score and rises live as the player
## passes it, so the "Best" readout ticks up in real time.
var _challenge_high: int = 0
## The active type's display name — the key under which its Challenge high score is saved.
var _active_type_key: String = ""

## The keep-alive run timer (Wave 2, Plans/Challenge_Mode.md §1). A challenge run is NOT endless: the
## clock starts low, drains in real time, and is topped up by every point scored. When it hits 0 the
## run ends and the best tier is banked. These fields are CHALLENGE-ONLY — a reward round (start_game)
## never touches them, so the keep-alive tension never leaks into a prestige/welcome-back round.
##   `_challenge_time_left`  — seconds remaining on the clock right now.
##   `_challenge_last_score` — the run's get_score() at the last top-up, so a frame's gain is the
##                             difference (each gained point buys seconds_per_point seconds).
##   `_challenge_ended`      — fire-once guard so the timer-death end path runs exactly once and never
##                             re-triggers while the end view is up.
##   `_challenge_low_pulse`  — a phase accumulator driving the low-time (<2s) warning pulse.
var _challenge_time_left: float = 0.0
var _challenge_last_score: int = 0
var _challenge_ended: bool = false
var _challenge_low_pulse: float = 0.0

## The keep-alive timer's prominent readout: a horizontal bar that empties as the clock runs down,
## with the seconds remaining printed over it. Shown only in challenge mode (in place of the reward
## timer + spectrum bar). Turns red and pulses under CHALLENGE_TIMER_LOW_SECONDS — it is the core
## tension of a run, so it is large and unmissable (low-vision rule).
var _challenge_timer_margin: MarginContainer
var _challenge_timer_bar: Control
var _challenge_timer_seconds_label: Label
## The timer bar's styleboxes, built once and reused so no StyleBoxFlat is allocated per frame
## (minigame-lag rule): a dark track, the normal fill, and the low-time red fill.
var _challenge_timer_track: StyleBoxFlat
var _challenge_timer_fill: StyleBoxFlat
var _challenge_timer_low: StyleBoxFlat

## Below this many seconds left the keep-alive bar turns red and pulses — the "you're about to die"
## warning (Plans/Challenge_Mode.md §1).
const CHALLENGE_TIMER_LOW_SECONDS := 2.0

## The current-TIER display (Challenge Mode, ALL games — Tim, 2026-07-22): the primary value in the
## header's top-right corner ("TIER 3"), dark gray, with `_best_tier_label` nestled underneath it. It
## PULSES with a brief scale-up + brighten every time the CURRENT tier climbs a rung. Shown for every
## challenge game (self-ending ones included, unlike the keep-alive timer bar).
##   `_challenge_tier_pulse` — decaying [0,1] pop, set to 1 when the current tier rises, eased to 0 in ~0.4s.
##   `_challenge_shown_tier` — the current tier last shown, so the pop fires once per crossing.
var _challenge_tier_label: Label
## The best tier reached, nestled under the current-tier primary ("Best: 7"), dark gray a size down.
var _best_tier_label: Label
## Whether this run has already passed the stored high score, so the beat fires once rather than on
## every frame after the crossing.
var _beaten_high_score := false
## The last whole second the countdown displayed, so its cue fires once per tick rather than per frame.
var _last_ticked_second := -1
var _challenge_tier_pulse: float = 0.0
var _challenge_shown_tier: int = 0

## The Get Ready gate's stakes and hint lines, kept as fields so start_game / start_challenge can
## set the wording per mode (reward stakes vs. "play as long as you like").
var _begin_stakes: Label
var _begin_hint: Label
## The WHY line under GET READY — the round's fiction (from the reward's `framing`), so
## the player knows what this game IS in the story before the mechanics (work item 3).
## Hidden in Challenge Mode and the review tuner, which need no fiction.
var _begin_framing: Label


func setup(tuning: TuningConfig) -> void:
	_tuning = tuning


## Main calls this before a REAL round with the dynasty's lifetime-earned Legacy, so the host can
## size any Legacy-gem bonus. Left at 0 for review/Challenge rounds, which never grant a bonus.
func set_legacy_lifetime(lifetime: int) -> void:
	_legacy_lifetime = maxi(0, lifetime)
	_legacy_bonus_multiplier = 1.0  # default; a caller (First Contact) may raise it right after


## Scale this round's Legacy-gem grant (First Contact sets it > 1 so an epoch-transition gem pays
## more). Call AFTER set_legacy_lifetime, which resets it to 1.0.
func set_legacy_bonus_multiplier(multiplier: float) -> void:
	_legacy_bonus_multiplier = maxf(0.0, multiplier)


func _ready() -> void:
	# A black field hugs the screen edge and frames the viewing area — the same bezel every other
	# full-screen screen uses. Behind the card now sits a full-bleed themed backdrop (Tim,
	# 2026-06-29); the card itself is semi-transparent so the backdrop reads through it.
	color = Color.BLACK
	visible = false

	# The full-bleed backdrop image, inset inside the black bezel like every other screen's
	# background. Its texture is CPU-baked (see _rebake_backdrop): the source image is scaled to
	# cover this rect and its four corners are rounded to match the screen frame, so the bright
	# bottom-corner art (chips/gold) doesn't poke past the rounded border. We bake instead of using
	# clip_children because the project supports only one clip stencil and Main already owns one — a
	# second would render empty (the documented 2026-06-26 render bug). STRETCH_SCALE because the
	# baked image is already sized to this rect.
	_backdrop = TextureRect.new()
	UiPalette.apply_screen_bezel(_backdrop)
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	# Bake once the backdrop has been laid out (its size is known), and again if that size changes.
	_backdrop.resized.connect(_rebake_backdrop)
	_rebake_backdrop.call_deferred()

	# The shared rounded screen frame over the backdrop edges: transparent fill (so the image
	# shows through), thin black rounded border, universal inner margin — the same frame every
	# screen uses, kept for visual consistency with the rest of the game.
	var frame := PanelContainer.new()
	UiPalette.apply_screen_bezel(frame)
	frame.add_theme_stylebox_override("panel", UiPalette.make_screen_frame_style())
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	# The game card itself, centered on top of that background with its own thick outline.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", make_card_style())
	# Center the panel by anchor fractions so it scales with the screen and stays centered.
	var half_w := PANEL_WIDTH_FRACTION / 2.0
	var half_h := PANEL_HEIGHT_FRACTION / 2.0
	panel.anchor_left = 0.5 - half_w
	panel.anchor_right = 0.5 + half_w
	panel.anchor_top = 0.5 - half_h
	panel.anchor_bottom = 0.5 + half_h
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	add_child(panel)

	# The two views (play / result) share one slot that fills the panel, so the play area
	# stretches to fill the card.
	var slot := MarginContainer.new()
	panel.add_child(slot)
	_play_view = _build_play_view()
	slot.add_child(_play_view)
	_result_view = _build_result_view()
	slot.add_child(_result_view)
	# The Challenge end view shares the same slot (only one view is ever visible at a time), so the
	# tier-credit feedback shows on the same card the run played on.
	_challenge_end_view = _build_challenge_end_view()
	slot.add_child(_challenge_end_view)

	# The Begin gate floats on top of the card, covering the play/result views until the player
	# presses Begin. Added to the panel after the slot so it draws over everything inside the card.
	_begin_overlay = _build_begin_overlay()
	panel.add_child(_begin_overlay)

	# The SKIP / DONE control sits BELOW the card, in the scrim (Tim, 2026-07-02): 40% taller and 20%
	# narrower than its old in-card form, anchored just under the panel's bottom edge and centered. It
	# is a SIBLING of the card (added to the screen, not the card's column), so it floats beneath the
	# frame; its visibility is toggled alongside the play view — shown only while a round is live, so
	# it never appears during the Get Ready gate or the result screen.
	_skip_button = Button.new()
	UiPalette.style_button(_skip_button, false)
	_skip_button.text = "SKIP"
	_skip_button.pressed.connect(_on_skip_pressed)
	# Its left/right anchors track the card's edges; the offsets inset it by the SAME margin the
	# spectrum bar and top row use (card content margin + CHROME_MARGIN), so all three line up. A
	# matching CHROME_MARGIN gap sits below it before the screen frame (Tim, 2026-07-09).
	var side_inset := float(UiPalette.UNIVERSAL_CONTENT_MARGIN + CHROME_MARGIN)
	_skip_button.anchor_left = 0.5 - half_w
	_skip_button.anchor_right = 0.5 + half_w
	_skip_button.anchor_top = 0.5 + half_h
	_skip_button.anchor_bottom = 0.5 + half_h
	_skip_button.offset_left = side_inset
	_skip_button.offset_right = -side_inset
	_skip_button.offset_top = CHROME_MARGIN
	_skip_button.offset_bottom = CHROME_MARGIN + SKIP_BUTTON_HEIGHT
	_skip_button.visible = false  # revealed on Begin (see _start_active_round)
	add_child(_skip_button)


## The cream card that frames every minigame — and, shared, the Minigame Tuning list, so the two
## match exactly: cream fill at 70% alpha (so the themed backdrop reads through), a moderately thick
## black outline, and the universal inner content margin. Static so the review screen builds the
## identical card via this + PANEL_WIDTH_FRACTION / PANEL_HEIGHT_FRACTION.
static func make_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# 70% alpha (Tim, 2026-06-30) so the themed backdrop reads through the card.
	style.bg_color = Color(UiPalette.CREAM, 0.7)
	style.set_corner_radius_all(24)
	style.border_color = Color.BLACK
	style.set_border_width_all(PANEL_BORDER_WIDTH)
	style.set_content_margin_all(UiPalette.UNIVERSAL_CONTENT_MARGIN)
	return style


## Bake this screen's backdrop to fit its current on-screen size with ROUNDED corners, so the
## bright bottom-corner art doesn't square off past the screen's rounded frame. Re-runs only when
## the size actually changes. The Minigame Tuning screen shares the baking via the static helper.
func _rebake_backdrop() -> void:
	if _backdrop == null:
		return
	var target := Vector2i(roundi(_backdrop.size.x), roundi(_backdrop.size.y))
	if target.x < 1 or target.y < 1:
		return
	# TOLERANCE, not equality: float layout jitter can wobble the size across an integer
	# boundary, alternating the rounded key every frame — which re-ran the bake every
	# frame (the basketball lag trap, Tim 2026-07-08). A ≤1px mismatch is invisible.
	if absi(target.x - _baked_backdrop_px.x) <= 1 and absi(target.y - _baked_backdrop_px.y) <= 1:
		return
	_baked_backdrop_px = target
	var texture := bake_rounded_backdrop(target, UiPalette.SCREEN_CORNER_RADIUS)
	if texture != null:
		_backdrop.texture = texture


## Load the shared backdrop image, scale it to COVER `size` (cropping the overflow, like
## STRETCH_KEEP_ASPECT_COVERED), and round its four corners to `radius`. Returns a ready-to-assign
## texture, or null if the image can't be loaded. Static + shared so the minigame screen and the
## Minigame Tuning screen produce the identical rounded backdrop from one place.
## The decompressed source image, cached after the first bake: load + decompress +
## convert is the expensive front half of a bake, and it never changes between bakes.
static var _backdrop_source: Image = null


static func bake_rounded_backdrop(size: Vector2i, radius: int) -> ImageTexture:
	if size.x < 1 or size.y < 1:
		return null
	if _backdrop_source == null:
		var source: Texture2D = load(BACKGROUND_IMAGE)
		if source == null:
			return null
		# Editing pixels needs an uncompressed RGBA image (the source PNG imports as RGB /
		# possibly VRAM compressed); convert so we can crop, resize, and write corners.
		_backdrop_source = source.get_image()
		if _backdrop_source.is_compressed():
			_backdrop_source.decompress()
		_backdrop_source.convert(Image.FORMAT_RGBA8)
	# Work on a copy — resize/crop mutate, and the pristine source is the cache.
	var image := _backdrop_source.duplicate() as Image

	# Scale to COVER the target rect (fill fully, crop the overflow), then center-crop to size.
	var cover := maxf(float(size.x) / image.get_width(), float(size.y) / image.get_height())
	image.resize(
		int(ceil(image.get_width() * cover)), int(ceil(image.get_height() * cover)),
		Image.INTERPOLATE_BILINEAR
	)
	var crop_offset := Vector2i((image.get_width() - size.x) / 2, (image.get_height() - size.y) / 2)
	var fitted := image.get_region(Rect2i(crop_offset, size))

	_clear_image_corners(fitted, radius)
	return ImageTexture.create_from_image(fitted)


## Make the four corners of `image` transparent to a quarter-circle of the given radius, so the
## image reads with rounded corners (same technique HeroStat uses for its globe watermark).
static func _clear_image_corners(image: Image, radius: int) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var corners := [
		{"center": Vector2i(radius, radius), "dir": Vector2i(-1, -1)},           # top-left
		{"center": Vector2i(w - radius, radius), "dir": Vector2i(1, -1)},        # top-right
		{"center": Vector2i(radius, h - radius), "dir": Vector2i(-1, 1)},        # bottom-left
		{"center": Vector2i(w - radius, h - radius), "dir": Vector2i(1, 1)},     # bottom-right
	]
	for corner in corners:
		var center: Vector2i = corner["center"]
		var dir: Vector2i = corner["dir"]
		for offset_y in range(radius):
			for offset_x in range(radius):
				# A pixel in the outward corner quadrant, beyond the radius from the arc centre, is
				# outside the rounded edge — clear it.
				if Vector2(offset_x, offset_y).length() <= radius:
					continue
				var pixel := center + Vector2i(dir.x * offset_x, dir.y * offset_y)
				if pixel.x < 0 or pixel.y < 0 or pixel.x >= w or pixel.y >= h:
					continue
				var color := image.get_pixel(pixel.x, pixel.y)
				color.a = 0.0
				image.set_pixel(pixel.x, pixel.y, color)


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_play_view() -> Control:
	var column := VBoxContainer.new()
	# Tightened 12 -> 10 (Tim, 2026-07-21) as part of reclaiming challenge-chrome height for the board;
	# still a clear gap between the stacked rows.
	column.add_theme_constant_override("separation", 10)

	# The first row carries two things side by side: the Back button (review mode only) on the left,
	# and the round timer right-aligned. It sits inside a MarginContainer so the Back button and timer
	# keep a generous margin from the card's top and side edges (Tim, 2026-07-09).
	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", CHROME_MARGIN)
	top_margin.add_theme_constant_override("margin_left", CHROME_MARGIN)
	top_margin.add_theme_constant_override("margin_right", CHROME_MARGIN)
	column.add_child(top_margin)
	var top_row := _add_back_button(top_margin)

	# The timer stays the round's focal point (plan §1): big and faux-bold, escalating in color/scale
	# as time runs low (see _refresh_timer). It lives at the top-right of the first row (the spacer
	# inside top_row pushes it right), 50% larger than the shared display size (Tim, 2026-07-09).
	_timer_label = _make_label("0:30", int(UiPalette.FONT_DISPLAY * 1.5), UiPalette.KETCHUP_RED)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_label.add_theme_font_override("font", UiPalette.make_bold_font())
	top_row.add_child(_timer_label)

	_purpose_label = _make_label(_purpose, UiPalette.FONT_HEADLINE, UiPalette.NAVY)
	_purpose_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_purpose_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_purpose_label)

	# Challenge Mode header (hidden in normal reward rounds): a two-corner readout (Tim, 2026-07-22) that
	# REPLACES the earlier centered "Score  Best" row and the centered "TIER x / y" line. Top-LEFT is the
	# live Score (primary) with the Best score nestled directly underneath it, both black. Top-RIGHT is the
	# current Tier (primary) with the Best tier underneath, both dark gray. Two equal-width columns hug the
	# card's left and right edges (CHROME_MARGIN inset, matching the timer bar below). start_challenge
	# fills the four labels; _set_challenge_chrome shows/hides the whole header as one unit.
	var challenge_header_margin := MarginContainer.new()
	challenge_header_margin.add_theme_constant_override("margin_left", CHROME_MARGIN)
	challenge_header_margin.add_theme_constant_override("margin_right", CHROME_MARGIN)
	challenge_header_margin.visible = false
	column.add_child(challenge_header_margin)
	_challenge_header = challenge_header_margin

	var challenge_header_row := HBoxContainer.new()
	challenge_header_row.add_theme_constant_override("separation", 20)
	challenge_header_margin.add_child(challenge_header_row)

	# LEFT column: Score (primary, big display font — it replaces the timer as the focal point) over the
	# Best score, both black, hugging the left edge. A tight 2px separation keeps Best "nestled" under it.
	var score_column := VBoxContainer.new()
	score_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_column.add_theme_constant_override("separation", 2)
	challenge_header_row.add_child(score_column)

	_score_label = _make_label("", UiPalette.FONT_DISPLAY, Color.BLACK)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_score_label.add_theme_font_override("font", UiPalette.make_bold_font())
	score_column.add_child(_score_label)

	_highscore_label = _make_label("", UiPalette.FONT_SUBHEAD, CHALLENGE_BEST_GRAY)
	_highscore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	score_column.add_child(_highscore_label)

	# RIGHT column: current Tier (primary) over Best tier, both dark gray, hugging the right edge. The tier
	# primary keeps its tier-up PULSE (see _update_challenge_tier); SHRINK_END sizes it to its own text so
	# the pulse still scales from the text's true center and the right edge stays pinned as the text width
	# changes ("TIER 3" -> "TIER MAX").
	# The tier text is short ("TIER 3" .. "TIER MAX"), so this column takes only the width it needs and
	# pins right, leaving the whole rest of the row to the score so a long score number has room.
	var tier_column := VBoxContainer.new()
	tier_column.size_flags_horizontal = Control.SIZE_SHRINK_END
	tier_column.add_theme_constant_override("separation", 2)
	challenge_header_row.add_child(tier_column)

	_challenge_tier_label = _make_label("", UiPalette.FONT_DISPLAY, Color.BLACK)
	_challenge_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_challenge_tier_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_challenge_tier_label.add_theme_font_override("font", UiPalette.make_bold_font())
	tier_column.add_child(_challenge_tier_label)

	_best_tier_label = _make_label("", UiPalette.FONT_SUBHEAD, CHALLENGE_BEST_GRAY)
	_best_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_best_tier_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	tier_column.add_child(_best_tier_label)

	# The keep-alive TIMER bar (Challenge Mode only): a horizontal bar that empties as the clock runs
	# down, the seconds remaining printed over it. It replaces the reward timer + spectrum bar in
	# challenge play. Inside a MarginContainer so its sides line up with the rest of the chrome. Hidden
	# until start_challenge shows it via _set_challenge_chrome.
	var challenge_timer_margin := MarginContainer.new()
	challenge_timer_margin.add_theme_constant_override("margin_left", CHROME_MARGIN)
	challenge_timer_margin.add_theme_constant_override("margin_right", CHROME_MARGIN)
	challenge_timer_margin.add_theme_constant_override("margin_top", 8)  # trimmed 14 -> 8 to reclaim board height
	challenge_timer_margin.visible = false
	column.add_child(challenge_timer_margin)
	_challenge_timer_margin = challenge_timer_margin

	_challenge_timer_bar = Control.new()
	# 68 -> 62: modestly shorter to reclaim board height; still large and unmissable (low-vision rule) —
	# it stays the tallest chrome bar because the keep-alive clock is the core tension of a run.
	_challenge_timer_bar.custom_minimum_size = Vector2(0, 62)
	_challenge_timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_challenge_timer_bar.draw.connect(_draw_challenge_timer_bar)
	challenge_timer_margin.add_child(_challenge_timer_bar)
	_build_challenge_timer_styleboxes()

	# The seconds-remaining readout, centered OVER the bar (full-rect child), cream with an ink
	# outline so it stays legible over both the dark track and the fill.
	_challenge_timer_seconds_label = _make_label("", UiPalette.FONT_SUBHEAD, UiPalette.CREAM)
	_challenge_timer_seconds_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_challenge_timer_seconds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_challenge_timer_seconds_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_challenge_timer_seconds_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_challenge_timer_seconds_label.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
	_challenge_timer_seconds_label.add_theme_constant_override("outline_size", 5)
	_challenge_timer_seconds_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_challenge_timer_bar.add_child(_challenge_timer_seconds_label)

	# The universal outcome bar — identical for every minigame type; it reads the active type's live
	# performance. Two rounded SEGMENTS side by side (Tim, 2026-07-09): a green LEFT segment that fills
	# as you climb to the "full" line, and a blue RIGHT segment that then fills as you climb to the max
	# bonus. Each starts dark and fills left→right and briefly flashes when it completes. Inside a
	# MarginContainer so its sides line up with the Back/timer margin above and it sits a little lower.
	var bar_margin := MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_left", CHROME_MARGIN)
	bar_margin.add_theme_constant_override("margin_right", CHROME_MARGIN)
	bar_margin.add_theme_constant_override("margin_top", 22)  # nudge the bar down a little (Tim)
	column.add_child(bar_margin)
	_keep_bar = Control.new()
	_keep_bar.custom_minimum_size = Vector2(0, 60)  # 40 * 1.5 — 50% taller (Tim, 2026-07-09)
	_keep_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keep_bar.draw.connect(_draw_keep_bar)
	bar_margin.add_child(_keep_bar)
	_build_segment_styleboxes()

	# The chosen minigame TYPE fills this area each round. A modest minimum keeps it from
	# collapsing; the expand flags make it take all the room left inside the centered panel
	# after the top section, timer, spectrum bar, and skip controls.
	_play_area = Control.new()
	_play_area.custom_minimum_size = Vector2(0, 400)
	_play_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_play_area)

	# The shared "gem earned" badge floats at the TOP of the play area (full-width row, centered), over
	# whatever game is running (z above it, mouse-ignored), so showing it never reflows the game. It's
	# revealed in _process the instant a Legacy gem is collected, uniformly across every game type.
	var badge_row := HBoxContainer.new()
	badge_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.add_theme_constant_override("separation", 12)
	badge_row.z_index = 5
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_row.visible = false
	var gem_icon := TextureRect.new()
	gem_icon.texture = LEGACY_GEM_TEXTURE
	gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	gem_icon.custom_minimum_size = Vector2(56, 56)
	badge_row.add_child(gem_icon)
	var gem_word := _make_label("LEGACY GEM!", UiPalette.FONT_SUBHEAD, UiPalette.MUSTARD_GOLD.darkened(0.35))
	gem_word.add_theme_font_override("font", UiPalette.make_bold_font())
	gem_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_row.add_child(gem_word)
	_play_area.add_child(badge_row)
	_gem_badge = badge_row

	# The SKIP / DONE control is NOT in this column — it floats BELOW the card in the scrim, built in
	# _ready (Tim, 2026-07-02). The in-round "Skip minigames from now on" checkbox was removed (Tim,
	# 2026-07-09); the "play transition minigames" preference lives in Settings.
	return column


func _build_result_view() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.visible = false

	# The Back button gets the SAME size and edge margin as the play screen's (Tim, 2026-07-09): same
	# _add_back_button, wrapped in a MarginContainer with CHROME_MARGIN like the play view's top row.
	var back_margin := MarginContainer.new()
	back_margin.add_theme_constant_override("margin_top", CHROME_MARGIN)
	back_margin.add_theme_constant_override("margin_left", CHROME_MARGIN)
	back_margin.add_theme_constant_override("margin_right", CHROME_MARGIN)
	column.add_child(back_margin)
	_add_back_button(back_margin)

	# An expanding spacer above the text block (mirrored by the one below CONTINUE) centers the result
	# text vertically in the middle of the card (Tim, 2026-07-09).
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(top_spacer)

	# The heading names what was won ("THE INHERITANCE" / "THE OVERNIGHT HAUL"); start_game
	# sets it per site from the reward context.
	_result_heading_label = _make_label("THE INHERITANCE", UiPalette.FONT_HEADLINE, UiPalette.NAVY)
	_result_heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_heading_label)

	# The verdict headline — how the round went, colored by tier.
	_result_verdict_label = _make_label("", UiPalette.FONT_DISPLAY, UiPalette.DARK_GOLD)
	_result_verdict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_verdict_label)

	# The statement — base → impact → total — as key/value rows in a constrained, centered column so
	# it reads as a clean ledger rather than running the full card width (Tim, 2026-07-10).
	var statement := VBoxContainer.new()
	statement.add_theme_constant_override("separation", 12)
	statement.custom_minimum_size = Vector2(680, 0)
	statement.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(statement)

	var base_row := _make_stat_row(false)
	_stat_base_key = base_row["key"]
	_stat_base_val = base_row["val"]
	statement.add_child(base_row["row"])

	var impact_row := _make_stat_row(false)
	_stat_impact_key = impact_row["key"]
	_stat_impact_val = impact_row["val"]
	statement.add_child(impact_row["row"])

	var impact2_row := _make_stat_row(false)
	_stat_impact2_key = impact2_row["key"]
	_stat_impact2_val = impact2_row["val"]
	_stat_impact2_row = impact2_row["row"]
	statement.add_child(impact2_row["row"])

	# A thin rule between the impact and the final total, like the line above a receipt total.
	_stat_divider = ColorRect.new()
	_stat_divider.color = Color(UiPalette.NAVY, 0.35)
	_stat_divider.custom_minimum_size = Vector2(0, 3)
	statement.add_child(_stat_divider)

	var total_row := _make_stat_row(true)
	_stat_total_key = total_row["key"]
	_stat_total_val = total_row["val"]
	statement.add_child(total_row["row"])

	# How the player did at the game itself (set per round from the type's result_summary).
	_result_summary_label = _make_label("", UiPalette.FONT_LABEL, UiPalette.NAVY)
	_result_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_result_summary_label)

	# The Legacy-gem bonus line — shown only when the player collected a gem this round. Dark gold
	# with a navy outline so the windfall reads as special AND stays legible over the translucent
	# result card + themed backdrop (Tim, 2026-07-20 contrast pass).
	_result_legacy_label = _make_label("", UiPalette.FONT_SUBHEAD, UiPalette.DARK_GOLD)
	_result_legacy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_legacy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_legacy_label.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
	_result_legacy_label.add_theme_constant_override("outline_size", 4)
	_result_legacy_label.visible = false
	column.add_child(_result_legacy_label)

	# Push CONTINUE to the BOTTOM of the card: an expanding spacer eats the slack above it so the
	# button sits at the panel's bottom edge instead of floating up under the summary text (Tim,
	# 2026-07-02).
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(bottom_spacer)

	# CONTINUE: 40% taller than the old 80px and 20% narrower than the card, centered. A 10 / 80 / 10
	# HBox (equal expanding pads either side of an 8×-ratio button) gives it exactly 80% width with
	# even margins (Tim, 2026-07-02) — mirroring the resized SKIP control on the play screen.
	var continue_row := HBoxContainer.new()
	var left_pad := Control.new()
	left_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_pad.size_flags_stretch_ratio = 1.0
	continue_row.add_child(left_pad)

	var continue_button := Button.new()
	continue_button.custom_minimum_size = Vector2(0, 112)  # 80 * 1.4 — 40% taller
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_button.size_flags_stretch_ratio = 8.0  # 80% of the row (10 / 80 / 10 with the pads)
	UiPalette.style_button(continue_button, true)
	continue_button.text = "CONTINUE"
	continue_button.pressed.connect(_on_continue_pressed)
	continue_row.add_child(continue_button)

	var right_pad := Control.new()
	right_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_pad.size_flags_stretch_ratio = 1.0
	continue_row.add_child(right_pad)

	column.add_child(continue_row)

	# A CHROME_MARGIN gap below CONTINUE so it isn't jammed against the card's bottom edge (Tim,
	# 2026-07-09) — matching the breathing room the SKIP button has on the play screen.
	var continue_bottom := Control.new()
	continue_bottom.custom_minimum_size = Vector2(0, CHROME_MARGIN)
	column.add_child(continue_bottom)

	return column


## The CHALLENGE end view (Challenge Mode Phase 2): shown when a run ends (DONE/Back) instead of
## closing straight away, so the tier-credit "NEW TIER" feedback has somewhere to land. Deliberately
## separate from the reward `_result_view` — a challenge run banks no Legacy, so it shows the final
## score and the credit line only, then a BACK TO LIST button that actually leaves.
func _build_challenge_end_view() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	column.visible = false

	# An expanding spacer above the text block (mirrored below the button) centers the text vertically.
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(top_spacer)

	var heading := _make_label("CHALLENGE COMPLETE", UiPalette.FONT_HEADLINE, UiPalette.NAVY)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	# The final score (filled by _show_challenge_end from the run's get_score()).
	_challenge_score_label = _make_label("", UiPalette.FONT_SUBHEAD, UiPalette.NAVY)
	_challenge_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_challenge_score_label)

	# The tier-credit line, filled by show_challenge_credit once Main reports the credit back. DARK_GOLD
	# with a navy outline so the "NEW TIER" reward reads as a positive windfall AND stays legible over
	# the translucent cream card + themed backdrop (same treatment as the reward-screen Legacy line, so
	# it never washes out — a light color would). Large headline font for the low-vision rule.
	_challenge_credit_label = _make_label("", UiPalette.FONT_HEADLINE, UiPalette.DARK_GOLD)
	_challenge_credit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_challenge_credit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_challenge_credit_label.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
	_challenge_credit_label.add_theme_constant_override("outline_size", 4)
	_challenge_credit_label.visible = false
	column.add_child(_challenge_credit_label)

	# Push the exit button to the bottom of the card, mirroring the reward view's CONTINUE placement.
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(bottom_spacer)

	# BACK TO LIST: an 8×-ratio button centered at 80% width (10 / 80 / 10 pads), matching CONTINUE. It
	# is the ONLY control that actually leaves the run now — connected to _exit_challenge, NOT the play
	# view's Back (which re-enters _end_challenge), so pressing it can't loop back into the end view.
	var exit_row := HBoxContainer.new()
	var left_pad := Control.new()
	left_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_pad.size_flags_stretch_ratio = 1.0
	exit_row.add_child(left_pad)

	var exit_button := Button.new()
	exit_button.custom_minimum_size = Vector2(0, 112)  # matches CONTINUE (80 * 1.4)
	exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_button.size_flags_stretch_ratio = 8.0
	UiPalette.style_button(exit_button, true)
	exit_button.text = "BACK TO LIST"
	exit_button.pressed.connect(_exit_challenge)
	exit_row.add_child(exit_button)

	var right_pad := Control.new()
	right_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_pad.size_flags_stretch_ratio = 1.0
	exit_row.add_child(right_pad)

	column.add_child(exit_row)

	var exit_bottom := Control.new()
	exit_bottom.custom_minimum_size = Vector2(0, CHROME_MARGIN)
	column.add_child(exit_bottom)

	return column


## The "Get Ready" gate over the card: the drawn type's name, goal, stakes, and a big BEGIN button.
## No opaque scrim — the gate lets the 70%-translucent card (and the backdrop through it) show, so
## Get Ready reads at the same 70% as the rest of the panel (Tim, 2026-06-30). The not-yet-started
## game is hidden instead by keeping _play_view invisible until Begin (see start_game /
## _start_active_round). start_game shows the gate; _on_begin_pressed fades it and starts the round.
func _build_begin_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false

	# The gate text SCROLLS if it's tall, with BEGIN PINNED below, so a wordy game (match-3) can never
	# push BEGIN off the card (Tim, 2026-07-10). Short games still read as a CENTERED block: the scroll
	# stretches its content column to the viewport when it fits, and the column centers its lines; when
	# the text overflows, the column exceeds the viewport and the scroll takes over instead.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	overlay.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 16)
	margin.add_child(outer)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED  # wrap, never scroll sideways
	outer.add_child(scroll)

	# The text column. EXPAND_FILL both ways so the ScrollContainer stretches it to fill the viewport
	# when the text is SHORT, and ALIGNMENT_CENTER then centers the lines within it (the approved
	# centered look); when the text is TALL it exceeds the viewport and scrolling takes over.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(box)

	var ready := _make_label("GET READY", _scaled_ready_size(UiPalette.FONT_HEADLINE), UiPalette.NAVY)
	ready.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ready)

	# The WHY line — this round's place in the story, before any mechanics. Slightly
	# muted so it reads as narration above the gold game title.
	_begin_framing = _make_label("", _scaled_ready_size(UiPalette.FONT_CARD_BODY), Color(UiPalette.NAVY, 0.85))
	_begin_framing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_begin_framing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_begin_framing)

	# Names the randomly drawn type so the player knows what they're about to play.
	# DARK_GOLD (not the brighter MUSTARD_GOLD) so the game name reads clearly on the cream card
	# (Tim, 2026-07-09).
	_begin_title = _make_label("", _scaled_ready_size(UiPalette.FONT_DISPLAY), UiPalette.DARK_GOLD)
	_begin_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_begin_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_begin_title)

	# The goal of THIS game (set per round from the type's how_to_play), so the player knows the
	# objective before the clock starts rather than only once play begins (Tim, 2026-06-29).
	_begin_howto = _make_label("", _scaled_ready_size(UiPalette.FONT_CARD_BODY), UiPalette.NAVY)
	_begin_howto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_begin_howto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_begin_howto)

	# The stakes line — reward win/lose in a normal round, "play as long as you like" in Challenge
	# Mode. Set per mode by start_game / start_challenge (kept as a field for that).
	_begin_stakes = _make_label("", _scaled_ready_size(UiPalette.FONT_LABEL), UiPalette.DARK_GOLD)
	_begin_stakes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_begin_stakes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_begin_stakes)

	# The closing hint ("The clock starts…" normally; hidden in Challenge Mode). Also a field.
	_begin_hint = _make_label("The clock starts when you press Begin.", _scaled_ready_size(UiPalette.FONT_LABEL), UiPalette.NAVY)
	_begin_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_begin_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_begin_hint)

	# BEGIN is PINNED below the scroll (in `outer`, NOT the scrolling column), so it stays on the card
	# no matter how tall the instructions are. SHRINK_CENTER keeps its fixed width, centered.
	var begin_button := Button.new()
	begin_button.custom_minimum_size = Vector2(360, 110)
	begin_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiPalette.style_button(begin_button, true)  # the action (red) button — this is the "go" control
	begin_button.add_theme_font_size_override("font_size", _scaled_ready_size(UiPalette.FONT_BUTTON))
	begin_button.text = "BEGIN"
	begin_button.pressed.connect(_on_begin_pressed)
	outer.add_child(begin_button)

	return overlay


## Add a left-aligned Back button to the top of a view's column. Hidden by default; only
## review mode (start_game's review_mode flag) makes it visible. A short HBox keeps it from
## stretching the full width — it sits in the top-left like a typical "back" affordance. Returns the
## row so a caller (the play view) can add the timer to it, right-aligned past the spacer.
func _add_back_button(parent: Container) -> HBoxContainer:
	var row := HBoxContainer.new()
	var back := Button.new()
	# A solid left-pointing triangle (◀) reads as a bigger, thicker back arrow than the thin "←" and,
	# unlike the heavy-arrow glyph, is present in the font (Tim, 2026-07-09). Bold thickens it further.
	back.text = "◀  BACK"
	back.custom_minimum_size = Vector2(340, 108)  # wider; 72 * 1.5 tall — 50% larger
	back.add_theme_font_size_override("font_size", int(UiPalette.FONT_BUTTON * 1.5))
	back.add_theme_font_override("font", UiPalette.make_bold_font())
	UiPalette.style_button(back, false)
	back.visible = false
	back.pressed.connect(_on_back_pressed)
	row.add_child(back)
	# A spacer eats the rest of the row so the button keeps its natural width on the left (and pushes
	# anything added after it — the play view's timer — to the right edge).
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_back_buttons.append(back)
	parent.add_child(row)
	return row


## A base font size scaled up for the "Get Ready" gate (GET_READY_TEXT_SCALE), rounded to a whole
## point size. Keeps every gate line proportionally bigger from one factor.
func _scaled_ready_size(base_size: int) -> int:
	return int(round(base_size * GET_READY_TEXT_SCALE))


## Build one statement row: a left-aligned KEY label that takes the slack, and a right-aligned VALUE
## label sized to its content at the far right — so the row reads as "Earned while away … $1.20M".
## `big` makes it the bold, larger total row. Returns the row and its two labels for the caller to fill.
func _make_stat_row(big: bool) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var key_size := int(UiPalette.FONT_SUBHEAD * (1.1 if big else 0.95))
	var val_size := int(UiPalette.FONT_SUBHEAD * (1.35 if big else 1.05))
	var key := _make_label("", key_size, UiPalette.NAVY)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := _make_label("", val_size, UiPalette.NAVY)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_horizontal = Control.SIZE_SHRINK_END
	if big:
		key.add_theme_font_override("font", UiPalette.make_bold_font())
		val.add_theme_font_override("font", UiPalette.make_bold_font())
	row.add_child(key)
	row.add_child(val)
	return {"row": row, "key": key, "val": val}


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# ---------------------------------------------------------------------------
# Round lifecycle
# ---------------------------------------------------------------------------

## Describe a round's reward for the host's DISPLAY only. The outcome math (the multiplier)
## is universal; these fields just control wording/formatting so the same minigames can scale
## Legacy at prestige and the cash pile at welcome-back. `base` is the pre-minigame amount,
## `noun` the singular reward word for plain counts ("Legacy"), `heading` the result-screen
## title, `purpose` the play-view blurb, and `format_as_money` formats amounts as dollars.
## `framing` is the WHY line on the Get Ready gate — one sentence of fiction explaining
## what this round is in the story (the heir proving themselves, risking the overnight
## pile, negotiating with aliens). Nothing in the game explained why a minigame was
## suddenly happening (Tim, 2026-07-07 debrief, work item 3).
## `base_label` / `total_label` name the two ends of the result STATEMENT for this site
## ("Earned while away" → "Total banked"), so the outcome reads with context (Tim, 2026-07-10).
static func make_reward(
		base: float, noun: String, heading: String, purpose: String, format_as_money: bool,
		upside_only: bool = false, framing: String = "", base_label: String = "Base",
		total_label: String = "Total"
) -> Dictionary:
	return {
		"base": base, "noun": noun, "heading": heading,
		"purpose": purpose, "as_money": format_as_money, "upside_only": upside_only,
		"framing": framing, "base_label": base_label, "total_label": total_label,
	}


## First Contact buckets its bonus (upside-only, GDD §5.5 site 2): a run at or below "full" earns
## nothing (index 0 = base, no penalty), and a run into the bonus band is sorted by how deep into it,
## as low / medium / high. Each bucket's permanent property bonus — income UP, cycle-time DOWN — and
## its result-screen label live here so Main (which applies it) and the result view (which announces
## it) read from ONE table and can never disagree about which bucket a run earned.
const FIRST_CONTACT_BUCKETS := [
	{"label": "NO BONUS", "income": 1.0, "cycle": 1.0},
	{"label": "LOW BONUS", "income": 1.15, "cycle": 0.95},
	{"label": "MEDIUM BONUS", "income": 1.40, "cycle": 0.88},
	{"label": "HIGH BONUS", "income": 1.80, "cycle": 0.80},
]


## Which FIRST_CONTACT_BUCKETS index a finished minigame multiplier earns, given the bonus cap:
## 0 at or below "full" (1.0), then low/medium/high by thirds of the bonus band above it.
static func first_contact_bucket(multiplier: float, bonus_max: float) -> int:
	var into_bonus := (multiplier - 1.0) / maxf(0.0001, bonus_max)
	if into_bonus <= 0.0:
		return 0
	elif into_bonus <= 1.0 / 3.0:
		return 1
	elif into_bonus <= 2.0 / 3.0:
		return 2
	return 3


## The prestige/succession round: scales the heir's Legacy (a plain count).
static func legacy_reward(base_legacy: int) -> Dictionary:
	return make_reward(
		float(base_legacy), "Legacy", "THE INHERITANCE", DEFAULT_PURPOSE, false, false,
		"The will is read. Before the fortune passes, the heir must show the estate "
		+ "what kind of tycoon they are.",
		"Inheritance at stake", "PASSED TO YOUR HEIR"
	)


## The welcome-back round (GDD §5.5 site 3): scales the overnight cash pile (money).
static func offline_pile_reward(pile: float) -> Dictionary:
	return make_reward(
		pile, "", "THE OVERNIGHT HAUL", "Make the most of your time away", true, false,
		"The empire earned this while you were away. One bold move before it banks.",
		"Earned while away", "TOTAL BANKED"
	)


## The First Contact round (GDD §5.5 site 2): the alien trade negotiation. It sets a permanent,
## upside-only bonus on the new alien property (income + cycle-time) — see Main._first_contact_bonus_for.
## `base_income` is that property's per-unit base income per cycle, framed as money so the result reads
## as the opening income you negotiated; `property_name` is the business being opened (result heading).
## `civilization` names who is across the table: the terms struck here apply to the
## epoch's WHOLE cohort (Phase 2), so the round is pitched at the civilization while
## the flagship's income stays the concrete number being negotiated.
static func first_contact_reward(
		base_income: float, property_name: String, civilization: String
) -> Dictionary:
	return make_reward(
		base_income, "", property_name.to_upper(),
		"Broker the %s trade terms" % civilization, true, true,  # as_money, upside_only
		("Across the table: a civilization that has never seen a human make a deal. "
		+ "The terms you strike cover every %s venture — open strong, and they favor "
		+ "you for good.") % civilization,
		"Base income", "Opening income"
	)


## Start a round. `reward` is a context from `make_reward` (or one of the named builders)
## describing what is being scaled and how to show it; `bonus_max` is the max extra-high
## bonus fraction (Family Reputation). Normally picks a random minigame type; the review
## screen passes a specific `forced_type` and sets `review_mode` so a Back button appears.
## Live play leaves both at their defaults (random type, no Back).
## The previously dealt type, read back from disk. Returns null when there is no file, the file
## is unreadable, or it names a type that no longer exists — in every one of those cases the
## caller simply deals from the full pool, which is the old behaviour.
static func _load_last_dealt() -> Script:
	if not FileAccess.file_exists(LAST_DEALT_PATH):
		return null
	var file := FileAccess.open(LAST_DEALT_PATH, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var path := String((parsed as Dictionary).get("last_dealt", ""))
	for type_variant in MINIGAME_TYPES:
		var type_script := type_variant as Script
		if type_script.resource_path == path:
			return type_script
	return null


## Remember this deal for the next launch. Stored by resource path so the file stays readable
## and a renamed or removed type degrades to "no exclusion" rather than to a wrong one.
static func _save_last_dealt(type_script: Script) -> void:
	var file := FileAccess.open(LAST_DEALT_PATH, FileAccess.WRITE)
	if file == null:
		return  # a write failure must never break the round that is about to start
	file.store_string(JSON.stringify({"last_dealt": type_script.resource_path}))
	file.close()


func start_game(
		reward: Dictionary, bonus_max: float, forced_type: Script = null, review_mode: bool = false
) -> void:
	# THE SOUNDTRACK STEPS OUT (Tim, 2026-08-09: "remove soundtrack entirely during minigame modal").
	# A minigame owns the whole screen, sets its own pace, and its own sounds are fast and small; an
	# era track underneath would fight all three. Restored in _close_modal_audio when the run ends.
	Audio.set_music_suppressed(true)
	# A normal reward round: make sure the reward chrome (timer/spectrum/skip/opt-out) is shown and
	# the Challenge chrome hidden, in case the previous round was a Challenge run.
	_challenge_mode = false
	_set_challenge_chrome(false)
	_base_amount = float(reward.get("base", 0.0))
	_reward_noun = String(reward.get("noun", "Legacy"))
	_result_heading = String(reward.get("heading", "THE INHERITANCE"))
	_base_label = String(reward.get("base_label", "Base"))
	_total_label = String(reward.get("total_label", "Total"))
	_format_as_money = bool(reward.get("as_money", false))
	_upside_only = bool(reward.get("upside_only", false))
	var purpose := String(reward.get("purpose", DEFAULT_PURPOSE))

	_bonus_max = maxf(0.0, bonus_max)
	_seconds_left = _tuning.minigame_duration_seconds
	_opt_out = false  # the in-round opt-out checkbox was removed; the preference lives in Settings

	# The result heading names what was won; set it before the round so the result view is
	# already correct when it appears.
	if _result_heading_label != null:
		_result_heading_label.text = _result_heading

	_review_mode = review_mode
	# Top section: the Back button in the tuner, the purpose blurb in a live round — never both.
	for back in _back_buttons:
		(back as Button).visible = review_mode
	if _purpose_label != null:
		_purpose = purpose
		_purpose_label.text = purpose
		_purpose_label.visible = not review_mode

	for child in _play_area.get_children():
		child.queue_free()
	var type_script: Script = forced_type
	if type_script == null:
		# Deal from every type EXCEPT the one dealt last round (see _last_dealt_type). On the
		# first deal of a launch the static is still empty, so pull the previous session's
		# choice off disk — otherwise every restart re-opens the door to a repeat.
		if _last_dealt_type == null:
			_last_dealt_type = _load_last_dealt()
		var pool := MINIGAME_TYPES.filter(func(t: Variant) -> bool: return t != _last_dealt_type)
		type_script = pool[randi() % pool.size()]
		_last_dealt_type = type_script
		_save_last_dealt(type_script)
	_active_minigame = type_script.new()
	_active_minigame.set_anchors_preset(Control.PRESET_FULL_RECT)

	# The player has now MET this game (Roadmap §8, Plans/Challenge_Mode_Gating.md). Reported here,
	# and ONLY here, on purpose — please don't "simplify" this placement away:
	#   • RANDOM DEALS ONLY. A REVIEW round from the Minigame Tuning screen passes an explicit
	#     forced_type, so it does not count as an encounter. Only a real transition deals randomly,
	#     and only that path marks — hence the `forced_type == null` guard.
	#   • CHALLENGE MODE DOES NOT COME THROUGH HERE AT ALL. It uses the separate start_challenge()
	#     entry point below, which never marks. So "a game met inside Challenge Mode must not
	#     circularly unlock itself there" holds by construction, not by a conditional. Do NOT add
	#     marking to start_challenge.
	#   • The mark must reach the DYNASTY (dynasty-scoped and permanent), NOT the per-install
	#     LAST_DEALT_PATH file, which is deliberately a presentation detail. The host has no dynasty
	#     handle, so it reports upward and Main writes it — the same route challenge_finished takes.
	# The instance already exists here, so its display_name() is the key with no probe needed.
	if forced_type == null:
		minigame_met.emit(_active_minigame.display_name())

	# Tell the type where this round's outcome curve sits (floor + bonus cap) BEFORE it begins, so
	# a type that aligns its scoring to the shared "full" line (match-3) can read it. See Minigame.
	_active_minigame.outcome_keep_floor = _tuning.minigame_keep_floor
	_active_minigame.outcome_bonus_max = _bonus_max
	_active_minigame.outcome_full_performance = _tuning.minigame_full_performance
	# The legacy-gem cap: how many gems earn the bonus, so a type knows when to stop spawning more.
	_active_minigame.legacy_bonus_cap = _tuning.legacy_bonus_max_gems
	_play_area.add_child(_active_minigame)
	_active_minigame.completed.connect(_on_minigame_completed)
	# Let a type ask for the shared big banner (Memory's "GEM ROUND"), so it matches MAX! exactly.
	_active_minigame.banner_requested.connect(_on_banner_requested)
	# Most types run for the shared default; a type may ask for more time on top of it (basketball).
	_seconds_left = _tuning.minigame_duration_seconds + maxf(0.0, _active_minigame.extra_seconds())
	# A no-timer type (Memory) hides the countdown entirely and ends the round only when it emits
	# `completed` itself — the clock branch in _process is skipped for it (see uses_timer).
	_timer_label.visible = _active_minigame.uses_timer()

	# The round does NOT start yet: the type stays un-begun and the clock paused behind the Begin
	# gate, so the player is never caught off guard. _on_begin_pressed starts it for real.
	# The play view stays hidden behind the (now scrim-less) Get Ready gate, so the not-yet-started
	# game doesn't show through the translucent card; _start_active_round reveals it on Begin.
	_play_view.visible = false
	_play_view.modulate = Color.WHITE
	_result_view.visible = false
	if _challenge_end_view != null:
		_challenge_end_view.visible = false  # a reward round never shows the Challenge end view
	_playing = false
	_skip_button.visible = false  # revealed on Begin (see _start_active_round)
	if _gem_badge != null:
		_gem_badge.visible = false  # hidden until a gem is collected this round
	_timer_label.text = "0:%02d" % int(ceil(_seconds_left))
	_timer_label.scale = Vector2.ONE

	# Reset the shared juice state so a new round starts at the keep floor with no carried-over
	# flash, pulse, or smoothing from the previous round.
	_display_mult = _tuning.minigame_keep_floor
	_left_seg_full = false
	_right_seg_full = false
	_left_seg_flash = 0.0
	_right_seg_flash = 0.0
	_keep_bar.queue_redraw()

	# Label SKIP with what skipping actually does: keep the DEFAULT amount as-is (multiplier 1.0),
	# forgoing only the bonus (Tim, 2026-07-09). Upside-only First Contact says so plainly.
	if _upside_only:
		_skip_button.text = "SKIP · no bonus"
	else:
		_skip_button.text = "SKIP · keep %s" % _format_amount(_base_amount)

	# The round's fiction: shown in live play, hidden in the review tuner (a practice
	# round has no story) and whenever a site provides none.
	var framing := String(reward.get("framing", ""))
	_begin_framing.text = framing
	_begin_framing.visible = framing != "" and not review_mode

	_begin_title.text = _active_minigame.display_name()
	_begin_howto.text = _active_minigame.how_to_play()
	# Reward stakes on the gate (Challenge Mode replaces this in start_challenge). Upside-only sites
	# frame it as pure upside; the amount-scaling sites warn that coming up short keeps less. Wording
	# tracks the result screen's "CAME UP SHORT" verdict — the old "weak round" phrasing was left
	# behind when that copy changed (Tim, 2026-07-22).
	if _upside_only:
		_begin_stakes.text = "Play well to earn a BONUS on this business — more income, faster cycles. Coming up short or a Skip just opens it at its base income. No penalty."
	else:
		_begin_stakes.text = "Play well to earn a BONUS on top of your inheritance. Skip to keep it as-is — coming up short keeps less."
	_begin_stakes.visible = true
	# A timed game warns the clock is about to start; a no-timer game invites the player to
	# take their time or explains the round end condition, so the hint never promises a clock that won't appear.
	var custom_hint := _active_minigame.begin_hint()
	if custom_hint != "":
		_begin_hint.text = custom_hint
	elif _active_minigame.uses_timer():
		_begin_hint.text = "The clock starts when you press Begin."
	else:
		_begin_hint.text = "No clock — take your time."
	_begin_hint.visible = true

	_begin_overlay.modulate = Color.WHITE
	_begin_overlay.visible = true
	visible = true


## Start a CHALLENGE MODE run (Tim, 2026-06-30): the given type runs ENDLESSLY — no timer, no
## win/loss — and the host tracks its raw score, shown live with the saved high score to beat.
## Launched from the Minigame Tuning screen, so review_mode is on (a Back button appears). Tapping
## DONE (or Back) saves the high score and returns to the list.
func start_challenge(type_script: Script) -> void:
	_beaten_high_score = false
	# THE SOUNDTRACK STEPS OUT (Tim, 2026-08-09: "remove soundtrack entirely during minigame modal").
	# A minigame owns the whole screen, sets its own pace, and its own sounds are fast and small; an
	# era track underneath would fight all three. Restored in _close_modal_audio when the run ends.
	Audio.set_music_suppressed(true)
	_challenge_mode = true
	_review_mode = true
	_set_challenge_chrome(true)

	# Back button visible (review context); the purpose blurb is hidden — the score readouts take
	# the top slot instead.
	for back in _back_buttons:
		(back as Button).visible = true
	if _purpose_label != null:
		_purpose_label.visible = false

	for child in _play_area.get_children():
		child.queue_free()
	_active_minigame = type_script.new()
	_active_minigame.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Tell the type to run endlessly BEFORE begin() (see Minigame.challenge_mode).
	_active_minigame.challenge_mode = true
	_play_area.add_child(_active_minigame)
	# A type shouldn't self-complete in Challenge Mode, but connect anyway — a stray completion is
	# simply ignored (see _on_minigame_completed).
	_active_minigame.completed.connect(_on_minigame_completed)
	# A MISS drains the keep-alive timer (Catch's dropped coin, Timing's failed lock). The type emits
	# challenge_time_penalty(points) — what a matching HIT would have earned — and the host drains the
	# clock (see _on_challenge_time_penalty). Connected here on the FRESH per-run instance, so it can
	# never double-connect across runs.
	_active_minigame.challenge_time_penalty.connect(_on_challenge_time_penalty)

	_active_type_key = _active_minigame.display_name()
	_challenge_high = ChallengeScores.get_high_score(_active_type_key)
	_score_label.text = "Score: 0"
	_highscore_label.text = "Best: %s" % _group_thousands(_challenge_high)
	# The skip control becomes the "I'm done" control in Challenge Mode.
	_skip_button.text = "DONE"

	# A SELF-ENDING game (Memory, Wave B) ends its own run via `completed` and uses NO keep-alive timer,
	# so hide the timer bar for it (the progress bar + score/best/next-tier still show). A timer-driven
	# game keeps the timer bar that _set_challenge_chrome already turned on.
	if _challenge_timer_margin != null:
		_challenge_timer_margin.visible = not _active_minigame.challenge_self_ends()

	# Seed the keep-alive run timer (Wave 2): a small starting budget (a per-game override for a game
	# that needs a longer runway, else the global knob), the run's opening score captured so the first
	# top-up measures from it, and the fire-once guard cleared. The clock does not drain until the player
	# presses Begin (the round isn't _playing yet), so this is just the initial state.
	_challenge_time_left = ChallengeGoals.timer_start_seconds(_active_type_key)
	_challenge_last_score = _active_minigame.get_score()
	_challenge_ended = false
	_challenge_low_pulse = 0.0
	_refresh_challenge_timer_bar()

	# Seed the tier display's pulse tracker to the run's OPENING tier so a fresh run doesn't pop on frame
	# one, and clear any leftover pulse from a previous run. Seeding from the opening score (not the best)
	# means every tier climbed THIS run pops, including re-climbing already-banked tiers.
	var opening_score := _active_minigame.get_score() if _active_minigame != null else 0
	_challenge_shown_tier = ChallengeGoals.tier_for_score(_active_type_key, opening_score)
	_challenge_tier_pulse = 0.0
	_update_challenge_tier()

	_play_view.visible = false
	_play_view.modulate = Color.WHITE
	_result_view.visible = false
	if _challenge_end_view != null:
		_challenge_end_view.visible = false  # a fresh run starts on the gate, not the end view
	_playing = false
	_skip_button.visible = false  # revealed on Begin (see _start_active_round)
	if _gem_badge != null:
		_gem_badge.visible = false

	_begin_title.text = _active_minigame.display_name()
	_begin_howto.text = _active_minigame.how_to_play()
	_begin_framing.visible = false  # free play has no story to frame
	_begin_stakes.text = "Keep-alive challenge — the clock drains, and every point you score adds time. Bank your best tier before it runs out!"
	_begin_stakes.visible = true
	_begin_hint.text = "The clock starts when you press Begin."
	_begin_hint.visible = true

	_begin_overlay.modulate = Color.WHITE
	_begin_overlay.visible = true
	visible = true


## Swap the reward chrome for the Challenge chrome. Reward mode (on=false): the timer + outcome bar
## show. Challenge mode (on=true): the live score + best-to-beat show instead.
func _set_challenge_chrome(on: bool) -> void:
	_timer_label.visible = not on
	_keep_bar.visible = not on
	# The whole two-corner header (Score/Best on the left, Tier/Best on the right) toggles as one unit so
	# it vanishes cleanly in reward mode with no leftover empty line. Shown for EVERY challenge game
	# (self-ending ones included, unlike the keep-alive timer bar).
	if _challenge_header != null:
		_challenge_header.visible = on
	# The keep-alive timer bar takes the reward chrome's place in a challenge run. start_challenge
	# overrides it OFF for a self-ending game (which has no keep-alive timer).
	if _challenge_timer_margin != null:
		_challenge_timer_margin.visible = on


## Begin pressed on the Get Ready gate: hide it, start the chosen type, and unpause the clock — the
## one and only point where a round actually goes live.
func _on_begin_pressed() -> void:
	Audio.play(&"minigame_begin")
	if _active_minigame == null:
		return
	# Fade the cream gate off to unmask the game (plan §1), THEN start the round — so the clock
	# doesn't run during the fade. The actual go-live happens in _start_active_round when the
	# fade completes.
	var fade := create_tween()
	fade.tween_property(_begin_overlay, "modulate:a", 0.0, 0.25)
	fade.tween_callback(_start_active_round)


## The one and only point where a round actually goes live: hide the (now-invisible) gate, start
## the chosen type, and unpause the clock. Called by _on_begin_pressed's fade-out tween.
func _start_active_round() -> void:
	if _active_minigame == null:
		return
	_begin_overlay.visible = false
	_play_view.visible = true  # reveal the game now that the gate is gone and the round goes live
	_skip_button.visible = true  # the below-card SKIP / DONE control shows only during live play
	_active_minigame.begin(_tuning)
	_playing = true


func _process(delta: float) -> void:
	if not _playing:
		return
	# Reveal the shared "gem earned" badge the instant a Legacy gem is collected this round — uniform
	# across every game type (Tim, 2026-07-11). Checked before the mode branches so it runs for all.
	if _gem_badge != null and _active_minigame != null \
			and _active_minigame.get_legacy_gems_collected() > 0:
		_gem_badge.visible = true
	# Challenge Mode: keep the live score readout current, then run the keep-alive timer (drain, top up
	# by points scored, cap, and end the run at 0). Both are challenge-only — a reward round never
	# reaches this branch, so the keep-alive clock never touches a prestige/welcome-back round.
	if _challenge_mode:
		_update_challenge_score()
		_tick_challenge_timer(delta)
		return
	# A no-timer game (Memory) owns its own ending: no countdown and no max-early-out. Just keep the
	# outcome bar gliding and wait for the game to emit `completed` on its own (a clear, a miss, or
	# its bonus round). Checked before the timer logic so none of it runs for such a game.
	if _active_minigame != null and not _active_minigame.uses_timer():
		_refresh_keep_bar(delta)
		return
	# Pause the countdown while a type is mid-animation (e.g. match-3 cascades) so animation time
	# isn't charged to the player — but keep the spectrum bar gliding and show a "held" cue on the
	# timer so a stalled countdown doesn't read as a bug (plan §1).
	var busy := _active_minigame != null and _active_minigame.is_busy()
	if not busy:
		_seconds_left = maxf(0.0, _seconds_left - delta)
	_refresh_timer(delta, busy)
	_refresh_keep_bar(delta)
	# End the round the instant the player has achieved the MAXIMUM result — no reason to keep playing
	# a round already won outright (Tim, 2026-07-09). Applies to every game via its performance.
	if not busy and _current_performance() >= 1.0:
		_end_round()
		return
	if not busy and _seconds_left <= 0.0:
		_end_round()


## Refresh the Challenge Mode readouts: the live score, and the best-to-beat (which ticks up in real
## time once the current score passes the saved high, so a new record is visible as it happens).
func _update_challenge_score() -> void:
	var score := _active_minigame.get_score() if _active_minigame != null else 0
	_score_label.text = "Score: %s" % _group_thousands(score)
	if score > _challenge_high:
		_challenge_high = score
	_highscore_label.text = "Best: %s" % _group_thousands(_challenge_high)
	# Keep the large tier display current too — one call refreshes the current/best readout and advances
	# any tier-up pulse (see _update_challenge_tier).
	_update_challenge_tier()


## Refresh the large TIER display (Tim, 2026-07-22). Shows the CURRENT tier (from the live score) over
## the BEST tier reached (from `_challenge_high`), or "TIER MAX" at the summit. Fires a pulse — a brief
## scale-up + gold brighten — the instant the current tier climbs a rung, so a tier-up is unmissable
## (low-vision rule). Called every frame from _update_challenge_score, and once at seed in start_challenge.
func _update_challenge_tier() -> void:
	if _challenge_tier_label == null:
		return
	var gk := _active_type_key
	var score := _active_minigame.get_score() if _active_minigame != null else 0
	var current := ChallengeGoals.tier_for_score(gk, score)
	var best := ChallengeGoals.tier_for_score(gk, _challenge_high)
	# Pop the display the moment the current tier rises past the last one we showed (once per crossing).
	if current > _challenge_shown_tier:
		_challenge_tier_pulse = 1.0
		# A TIER CLIMBED mid-run — the ladder moving is the reason to keep playing, so it gets its own
		# beat rather than being lumped in with an ordinary score.
		Audio.play(&"challenge_tier")
	# BEATING THE STORED HIGH SCORE, once per run: the moment the run stops being practice.
	if not _beaten_high_score and _challenge_high > 0 and score > _challenge_high:
		_beaten_high_score = true
		Audio.play(&"minigame_best")
	_challenge_shown_tier = current
	# Decay the pulse toward 0 over ~0.4s (rate 2.5/sec). Uses the Control's own frame delta so no delta
	# needs threading in here, mirroring the timer bar's decay pattern.
	_challenge_tier_pulse = maxf(0.0, _challenge_tier_pulse - get_process_delta_time() * 2.5)

	# The primary reads the CURRENT tier ("TIER 3", or "TIER MAX" at the summit); the best tier reached
	# nestles underneath ("Best: 7" / "Best: MAX"), mirroring the Score/Best pairing on the left.
	_challenge_tier_label.text = "TIER MAX" if current >= ChallengeGoals.MAX_TIER else "TIER %d" % current
	if _best_tier_label != null:
		_best_tier_label.text = "Best: MAX" if best >= ChallengeGoals.MAX_TIER else "Best: %d" % best

	# Apply the pulse as a brief scale-up + gold color flash, pivoting on the label's center so it grows
	# from the middle rather than the top-left. At rest (pulse 0) it sits at scale 1.0 and its resting
	# black. The flash uses the FONT COLOR, not modulate: modulate multiplies the glyph color, and the
	# tier text is now black (0 × anything = 0), so a modulate brighten would be invisible — the color
	# lerp flashes it toward gold on a tier-up and eases back to black (Tim, 2026-07-22).
	_challenge_tier_label.pivot_offset = _challenge_tier_label.size * 0.5
	_challenge_tier_label.scale = Vector2.ONE * (1.0 + 0.35 * _challenge_tier_pulse)
	_challenge_tier_label.add_theme_color_override(
		"font_color", Color.BLACK.lerp(UiPalette.MUSTARD_GOLD, _challenge_tier_pulse))


## Advance the keep-alive run timer one frame (Wave 2, Plans/Challenge_Mode.md §1). Only called from
## _process while a challenge round is live (_playing true, _challenge_mode true):
##   • PAUSE while the game is busy — Memory's playback, Match-3 cascades, Timing's freeze — so the
##     player is never drained by time they can't act in. No drain, no top-up, and the last-score
##     anchor is left alone (so points scored DURING the pause are credited when it ends).
##   • Otherwise drain 1s per second, then top up by the points just gained (each point buys
##     seconds_per_point seconds for this game), and clamp to [0, cap] — a hot streak can't stockpile
##     an unlimited cushion.
##   • At 0 the run ENDS, exactly once, through the same _end_challenge path DONE/Back use (records the
##     arcade score, shows the end view + credit feedback, emits challenge_finished).
func _tick_challenge_timer(delta: float) -> void:
	if _challenge_ended:
		return
	# A SELF-ENDING game (Memory, Wave B) does not use the keep-alive timer at all — it ends its own run
	# via `completed` (routed in _on_minigame_completed). Skip the whole drain/top-up for it; its timer
	# bar is already hidden (see start_challenge).
	if _active_minigame != null and _active_minigame.challenge_self_ends():
		return
	var busy := _active_minigame != null and _active_minigame.is_busy()
	if not busy:
		_challenge_time_left -= delta
		var score := _active_minigame.get_score() if _active_minigame != null else 0
		var gained := score - _challenge_last_score
		# Every game's get_score() is MONOTONIC (catches / locks / points only ever rise), so a top-up
		# only ever ADDS time — the `gained > 0` guard skips the no-op zero-gain frames. A MISS never
		# shows up here; its time cost arrives through the explicit challenge_time_penalty channel
		# (see _on_challenge_time_penalty), which drains the timer directly.
		if gained > 0:
			# The shared "you scored" beat. Every game's get_score() is monotonic, so a positive gain
			# is unambiguously a success in that game's own terms, whatever the gesture was.
			Audio.play(&"minigame_score")
			_challenge_time_left += float(gained) * ChallengeGoals.seconds_per_point(_active_type_key)
		_challenge_last_score = score
		_challenge_time_left = clampf(_challenge_time_left, 0.0, ChallengeGoals.timer_cap_seconds())
	# Advance the low-time pulse phase and refresh the readout every frame — even while busy, so a
	# paused clock still shows its held value.
	_challenge_low_pulse += delta
	_refresh_challenge_timer_bar()
	if _challenge_time_left <= 0.0:
		# Fire the end path exactly once. The guard (plus _end_challenge clearing _playing) makes sure
		# it can't re-trigger while the end view is up.
		_challenge_ended = true
		_end_challenge()


## A MISS in a challenge run drains the keep-alive timer (Plans/Challenge_Mode.md). The active minigame
## emits Minigame.challenge_time_penalty(points), where `points` is what a matching HIT would have earned
## (Catch: the dropped coin's value; Timing: 1 for a failed lock). We drain by the SAME rate a hit tops
## up (seconds_per_point), scaled by the tunable miss-penalty ratio — so a miss costs miss_penalty_ratio x
## what the hit was worth. Floored at 0. Gated to an ACTIVE run so a stray emit never drains a dead clock.
func _on_challenge_time_penalty(points: float) -> void:
	# The one MISS every game already reports through a shared channel. Per-game misses that do not
	# cost time (a whiffed basketball in reward mode) belong to the per-game pass.
	Audio.play(&"minigame_miss")
	if not _challenge_mode or _challenge_ended:
		return
	var drain := ChallengeGoals.miss_penalty_ratio() * points * ChallengeGoals.seconds_per_point(_active_type_key)
	_challenge_time_left = maxf(0.0, _challenge_time_left - drain)
	_refresh_challenge_timer_bar()


## Update the keep-alive timer bar: the seconds readout, the low-time red-pulse, and a redraw so the
## fill tracks the clock. Called each frame during a run and once at seed (start_challenge).
func _refresh_challenge_timer_bar() -> void:
	if _challenge_timer_seconds_label == null or _challenge_timer_bar == null:
		return
	_challenge_timer_seconds_label.text = "%.1fs" % maxf(0.0, _challenge_time_left)
	# Under the low threshold the whole bar pulses (~2 Hz) so a run about to die is unmissable.
	if _challenge_time_left <= CHALLENGE_TIMER_LOW_SECONDS:
		var pulse := 0.55 + 0.45 * absf(sin(_challenge_low_pulse * TAU * 2.0))
		_challenge_timer_bar.modulate = Color(1, 1, 1, pulse)
	else:
		_challenge_timer_bar.modulate = Color.WHITE
	_challenge_timer_bar.queue_redraw()


## Build the keep-alive timer bar's styleboxes once (reused every frame, minigame-lag rule): a dark
## ink track, a green normal fill, and a red low-time fill. Dark/legible, not washed out (house style).
func _build_challenge_timer_styleboxes() -> void:
	_challenge_timer_track = StyleBoxFlat.new()
	_challenge_timer_track.bg_color = UiPalette.INK_NAVY
	_challenge_timer_track.set_corner_radius_all(16)
	_challenge_timer_track.border_color = UiPalette.NAVY
	_challenge_timer_track.set_border_width_all(2)
	_challenge_timer_fill = StyleBoxFlat.new()
	_challenge_timer_fill.bg_color = UiPalette.MONEY_GREEN
	_challenge_timer_fill.set_corner_radius_all(12)
	_challenge_timer_low = StyleBoxFlat.new()
	_challenge_timer_low.bg_color = UiPalette.KETCHUP_RED
	_challenge_timer_low.set_corner_radius_all(12)


## Draw the keep-alive timer bar: the dark track, then a fill inset inside it whose width is the
## fraction of the clock still left (time_left / cap). Red under the low threshold, green above.
func _draw_challenge_timer_bar() -> void:
	var w := _challenge_timer_bar.size.x
	var h := _challenge_timer_bar.size.y
	if w <= 0.0 or h <= 0.0 or _challenge_timer_track == null:
		return
	var cap := ChallengeGoals.timer_cap_seconds()
	var frac := clampf(_challenge_time_left / maxf(0.0001, cap), 0.0, 1.0)
	_challenge_timer_bar.draw_style_box(_challenge_timer_track, Rect2(0, 0, w, h))
	if frac > 0.0:
		var pad := 4.0
		var fill_w := frac * (w - 2.0 * pad)
		if fill_w > 1.0:
			var low := _challenge_time_left <= CHALLENGE_TIMER_LOW_SECONDS
			var box := _challenge_timer_low if low else _challenge_timer_fill
			_challenge_timer_bar.draw_style_box(box, Rect2(pad, pad, fill_w, h - 2.0 * pad))


## A type finished on its own (e.g. the timing bar's last lock) — end with its result. In a normal
## round this ends the round. In Challenge Mode it is ignored for a timer-driven game (the run ends on
## the keep-alive clock or DONE) — EXCEPT for a SELF-ENDING game (Memory, Wave B), whose own `completed`
## IS the run end: route it to the same _end_challenge path DONE/timer-death use, fire-once via the
## shared _challenge_ended guard.
func _on_minigame_completed(_performance: float) -> void:
	if not _playing:
		return
	if _challenge_mode:
		if _active_minigame != null and _active_minigame.challenge_self_ends() and not _challenge_ended:
			_challenge_ended = true
			_end_challenge()
		return
	_end_round()


## Format an integer with thousands separators ("1,240"), for the Challenge score readouts.
func _group_thousands(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "," + grouped
	return ("-" if value < 0 else "") + grouped


## End a Challenge run: record the final score, show the Challenge end view (with any tier-credit
## feedback), and wait there for BACK TO LIST. Called by DONE and by Back. No longer closes the
## screen itself — _exit_challenge does that once the player has seen the result.
func _end_challenge() -> void:
	_playing = false
	Audio.play(&"minigame_over")
	var score := _active_minigame.get_score() if _active_minigame != null else 0
	# Keep driving the arcade "Best" store (unchanged) — that still powers the tuning list's Best
	# label. The dynasty tier credit is a SEPARATE path, reported via challenge_finished below.
	ChallengeScores.record_score(_active_type_key, score)
	# Swap to the end view showing the final score; the credit line stays blank until Main reports.
	_show_challenge_end(score)
	# Report the finished run so Main can credit any newly-cleared tiers into the dynasty bonus and
	# hand the outcome back to show_challenge_credit. Signals are synchronous, so by the time this
	# returns the credit line is already filled (when routed through Main).
	Audio.set_music_suppressed(false)
	challenge_finished.emit(_active_type_key, score)


## Reveal the Challenge end view: hide the play chrome and result view, show the final score, and
## clear the credit line so it is blank until show_challenge_credit fills it (a run credited through
## Main fills it synchronously during the challenge_finished emit).
func _show_challenge_end(score: int) -> void:
	_skip_button.visible = false
	_play_view.visible = false
	_result_view.visible = false
	if _challenge_score_label != null:
		_challenge_score_label.text = "Final score: %s" % _group_thousands(score)
	if _challenge_credit_label != null:
		_challenge_credit_label.text = ""
		_challenge_credit_label.visible = false
	if _challenge_end_view != null:
		_challenge_end_view.visible = true
	visible = true


## Fill the Challenge end view's tier-credit line from Main's credit report (see
## DynastyState.credit_challenge_score). Called by Main (via MinigameReviewScreen) after crediting.
##   improved → the "NEW TIER" windfall: the tier just cleared, and which TRACK the newly-cleared
##              payout paid — the income the tier JUST added (income_after − income_before) and/or the
##              Legacy it added (legacy_after − legacy_before). A payout tier only ever pays ONE track,
##              but a run that vaults several payout tiers at once can raise both, so both are handled.
##              A tier gained with no payout crossed reads as progress toward the next reward.
##   not improved → a quiet neutral line naming the best tier still held (or an invitation to reach
##                  the first goal if none is cleared yet).
func show_challenge_credit(result: Dictionary) -> void:
	if _challenge_credit_label == null:
		return
	if bool(result.get("improved", false)):
		var new_tier := int(result.get("new_tier", 0))
		var income_gain := (float(result.get("income_after", 0.0)) - float(result.get("income_before", 0.0))) * 100.0
		var legacy_gain := (float(result.get("legacy_after", 0.0)) - float(result.get("legacy_before", 0.0))) * 100.0
		var text := "NEW TIER %d" % new_tier
		if income_gain > 0.001:
			text += "\n+%.1f%% INCOME" % income_gain
		if legacy_gain > 0.001:
			text += "\n+%.1f%% LEGACY" % legacy_gain
		# A tier cleared that wasn't a payout tier still counts — it's a step toward the next reward.
		if income_gain <= 0.001 and legacy_gain <= 0.001:
			text += "\ntier banked — next reward ahead"
		_challenge_credit_label.text = text
		_challenge_credit_label.add_theme_color_override("font_color", UiPalette.DARK_GOLD)
	else:
		var best := int(result.get("old_tier", 0))
		if best > 0:
			_challenge_credit_label.text = "No new tier — best is tier %d" % best
		else:
			_challenge_credit_label.text = "No tier cleared yet — reach the first goal to earn a bonus"
		# A quiet navy for the neutral line, so a non-improving run doesn't read as a reward.
		_challenge_credit_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_challenge_credit_label.visible = true


## Leave the Challenge run for good: only reached from the end view's BACK TO LIST button. Clears
## Challenge Mode, hides the screen, and returns to the Minigame Tuning list (back_pressed).
func _exit_challenge() -> void:
	_challenge_mode = false
	if _challenge_end_view != null:
		_challenge_end_view.visible = false
	visible = false
	Audio.set_music_suppressed(false)
	back_pressed.emit()


# ---------------------------------------------------------------------------
# The universal "Legacy kept" indicator
# ---------------------------------------------------------------------------

## Performance (0..1) -> kept multiplier. A two-segment curve (Tim, work item 4, 2026-07-10) so
## STANDARD play is neutral, not punishing: below the "full" point the multiplier eases from
## keep_floor (a modest downside at performance 0) up to 1.0; at/above it, up to the extra-high bonus
## (1.0 + bonus_max) at performance 1.0. `minigame_full_performance` is where 1.0 sits — the same
## value a skip banks. One curve for every minigame type.
func _multiplier_for_performance(performance: float) -> float:
	var perf := clampf(performance, 0.0, 1.0)
	var full_perf := clampf(_tuning.minigame_full_performance, 0.0001, 0.9999)
	if perf < full_perf:
		return lerpf(_tuning.minigame_keep_floor, 1.0, perf / full_perf)
	return lerpf(1.0, 1.0 + _bonus_max, (perf - full_perf) / (1.0 - full_perf))


func _current_performance() -> float:
	return _active_minigame.get_performance() if _active_minigame != null else 0.0


func _keep_color(mult: float) -> Color:
	# Below the "full" line the bar heats up red -> orange -> yellow as you approach 100%; at and
	# above full it cools the other way, green -> blue, as you climb into the extra-high bonus band
	# (Tim, 2026-06-25). The deliberate red/yellow -> green jump at exactly 100% marks the moment
	# you stop losing Legacy and start banking the full inheritance.
	if mult < 1.0:
		var floor_mult := _tuning.minigame_keep_floor
		var t := clampf((mult - floor_mult) / maxf(0.0001, 1.0 - floor_mult), 0.0, 1.0)
		# Two warm segments: red -> orange in the first half, orange -> yellow in the second.
		if t < 0.5:
			return UiPalette.KETCHUP_RED.lerp(UiPalette.ORANGE, t / 0.5)
		return UiPalette.ORANGE.lerp(UiPalette.MUSTARD_GOLD, (t - 0.5) / 0.5)
	var into_extra := clampf((mult - 1.0) / maxf(0.0001, _bonus_max), 0.0, 1.0)
	return UiPalette.MONEY_GREEN.lerp(UiPalette.CYCLE_BLUE, into_extra)


## Format an amount the way this round's reward wants it: as dollars (the cash pile) or as a
## plain count of the reward noun (e.g. "12 Legacy"). Counts floor to whole units.
func _format_amount(amount: float) -> String:
	if _format_as_money:
		return Money.of(amount).display()
	# A plain count (Legacy) still gets the common large-number abbreviation — "14.9M Legacy", not
	# "14863217 Legacy" (Tim, 2026-07-23). Money.abbrev is the money display minus the "$", so small
	# counts read in full ("12 Legacy") and large ones abbreviate, matching every other big number.
	return "%s %s" % [Money.abbrev(floorf(amount)), _reward_noun]


## Update the focal timer each frame: for the last TIMER_PULSE_SECONDS it pops once per second
## (bigger + brighter toward gold on each tick), and dims to a muted color while the type is
## mid-animation to show the countdown is held. The text stays the same width whether held or not —
## the old "⏸" glyph widened the right-aligned label, so the timer visibly slid left during a
## match's animation (Tim, 2026-07-09); the muted color alone now carries the held cue.
func _refresh_timer(delta: float, busy: bool) -> void:
	var secs := int(ceil(_seconds_left))
	if busy:
		_timer_label.text = "0:%02d" % secs
		_set_timer_color(UiPalette.NAVY)
		_set_timer_scale(1.0)
		return

	_timer_label.text = "0:%02d" % secs
	var color := UiPalette.KETCHUP_RED
	var pulse := 1.0
	if secs != _last_ticked_second and _seconds_left <= TIMER_PULSE_SECONDS and _seconds_left > 0.0:
		# One cue per displayed second, on the same tick the label pops. The visual urgency has been
		# there since 2026-07-09; this is the audible half of it.
		Audio.play(&"minigame_countdown")
	_last_ticked_second = secs
	if _seconds_left <= TIMER_PULSE_SECONDS and _seconds_left > 0.0:
		# One pop per second: the fractional part of the remaining time runs 1→0 within each second
		# and jumps back to ~1 the instant the displayed number ticks down, so the pop lands ON each
		# tick and eases out over that second. Squared for a sharper spike. Bigger + brighter at peak.
		var into_second := _seconds_left - floorf(_seconds_left)
		var pop := into_second * into_second
		color = UiPalette.KETCHUP_RED.lerp(UiPalette.MUSTARD_GOLD, pop)
		pulse = 1.0 + 0.3 * pop
	_set_timer_color(color)
	_set_timer_scale(pulse)


## Apply the timer's font color only when it actually changed — re-applying a theme
## override every frame rebuilds the label's theme cache for nothing (minigame lag
## pass, Tim 2026-07-06). Outside the warn/critical pulse the color is constant.
var _timer_color := Color.TRANSPARENT
func _set_timer_color(color: Color) -> void:
	if color != _timer_color:
		_timer_color = color
		_timer_label.add_theme_color_override("font_color", color)


## Scale the timer label about its own center (a Label scales from its top-left by default, which
## would drift the centered text sideways as it pulses).
func _set_timer_scale(factor: float) -> void:
	_timer_label.pivot_offset = _timer_label.size / 2.0
	_timer_label.scale = Vector2(factor, factor)


## Glide the outcome bar toward the live multiplier and fire a brief flash the moment either segment
## first fills completely. The smoothed value `_display_mult` is what _draw_keep_bar paints.
func _refresh_keep_bar(delta: float) -> void:
	var target := _multiplier_for_performance(_current_performance())
	var weight := clampf(delta * KEEP_BAR_LERP_SPEED, 0.0, 1.0)
	_display_mult = lerpf(_display_mult, target, weight)

	var floor_mult := _tuning.minigame_keep_floor
	var left_full := (_display_mult - floor_mult) / maxf(0.0001, 1.0 - floor_mult) >= 1.0
	var right_full := (_display_mult - 1.0) / maxf(0.0001, _bonus_max) >= 1.0
	# Fire each segment's flash once, the moment it first completes (re-arm if it drops back below).
	if left_full and not _left_seg_full:
		_left_seg_flash = 1.0
	if right_full and not _right_seg_full:
		_right_seg_flash = 1.0
	_left_seg_full = left_full
	_right_seg_full = right_full
	_left_seg_flash = maxf(0.0, _left_seg_flash - delta * 3.0)
	_right_seg_flash = maxf(0.0, _right_seg_flash - delta * 3.0)
	_keep_bar.queue_redraw()


## Build the two-segment bar's styleboxes once, reused every frame so no StyleBoxFlat is allocated
## per draw (minigame-lag rule).
func _build_segment_styleboxes() -> void:
	var green := UiPalette.MONEY_GREEN
	var blue := UiPalette.CYCLE_BLUE
	_seg_track_left = _make_segment_box(green.darkened(0.62), true)
	_seg_track_right = _make_segment_box(blue.darkened(0.62), true)
	_seg_fill_left = _make_segment_box(green, false)
	_seg_fill_right = _make_segment_box(blue, false)
	_seg_flash_box = _make_segment_box(Color(1, 1, 1, 1), false)


func _make_segment_box(color: Color, is_track: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(16)
	if is_track:
		box.border_color = UiPalette.NAVY
		box.set_border_width_all(2)
	return box


## The two-segment outcome bar (Tim, 2026-07-09): two separate rounded squares side by side. The LEFT
## (green) fills as the smoothed multiplier climbs floor → 1.0 (the "full" / keep-100% line); the
## RIGHT (blue) then fills as it climbs 1.0 → 1.0 + bonus_max (the max bonus). Each has a dark track
## and a bright fill that grows left→right, and flashes briefly the instant it completes.
func _draw_keep_bar() -> void:
	var w := _keep_bar.size.x
	var h := _keep_bar.size.y
	if w <= 0.0 or h <= 0.0 or _seg_track_left == null:
		return
	var floor_mult := _tuning.minigame_keep_floor
	var left_frac := clampf((_display_mult - floor_mult) / maxf(0.0001, 1.0 - floor_mult), 0.0, 1.0)
	var right_frac := clampf((_display_mult - 1.0) / maxf(0.0001, _bonus_max), 0.0, 1.0)

	var gap := 12.0
	var seg_w := (w - gap) * 0.5
	_draw_segment(Rect2(0, 0, seg_w, h), _seg_track_left, _seg_fill_left, left_frac, _left_seg_flash)
	_draw_segment(Rect2(seg_w + gap, 0, seg_w, h), _seg_track_right, _seg_fill_right, right_frac, _right_seg_flash)


## Draw one rounded segment: the dark track, a bright fill inset inside it that grows left→right to
## `frac`, and a brief white flash overlay when the segment has just completed.
func _draw_segment(rect: Rect2, track: StyleBoxFlat, fill: StyleBoxFlat, frac: float, flash: float) -> void:
	_keep_bar.draw_style_box(track, rect)
	if frac > 0.0:
		var pad := 4.0
		var fill_w := frac * (rect.size.x - 2.0 * pad)
		if fill_w > 1.0:
			_keep_bar.draw_style_box(fill, Rect2(rect.position.x + pad, pad, fill_w, rect.size.y - 2.0 * pad))
	if flash > 0.0:
		_seg_flash_box.bg_color = Color(1, 1, 1, clampf(flash, 0.0, 1.0) * 0.7)
		_keep_bar.draw_style_box(_seg_flash_box, rect)


# ---------------------------------------------------------------------------
# Ending
# ---------------------------------------------------------------------------

func _end_round() -> void:
	_playing = false
	Audio.play(&"minigame_over")
	var performance := _current_performance()
	# The spectrum bar's fill is SMOOTHED (lerped toward the live value each frame while playing). Now
	# that the round is over the lerp stops, so snap the bar to the true final multiplier — otherwise a
	# round that ends the instant the player maxes out shows the MAX! flash over a bar that hadn't
	# finished filling (Tim, 2026-07-10). The bar stays visible behind the flash, so this must be full.
	_display_mult = _multiplier_for_performance(performance)
	_keep_bar.queue_redraw()
	# A round can end for two reasons: the clock ran out, or the player hit the MAXIMUM result and there
	# was no point playing on. In the latter case flash "MAX!" over the card for a beat before the result
	# appears, so the player understands the round ended because they maxed it — not that it was cut off
	# (Tim, 2026-07-10). "Early" = the timer still had time left; a max reached exactly as the clock
	# expired just shows the result normally. Universal here in the host, so every minigame behaves alike.
	var ended_on_max := performance >= 1.0 and _seconds_left > 0.0 and not _challenge_mode
	if ended_on_max:
		_flash_max_then(func() -> void: _show_result(_multiplier_for_performance(performance)))
		return
	_show_result(_multiplier_for_performance(performance))


## Flash a big "MAX!" over the card for about a second, then run `after` (which shows the result).
## Hides the SKIP control first (the round is over), then defers to the shared flash_banner so every
## maxed-out round announces the same way. Kept as its own name for the max-out call site.
func _flash_max_then(after: Callable) -> void:
	# The play view stays up behind the flash until the result swaps in, so the board doesn't blank
	# out mid-celebration; but the round is over, so hide the below-card SKIP control.
	_skip_button.visible = false
	flash_banner("MAX!", UiPalette.MUSTARD_GOLD, after)


## Flash `text` big and gold-styled over the CENTER of the screen for about a second, then run
## `after`. Shared by the universal "MAX!" celebration and any minigame that asks for a mid-round
## banner via banner_requested (Memory's "GEM ROUND"), so every big centered flash looks and sizes
## the SAME (Tim, 2026-07-10). Built on demand and freed when done. Does NOT touch the SKIP control
## or the play view, so it is safe to use mid-round (the caller decides what to hide).
func flash_banner(text: String, color: Color, after: Callable) -> void:
	var flash := Label.new()
	flash.text = text
	flash.add_theme_font_size_override("font_size", UiPalette.FONT_DISPLAY)
	flash.add_theme_color_override("font_color", color)
	flash.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
	flash.add_theme_constant_override("outline_size", 12)
	flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Cover the whole screen and center the word over the card. z high so it sits above everything. The
	# label is anchored to fill the screen, so its centered text lands at screen center; we scale it
	# about the SCREEN center (this host's own size) — reading the label's own size right after add_child
	# gives (0,0), and forcing it fights the full-rect anchors (Tim, 2026-07-10).
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.z_index = 10
	flash.pivot_offset = size / 2.0
	add_child(flash)

	# Bloom in big, hold, then fade — about one second total. Built as a SEQUENTIAL tween (bloom → hold
	# → fade), pairing the bloom's scale + fade-in with parallel() so we never leave set_parallel latched
	# across the chain (that latch silently ran the steps out of order and nothing showed — Tim,
	# 2026-07-10).
	flash.scale = Vector2(0.5, 0.5)
	flash.modulate = Color(1, 1, 1, 0.0)
	var beat := create_tween()
	beat.tween_property(flash, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	beat.parallel().tween_property(flash, "modulate:a", 1.0, 0.18)
	beat.tween_interval(0.5)  # hold at full
	beat.tween_property(flash, "modulate:a", 0.0, 0.25)  # fade out
	beat.tween_callback(func() -> void:
		flash.queue_free()
		# Guard: the requesting minigame may have been freed (player left) during the ~1s banner.
		if after.is_valid():
			after.call())


## A minigame asked for the shared banner (see Minigame.banner_requested). Flash it, then run the
## type's continuation — e.g. Memory announces "GEM ROUND" and resumes into its bonus round.
func _on_banner_requested(text: String, color: Color, after: Callable) -> void:
	flash_banner(text, color, after)


func _show_result(mult: float) -> void:
	if _upside_only:
		_fill_first_contact_statement(mult)
	else:
		_fill_amount_statement(mult)

	# The type's own summary of how the round was played (empty for types that provide none).
	var summary := _active_minigame.result_summary() if _active_minigame != null else ""
	_result_summary_label.text = summary
	_result_summary_label.visible = summary != ""

	_refresh_legacy_result_line(mult)

	_play_view.visible = false
	_skip_button.visible = false  # the below-card control hides once the round resolves
	_result_view.visible = true
	visible = true
	_animate_result()


## Fill the statement for an amount-scaling site (succession Legacy / welcome-back cash): the base
## amount you brought in, the minigame's impact on it (a signed amount + the percent), and the final
## banked total — each clearly labelled so the outcome reads with context (Tim, 2026-07-10).
func _fill_amount_statement(mult: float) -> void:
	_stat_impact2_row.visible = false  # amount sites have a single impact line
	var kept := _base_amount * mult
	# Derive the impact from the SAME values the base and total rows show, so base + impact = total
	# exactly. Legacy is a whole-gem count (_format_amount floors it), so the delta must be the
	# difference of the floored amounts or the three numbers won't reconcile (Tim, 2026-07-10).
	var delta := (kept - _base_amount) if _format_as_money else (floorf(kept) - floorf(_base_amount))

	# Reset the row key/value colors that the branches below may tint, so nothing carries over.
	_stat_impact_key.add_theme_color_override("font_color", UiPalette.NAVY)

	if mult > 1.0 + 0.001:
		_result_verdict_label.text = "GREAT ROUND"
		# Darkened from the original mid-blue so the celebratory verdict still reads over the
		# translucent result card + themed backdrop (Tim, 2026-07-22 contrast pass, completing the
		# 07-20 teal/shortfall darkening) — still clearly blue, just deep enough to hold contrast.
		_result_verdict_label.add_theme_color_override("font_color", Color("#2E6FD6").darkened(0.25))
		_stat_impact_key.text = "Minigame bonus  (+%d%%)" % int(round((mult - 1.0) * 100.0))
		_stat_impact_val.text = "+%s" % _format_amount(delta)
		_stat_impact_val.add_theme_color_override("font_color", UiPalette.DARK_MONEY_GREEN)
	elif mult < 1.0 - 0.001:
		# Copy pass (Tim, 2026-07-20): the loss framing STAYS — falling short still costs something —
		# but the keep floor was retuned 0.5 -> 0.9, so the worst round now gives up a tenth, not a
		# half. "WEAK ROUND / kept 90%" was written for the old floor and read like a catastrophe.
		# We now name the SHORTFALL itself ("−10%"), which is both honest about the loss and
		# self-scaling: a small miss reads small. No math changed.
		_result_verdict_label.text = "CAME UP SHORT"
		# Any shortfall now gives up real reward (the keep floor is 0.9, so even a small miss costs
		# income), so the verdict always reads as one flat alarm red instead of the keep gradient's
		# gold-for-a-near-miss — a loss should never look celebratory (Tim, 2026-07-22). Darkened a
		# touch so it reads on the translucent result card (2026-07-20 contrast pass).
		_result_verdict_label.add_theme_color_override("font_color", UiPalette.KETCHUP_RED.darkened(0.2))
		_stat_impact_key.text = "Short of full  (−%d%%)" % int(round((1.0 - mult) * 100.0))
		_stat_impact_val.text = "−%s" % _format_amount(-delta)
		_stat_impact_val.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)
	else:
		_result_verdict_label.text = "FULL RESULT"
		_result_verdict_label.add_theme_color_override("font_color", UiPalette.DARK_MONEY_GREEN)
		_stat_impact_key.text = "Kept in full"
		_stat_impact_val.text = "—"
		_stat_impact_val.add_theme_color_override("font_color", UiPalette.NAVY)

	_stat_base_key.text = _base_label
	_stat_base_val.text = _format_amount(_base_amount)
	_stat_total_key.text = _total_label
	_stat_total_val.text = _format_amount(kept)


## Fill the statement for the upside-only First Contact round: the property's base income, the terms
## you negotiated (income boost + faster cycles, or none), and the opening income that buys — matching
## exactly what Main applies to the property (both read FIRST_CONTACT_BUCKETS).
func _fill_first_contact_statement(mult: float) -> void:
	var bucket := first_contact_bucket(mult, _bonus_max)
	var info: Dictionary = FIRST_CONTACT_BUCKETS[bucket]
	var income_mult := float(info["income"])
	var cycle_mult := float(info["cycle"])

	_result_verdict_label.text = String(info["label"])
	# First Contact's positive terms use a teal accent, darkened ~0.5 so it reads over the
	# translucent result card + themed backdrop (Tim, 2026-07-20 contrast pass). Applied at each
	# teal result site below too; the pale ATOMIC_TEAL is left untouched everywhere else in-game.
	_result_verdict_label.add_theme_color_override(
		"font_color", UiPalette.DARK_MONEY_GREEN if bucket == 0 else UiPalette.ATOMIC_TEAL.darkened(0.5))

	_stat_base_key.text = _base_label  # "Base income"
	_stat_base_val.text = "%s / cycle" % _format_amount(_base_amount)
	_stat_base_val.add_theme_color_override("font_color", UiPalette.NAVY)

	if bucket == 0:
		# No bonus: opens at its base income, and there is nothing extra to show on the second line.
		_stat_impact_key.text = "Negotiated terms"
		_stat_impact_val.text = "no bonus"
		_stat_impact_val.add_theme_color_override("font_color", UiPalette.NAVY)
		_stat_impact2_row.visible = false
	else:
		_stat_impact_key.text = "Income boost"
		_stat_impact_val.text = "+%d%%" % int(round((income_mult - 1.0) * 100.0))
		_stat_impact_val.add_theme_color_override("font_color", UiPalette.ATOMIC_TEAL.darkened(0.5))
		_stat_impact2_key.text = "Faster cycles"
		_stat_impact2_val.text = "−%d%%" % int(round((1.0 - cycle_mult) * 100.0))
		_stat_impact2_val.add_theme_color_override("font_color", UiPalette.ATOMIC_TEAL.darkened(0.5))
		_stat_impact2_row.visible = true

	_stat_impact_key.add_theme_color_override("font_color", UiPalette.NAVY)
	_stat_total_key.text = _total_label  # "Opening income"
	_stat_total_val.text = "%s / cycle" % _format_amount(_base_amount * income_mult)


## Show/hide the Legacy-gem bonus line on the result screen. Only appears when the player actually
## collected a gem this round; the wording depends on whether the round result let them keep it.
func _refresh_legacy_result_line(mult: float) -> void:
	if _result_legacy_label == null:
		return
	var collected := _active_minigame.get_legacy_gems_collected() if _active_minigame != null else 0
	if collected <= 0 or _legacy_lifetime <= 0:
		_result_legacy_label.visible = false
		return
	var amount := _legacy_bonus_amount(mult)
	if amount > 0:
		var great := _legacy_bonus_factor(mult) > 1.0
		_result_legacy_label.text = ("LEGACY BONUS  +%s gems!" % Money.abbrev(amount)) + ("  (great round!)" if great else "")
		_result_legacy_label.add_theme_color_override("font_color", UiPalette.DARK_GOLD)
	else:
		# Collected a gem but the round fell short of the "full" line, which is what keeps it. This IS
		# a real all-or-nothing loss, so it still says so — just without the harsher "lost" (Tim,
		# 2026-07-20 copy pass). "Legacy" is correct here at every site: the gem bonus is always
		# Legacy, even on the cash-pile round.
		_result_legacy_label.text = "Legacy bonus just missed — reach full to keep it"
		_result_legacy_label.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)
	_result_legacy_label.visible = true


## The round's Legacy-gem tier factor from its final multiplier: 0 below the "full" line (bad → keep
## nothing), 1.0 at/above full (normal → keep), and 1.0 + great_multiplier−1 deep in the bonus band
## (great → a proportional bonus). Mirrors the gating in Plans/Legacy_Bonus_System.md.
func _legacy_bonus_factor(mult: float) -> float:
	if mult < 1.0:
		return 0.0
	var into_bonus := (mult - 1.0) / maxf(0.0001, _bonus_max)
	if into_bonus >= _tuning.legacy_bonus_great_threshold:
		return _tuning.legacy_bonus_great_multiplier
	return 1.0


## The unearned Legacy to grant this round: capped collected gems × the round's tier factor × the
## per-gem fraction × lifetime Legacy. Returns 0 when nothing is owed; otherwise at least 1 (the
## early-game floor: if the player has any lifetime Legacy and earned a bonus, they always get ≥1).
func _legacy_bonus_amount(mult: float) -> int:
	var collected := _active_minigame.get_legacy_gems_collected() if _active_minigame != null else 0
	var factor := _legacy_bonus_factor(mult)
	if collected <= 0 or factor <= 0.0 or _legacy_lifetime <= 0:
		return 0
	var counted := mini(collected, maxi(1, _tuning.legacy_bonus_max_gems))
	# _legacy_bonus_multiplier is the site boost (1.0 normally; higher for a First Contact milestone).
	var raw := float(counted) * factor * _tuning.legacy_bonus_fraction * float(_legacy_lifetime) \
			* _legacy_bonus_multiplier
	return maxi(1, int(floor(raw)))


## The payoff beat (plan §1): fade the result view in, then bloom the verdict and the total figure
## with a brief scale pop and a flash to white, so the reveal reads as a reward, not an instant cut.
func _animate_result() -> void:
	_result_view.modulate = Color(1, 1, 1, 0)
	var reveal := create_tween()
	reveal.tween_property(_result_view, "modulate:a", 1.0, 0.25)

	for label in [_result_verdict_label, _stat_total_val]:
		# Capture each label's settled color so the white flash can resolve back to it.
		var final_color: Color = label.get_theme_color("font_color")
		label.pivot_offset = label.size / 2.0
		label.scale = Vector2(0.7, 0.7)
		label.add_theme_color_override("font_color", Color.WHITE)
		var bloom := create_tween()
		bloom.set_parallel(true)
		bloom.tween_property(label, "scale", Vector2.ONE, 0.4) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bloom.tween_property(label, "modulate", Color.WHITE, 0.0)  # ensure full opacity for the bloom
		bloom.tween_method(
				func(c: Color) -> void: label.add_theme_color_override("font_color", c),
				Color.WHITE, final_color, 0.45)


## Back (review mode only): abandon the round and return to the review list. No result is
## emitted — reviewing a minigame never touches the run's Legacy. In a Challenge run it saves the
## high score on the way out (same as DONE).
func _on_back_pressed() -> void:
	if _challenge_mode:
		_end_challenge()
		return
	_playing = false
	visible = false
	Audio.set_music_suppressed(false)
	back_pressed.emit()


## Skip (reward round): keep the DEFAULT amount as-is and leave — skipping forgoes the bonus but
## does NOT cost anything (Tim, 2026-07-09: skip keeps the default, not half). That is multiplier 1.0.
## In Challenge Mode this is the DONE button — it saves the high score and returns to the list instead.
func _on_skip_pressed() -> void:
	if _challenge_mode:
		_end_challenge()
		return
	_playing = false
	visible = false
	Audio.set_music_suppressed(false)
	finished.emit(1.0, _opt_out)


func _on_continue_pressed() -> void:
	visible = false
	var mult := _multiplier_for_performance(_current_performance())
	# Bank any Legacy-gem bonus first (real rounds only; review/Challenge never set _legacy_lifetime,
	# and a bad round yields 0), then hand the main outcome multiplier to the site that launched us.
	if not _review_mode and not _challenge_mode:
		var bonus := _legacy_bonus_amount(mult)
		if bonus > 0:
			legacy_bonus_earned.emit(bonus)
	Audio.set_music_suppressed(false)
	finished.emit(mult, _opt_out)
