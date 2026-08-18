class_name DevTuningPanel
extends Control

# The "Balance Tuning" panel (GDD §13 "Balance config screen") — a developer tool,
# not a player screen. It lists every numeric constant in TuningConfig and lets
# them be edited on-device, so balance can be felt on real hardware instead of
# only in the headless simulator.
#
# It lives INSIDE the Settings tab (Tim, 2026-07-06 — was a full-screen overlay):
# the Balance Tuning button swaps the tab's normal content for this panel, and
# Close swaps back. The tab's shared cream panel supplies the frame, so this
# control builds only its own content.
#
# How a change takes effect: the panel does not mutate the running game live —
# many constants are read once at startup, so a half-applied change would be
# inconsistent. Instead Apply writes the changed constants to the user:// override
# file (see TuningOverrides) and asks Main to reload the scene, which re-runs the
# normal startup path with the new numbers layered over the baked defaults. The
# current save is preserved across the reload, so only the tuning changes.
#
# It is built generically from reflection (every TYPE_INT / TYPE_FLOAT exported
# var on TuningConfig), so new constants appear here automatically with no UI work.
#
# Drive it from Main.gd:
#   1. setup()                          once, to build the static chrome
#   2. open(effective_tuning, baked)    to (re)populate rows and show the panel
#   3. listen for the signals below

## Close without applying anything.
signal closed

## Apply the given { constant_name: number } overrides and reload. Only constants
## that differ from the baked default are included; an empty dict clears overrides.
signal apply_requested(overrides: Dictionary)

## Discard every override and return to the baked defaults (then reload).
signal defaults_requested

## Wipe the save and start a brand-new dynasty from generation 1 (the folded-in
## reset). Destructive — the panel two-taps to confirm before emitting this.
signal reset_dynasty_requested

## Playtest "jump ahead" tools (Tim 2026-07-13) — Main applies each to the live game, saves, and
## reloads, so the mid/late game and a prestiged heir can be sampled in seconds. jump_epoch teleports
## to a tier; grant_legacy adds Legacy to spend; grant_cash adds spending money as a multiple of the
## current epoch's clear target.
signal jump_epoch_requested(tier: int)
signal grant_legacy_requested(amount: int)
signal grant_cash_requested(epoch_target_multiplier: float)
signal trigger_crash_requested
signal trigger_audit_requested
signal trigger_windfall_requested
signal clear_events_requested


# Large, legible type for phone reading (UI notes §1) — sized up 25% from the first
# pass for on-device readability (Tim). Still denser than the ceremony screens, since
# this is a long developer list, not a player moment.
const TITLE_SIZE := UiPalette.FONT_PAGE_TITLE
const SUBTITLE_SIZE := UiPalette.FONT_CARD_BODY
const ROW_LABEL_SIZE := UiPalette.FONT_SUBHEAD
const ROW_DESC_SIZE := UiPalette.FONT_LABEL
const ROW_VALUE_SIZE := UiPalette.FONT_SUBHEAD
const BUTTON_SIZE := UiPalette.FONT_SUBHEAD

## Fixed width (px) of the value editor column, so the constant names line up. Trimmed from 400 so a
## long name + the field can't push the row past the panel's right edge (Tim, 2026-07-09).
const VALUE_COLUMN_WIDTH := 300
## Minimum height (px) of a value editor — a comfortable thumb target.
const VALUE_HEIGHT := 72
## Clearance between each row's right edge and the scroll's overlaid scrollbar: the
## full scrollbar width plus a visible gap, or the bar sits ON the value field and the
## end of the text can't be tapped (Tim, 2026-07-06 — same rule as the property ladder).
const SCROLLBAR_GAP := UiPalette.SCROLLBAR_WIDTH + 16

## One concise, plain-language description per tuning constant, shown beneath its
## name so the panel is legible without cross-referencing TuningConfig.gd. Keyed by
## the constant's exact variable name. When a new constant is added to TuningConfig,
## add its description here too; anything missing simply shows no description.
const DESCRIPTIONS := {
	"logic_hz": "Logic ticks per second (fixed timestep).",
	"m1_starting_cash": "Cash a fresh founder starts with (intentionally $0).",
	"band_step": "How much steeper the cost curve gets at each milestone band.",
	"cycle_floor": "Fastest a cycle can become from milestone speed-ups (seconds).",
	"rush_pct": "Cycle fraction one rush-tap advances.",
	"hold_rush_per_second": "Auto-rush pulses per second while holding a property.",
	"wage_hold_taps_per_second": "Auto wage-taps per second while holding Clock In.",
	"wage_passive_fraction": "Seconds of passive income one Clock In tap pays (the executive-pay floor).",
	"wage_floor_bonus_per_level": "Executive-pay bonus per clock-in level (0.15 = +15% of the floor per level).",
	"frenzy_fill_hold_factor": "Frenzy charge from a held-rush pulse vs a real tap.",
	"buy_hold_initial_delay": "Pause before a held Buy button starts repeating (seconds).",
	"buy_hold_repeat_interval": "Gap between Buy auto-repeats while held (seconds).",
	"hire_hold_initial_delay": "Pause before a held Hire/Upgrade button starts repeating (seconds).",
	"hire_hold_repeat_interval": "Gap between Hire/Upgrade auto-repeats while held (seconds).",
	"staff_cost_fraction": "Alien staff hire cost as a fraction of that epoch's whole economy.",
	"staff_cost_property_growth": "How much pricier each higher rung's staff is.",
	"staff_level_step": "Income added per staff level (additive; cumulative ladder).",
	"staff_levels_per_epoch": "Staff levels each epoch unlocks (cap = this × epoch).",
	"staff_level_cost_base": "First staff level's cost as a fraction of the hire price.",
	"staff_level_cost_growth": "How much each further staff level costs vs the last (per block).",
	"retention_base_cost": "Legacy to retain the first property's first staff level.",
	"retention_cost_growth": "How much each deeper retained level costs vs the last.",
	"retention_property_step": "How much pricier each higher property's retention is.",
	"carb_debug_overlay": "1 shows a live per-row readout of the bubble numbers (diagnosis).",
	"carb_tier_idle_px": "Bubble speed on a still/full bar (px/s) — the slowest tier.",
	"carb_tier_flowing_px": "Bubble speed on a normally cycling bar / economy bar (px/s).",
	"carb_tier_rushed_px": "Bubble speed while TURBO is burning (px/s).",
	"carb_tier_frenzy_px": "Bubble speed while a property's rush is held (px/s) — the fastest tier.",
	"carb_tier_ease": "Seconds bubble speed eases over on a tier change (0 = instant, no rush ramp).",
	"minigame_duration_seconds": "Seconds each transition minigame lasts (shared by all games).",
	"minigame_keep_floor": "Reward kept on the WORST round (modest downside; higher = gentler, 1.0 = no penalty).",
	"minigame_full_performance": "Performance (0-1) that keeps exactly 100% — 'standard' play; below eases down, above earns bonus.",
	"match3_full_score": "Match-3 score that keeps 100% (higher = harder to reach full).",
	"match3_max_score": "Match-3 score for the max bonus / early win (higher = harder to max).",
	"match3_legacy_match_size": "Gems in a match needed to drop a Legacy gem (higher = rarer).",
	"legacy_bonus_fraction": "Legacy granted per collected gem, as a fraction of lifetime (0.001 = 0.1%).",
	"legacy_bonus_max_gems": "Most legacy moments one round can bank (1 = flat windfall).",
	"legacy_bonus_great_multiplier": "Bonus to the legacy grant on a great round (1.10 = +10%).",
	"legacy_bonus_great_threshold": "How far into the bonus band counts as a great round (0-1).",
	"legacy_bonus_first_contact_multiplier": "Extra multiplier on the epoch-transition (First Contact) legacy gem grant.",
	"legacy_gem_chance_catch": "Chance a legacy gem-coin appears in Catch Money.",
	"legacy_gem_chance_timing": "Chance a legacy gem appears in the Timing zone.",
	"legacy_gem_chance_balance": "Chance a legacy gem appears in the Balance zone.",
	"legacy_gem_chance_basketball": "Chance a legacy gem appears in Basketball.",
	"legacy_gem_chance_memory": "Chance the Memory gem bonus round appears after a full clear.",
	"memory_gem_sequence_length": "Length of the Memory gem bonus sequence (identical pads; higher = harder).",
	"basketball_launch_curve_exp": "Basketball throw ease (higher = gentler small pulls, finer aim).",
	"basketball_launch_max_drag": "Drag distance (px) for a full-power basketball throw (higher = more pull needed).",
	"basketball_max_throw_speed": "Max basketball throw speed (px/sec) — raw power.",
	"offline_efficiency": "Offline income rate vs live play (0–1).",
	"offline_cap_seconds": "Longest offline accrual window (seconds; 14400 = 4h).",
	"rush_momentum_heat_build_per_second": "How fast heat climbs while rushing (heat/sec; 1.0 heat = the Hot edge).",
	"rush_momentum_heat_build_hot_per_second": "Slower climb rate above the Hot edge (heat/sec; sets time-in-danger).",
	"rush_momentum_heat_bleed_per_second": "How fast heat cools when NOT rushing (heat/sec).",
	"rush_momentum_hard_ceiling": "Heat that instantly overheats — the bar's fixed end (vent windows are the real test).",
	"rush_momentum_cruise_bonus": "Safe rush bonus while holding WITHOUT overdrive (0.25 = +25%; capped at the Hot-edge bonus).",
	"rush_momentum_bonus_at_hot": "Income bonus at the Hot edge, heat 1.0 (0.30 = +30%).",
	"rush_momentum_bonus_peak": "Income bonus at max possible heat (0.55 = +55%).",
	"rush_momentum_locked_drain_per_second": "Heat drained per second while overheated (sets the lockout length).",
	"rush_momentum_rearm_seconds": "Extra delay after a full cool-down before rushing re-enables.",
	"rush_momentum_grace_seconds": "How long you still count as rushing after your last rush (bridges the pulse gaps).",
	"rush_momentum_vent_rate_at_cruise": "Expected vent checks per second while hovering just past the cruise point (0.05 = about one every 20 s); riding deeper raises the rate.",
	"rush_momentum_vent_rate_at_ceiling": "Expected vent checks per second at the very top of the bar (1.0 = about one per second) — the frantic end of the deeper-is-more-frequent ramp.",
	"rush_momentum_vent_refractory_min": "Shortest rolled quiet time after a vent (or engaging overdrive) before the next event can spawn (seconds).",
	"rush_momentum_vent_refractory_max": "Longest rolled quiet time before the next vent event (seconds) — the gap is rolled fresh each time so spacing feels random.",
	"rush_momentum_vent_approach_seconds": "How long an incoming vent event takes to travel across the bar to the trigger point (seconds of warning).",
	"rush_momentum_vent_window_duration": "Seconds to finish the vent gesture once the window telegraphs.",
	"rush_momentum_vent_duration_decay": "Window duration multiplier per tier reached (0.92 = 8% less time each tier).",
	"rush_momentum_vent_duration_floor": "Shortest the escalating window duration can get (seconds).",
	"rush_momentum_vent_gap_max": "Longest pause allowed between vent gesture beats (seconds; bigger = more forgiving).",
	"rush_momentum_vent_tap_max": "Longest press that still counts as the quick middle tap of VENT x2 (seconds).",
	"rush_momentum_vent_heat_drop": "Heat released by a successful vent (small drop = deep runs keep riding near the top).",
	"rush_momentum_vent_bonus_step": "Peak bonus added per successful vent (0.20 = +20% per rung; no cap).",
	"rush_momentum_vent_lifts_step_tiers": "Tiers between lift escalations (3 = demand 1 lift, then 2 from tier 3, then 3 from tier 6; max 3 lifts).",
	"rush_momentum_vent_fail_rearm_per_tier": "Extra re-arm seconds per earned vent tier when you overheat; 0 = off.",
	"rush_momentum_vent_fail_rearm_cap": "Most extra re-arm seconds the per-tier sting can add (keeps deep-run failures from ever-longer timeouts).",
	"rush_momentum_haptic_overheat_ms": "Vibration length (ms) when a rush overheats; 0 = off.",
	"rush_momentum_haptic_ready_ms": "Vibration length (ms) when rushing re-arms after a lockout; 0 = off.",
	"rush_momentum_haptic_vent_ms": "Vibration length (ms) of EACH vent telegraph pulse — one pulse per required lift, so a x2 window buzzes twice; 0 = off.",
	"rush_momentum_haptic_vent_gap_ms": "Silence (ms) between those vent telegraph pulses, so a x2/x3 reads as counted beats instead of one long buzz.",
	"frenzy_max_multiplier": "Peak income multiplier during a frenzy burn.",
	"frenzy_burn_duration": "How long a full frenzy burn lasts (seconds).",
	"frenzy_fill_per_tap": "Meter fill added per tap (fraction of the full bar).",
	"frenzy_decay_per_second": "Meter decay per idle second (fraction of full bar).",
	"frenzy_idle_grace": "Idle seconds before the meter begins to decay.",
	"frenzy_pop_floor": "Minimum charge needed to trigger a frenzy.",
	"estate_exemption_base": "Estate-tax-free amount at death ($).",
	"estate_tax_rate_base": "Estate tax rate before loopholes (0–1).",
	"loophole_rate_floor": "Lowest the estate tax can fall via loopholes.",
	"k_legacy": "Legacy payout scale on the power curve (K × (net/floor) ^ alpha).",
	"alpha_legacy": "Legacy curve exponent; lower = flatter yield, tames the prestige runaway.",
	"alpha_legacy_deep": "Mint exponent ABOVE the knee (0.06 = +15% gems per 10x deeper estate).",
	"legacy_knee_net": "Estate net where the mint curve bends to the deep exponent ($).",
	"legacy_cost_steepening": "Upgrade cost growth's own per-level multiplier — the uncapped shop's brake.",
	"legacy_upgrade_cost_multiplier": "Global x on every Legacy upgrade cost — the prestige-power brake (higher = a prestige buys fewer levels).",
	"challenge_bonus_scale": "Global x on every Challenge tier payout, both tracks (1.0 = authored ~24% income + 24% Legacy across all six games maxed).",
	"challenge_timer_start_seconds": "Challenge keep-alive run timer's starting seconds — a run begins with this on the clock and drains until scoring tops it up (Wave 2).",
	"challenge_timer_cap_seconds": "Challenge keep-alive run timer's max seconds — top-ups never bank the clock past this (Wave 2).",
	"challenge_miss_penalty_ratio": "Fraction of a hit's time-gain a MISS costs the keep-alive timer (0.5 = half): a dropped Catch coin / failed Timing lock drains this x what the hit would have added.",
	"challenge_show_all_games": "1 shows every minigame on the CHALLENGES screen, ignoring which ones you have met (testing aid; display only — it never marks a game as met).",
	"basketball_tier_base_cost": "Micro Basketball Challenge: baskets each tier costs for tiers 1-5 (the escalating cost's base). At 1, tier 5 = 5 baskets.",
	"basketball_tier_cost_increment": "Micro Basketball Challenge: baskets added to each tier's cost every 5 tiers (escalating cost climbs).",
	"basketball_tier_cost_cap": "Micro Basketball Challenge: the most baskets a single tier can cost (escalation caps here).",
	"basketball_keepalive_seconds_per_point": "Micro Basketball Challenge: keep-alive seconds each sunk basket adds to the run clock.",
	"memory_tier_base_cost": "Memory Match Challenge: climbs each tier costs for tiers 1-5 (the escalating cost's base). At 0.2, tier 5 ≈ 1 climb.",
	"memory_tier_cost_increment": "Memory Match Challenge: climbs added to each tier's cost every 5 tiers (escalating cost climbs).",
	"memory_tier_cost_cap": "Memory Match Challenge: the most climbs a single tier can cost (escalation caps here).",
	"memory_keepalive_seconds_per_point": "Memory Match Challenge: keep-alive seconds each completed climb adds to the run clock.",
	"match3_keepalive_seconds_per_point": "Match Three Challenge: keep-alive seconds each point adds to the run clock (points arrive in bulk, so small).",
	"timing_keepalive_seconds_per_point": "Timing Bar Challenge: keep-alive seconds each successful lock adds to the run clock.",
	"catch_keepalive_seconds_per_point": "Catch the Money Challenge: keep-alive seconds each caught coin adds to the run clock.",
	"balance_seconds_per_point": "Balance the Books Challenge: in-zone seconds to earn one point (score = time-in-zone / this).",
	"balance_keepalive_seconds_per_point": "Balance the Books Challenge: keep-alive seconds each point adds to the run clock.",
	"balance_zone_reroll_seconds": "Balance the Books Challenge: seconds between the gold zone re-rolling a new target center.",
	"balance_zone_ease": "Balance the Books Challenge: how fast the gold zone eases toward its target center, per second.",
	"crash_multiplier": "Income multiplier during a Market Crash event.",
	"crash_duration_base_minutes": "Market Crash base length for Gen 1 (active minutes).",
	"crash_duration_growth_per_gen": "Market Crash duration increase per generation (+min/gen).",
	"crash_duration_max_minutes": "Market Crash maximum duration cap (active minutes).",
	"crash_duration_minutes": "Market Crash fallback length (active minutes).",
	"audit_settle_rate": "Audit settlement cost as a fraction of net worth.",
	"audit_threshold": "Legislative Assets needed to void an audit.",
	"windfall_net_worth_fraction": "The Windfall: fraction of net worth granted as cash.",
	"event_roll_interval_seconds": "Rare Events: seconds between random roll checks.",
	"event_base_chance": "Rare Events: base probability on each roll interval (0..1).",
	"event_grace_period_seconds": "Rare Events: grace period at generation start before events fire.",
	"earth_economy_target": "Total money on Earth; capture it to win ($).",
	"autosave_cadence": "Seconds between autosaves.",
	"audio_rush_harmony_interval_seconds": "Rush Audio: seconds between harmonic chord changes (2-4s).",
}


## Display-name overrides for constants whose variable name doesn't read well through
## plain capitalize() (Tim, 2026-07-07): dev jargon ("M1", the "K" coefficient) and
## abbreviations get intuitive names here. Everything else falls back to capitalize().
## Keyed by the exact variable name, like DESCRIPTIONS.
const DISPLAY_NAMES := {
	"audio_rush_harmony_interval_seconds": "Rush Harmony Interval /s",
	"m1_starting_cash": "Starting Cash",
	"rush_pct": "Rush Percent",
	"rush_momentum_heat_build_per_second": "Heat Build /s",
	"rush_momentum_heat_build_hot_per_second": "Hot Heat Build /s",
	"rush_momentum_heat_bleed_per_second": "Heat Bleed /s",
	"rush_momentum_hard_ceiling": "Hard Ceiling",
	"rush_momentum_bonus_at_hot": "Bonus At Hot",
	"rush_momentum_bonus_peak": "Bonus Peak",
	"rush_momentum_locked_drain_per_second": "Overheat Drain /s",
	"rush_momentum_rearm_seconds": "Re-arm Seconds",
	"rush_momentum_grace_seconds": "Momentum Grace Sec",
	"rush_momentum_vent_rate_at_cruise": "Vent Rate At Cruise",
	"rush_momentum_vent_rate_at_ceiling": "Vent Rate At Ceiling",
	"rush_momentum_vent_refractory_min": "Vent Quiet Min",
	"rush_momentum_vent_refractory_max": "Vent Quiet Max",
	"rush_momentum_vent_approach_seconds": "Vent Approach Sec",
	"rush_momentum_vent_window_duration": "Vent Window Sec",
	"rush_momentum_vent_duration_decay": "Vent Window Decay",
	"rush_momentum_vent_duration_floor": "Vent Window Floor",
	"rush_momentum_vent_gap_max": "Vent Gap Max",
	"rush_momentum_vent_tap_max": "Vent Tap Max",
	"rush_momentum_vent_heat_drop": "Vent Heat Drop",
	"rush_momentum_vent_bonus_step": "Vent Bonus Step",
	"rush_momentum_vent_lifts_step_tiers": "Vent Lift Step Tiers",
	"rush_momentum_vent_fail_rearm_per_tier": "Vent Fail Re-arm /Tier",
	"rush_momentum_vent_fail_rearm_cap": "Vent Fail Re-arm Cap",
	"rush_momentum_haptic_overheat_ms": "Overheat Haptic ms",
	"rush_momentum_haptic_ready_ms": "Ready Haptic ms",
	"rush_momentum_haptic_vent_ms": "Vent Haptic ms",
	"rush_momentum_haptic_vent_gap_ms": "Vent Haptic Gap ms",
	"k_legacy": "Legacy Payout Scale",
	"alpha_legacy": "Legacy Payout Curve",
	"legacy_upgrade_cost_multiplier": "Legacy Upgrade Cost x",
	"minigame_duration_seconds": "Minigame Timer Seconds",
	"minigame_keep_floor": "Minigame Downside Floor",
	"minigame_full_performance": "Minigame Neutral Point",
	"match3_full_score": "Match3 Full Score",
	"match3_max_score": "Match3 Max Score",
	"match3_legacy_match_size": "Match3 Legacy Match Size",
	"legacy_bonus_fraction": "Legacy Bonus Fraction",
	"legacy_bonus_max_gems": "Legacy Bonus Max Gems",
	"legacy_bonus_great_multiplier": "Legacy Bonus Great Multiplier",
	"legacy_bonus_great_threshold": "Legacy Bonus Great Threshold",
	"legacy_bonus_first_contact_multiplier": "Legacy Bonus First Contact Mult",
	"legacy_gem_chance_catch": "Legacy Gem Chance Catch",
	"legacy_gem_chance_timing": "Legacy Gem Chance Timing",
	"legacy_gem_chance_balance": "Legacy Gem Chance Balance",
	"legacy_gem_chance_basketball": "Legacy Gem Chance Basketball",
	"legacy_gem_chance_memory": "Legacy Gem Chance Memory",
	"memory_gem_sequence_length": "Memory Gem Sequence Length",
	"basketball_launch_curve_exp": "Basketball Launch Ease",
	"basketball_launch_max_drag": "Basketball Full-Power Drag",
	"basketball_max_throw_speed": "Basketball Max Speed",
}


## The tuning knobs are grouped into collapsible sections (Tim, 2026-07-09 — the flat list
## had grown too long to scan), the same pattern as the Estate Planning tab's upgrade
## categories. Each section owns a set of knobs matched by NAME PREFIX (a plain "starts-with"
## test), so adding a new knob to TuningConfig usually lands in the right section with no UI
## change. The order here is the order the sections appear. A knob is placed in the FIRST
## section whose prefix list matches it; anything unmatched falls into the catch-all section
## (CATCH_ALL_SECTION_TITLE) appended at the end. Each entry is { "title": String, "prefixes":
## Array[String] } — a prefix that is a full knob name (e.g. "logic_hz") matches only that knob.
const SECTIONS := [
	# Core Loop is the general "base economy" bucket. It also absorbs the input-repeat holds
	# (buy_hold_ / hire_hold_), the offline pacing (offline_), and the carbonation bubble visuals
	# (carb_) — each was its own header, but they are all facets of the core loop and its feedback,
	# so folding them here trims the panel from 14 section headers to 10 (Tim, 2026-07-22 — the
	# collapsed headers had grown to fill the whole tab).
	{"title": "Core Loop", "prefixes": [
		"logic_hz", "m1_starting_cash", "band_step", "cycle_floor", "rush_pct",
		"hold_rush_per_second", "earth_economy_target", "autosave_cadence",
		"buy_hold_", "hire_hold_", "offline_", "carb_",
	]},
	{"title": "Wage", "prefixes": ["wage_"]},
	# Audio needs its own entry or every audio_* knob lands in the catch-all section, which is
	# titled "Challenge Mode" and would be a confusing home for the tap-scale timing.
	{"title": "Audio", "prefixes": ["audio_"]},
	{"title": "Frenzy", "prefixes": ["frenzy_"]},
	{"title": "Rush Momentum", "prefixes": ["rush_momentum_"]},
	# Staff absorbs the retention pricing knobs (retention_*) — retention is just staff-level pricing.
	{"title": "Staff", "prefixes": ["staff_", "retention_"]},
	# NOTE: this section holds the non-challenge minigame knobs (physics / features) ONLY. The
	# per-game challenge dials — basketball_tier_*, the *_keepalive_seconds_per_point knobs, etc. —
	# belong to the "Challenge Mode" catch-all (Tim, 2026-07-22). So the basketball and match3 prefixes
	# are SPECIFIC (basketball_launch_, match3_full_score, …) rather than broad "basketball_" / "match3_",
	# which would otherwise scoop challenge knobs like basketball_keepalive_* / match3_keepalive_* back in.
	{"title": "Minigames", "prefixes": [
		"minigame_", "match3_full_score", "match3_max_score", "match3_legacy_match_size",
		"basketball_launch_", "basketball_max_", "memory_gem_",
	]},
	{"title": "Legacy Bonus", "prefixes": ["legacy_bonus_", "legacy_gem_chance_"]},
	{"title": "Estate & Legacy", "prefixes": ["estate_", "loophole_", "k_legacy", "alpha_legacy",
		"legacy_knee_net", "legacy_cost_steepening", "legacy_upgrade_cost_multiplier"]},
	{"title": "Events", "prefixes": ["crash_", "audit_", "windfall_", "event_"]},
]

## The catch-all section title for knobs no SECTIONS prefix matched (so a newly added knob always
## appears somewhere, even before it is sorted into a real section). It is titled "Challenge Mode"
## (Tim, 2026-07-22) because every knob that currently falls through is a Challenge Mode dial — the
## per-game tier costs (basketball_tier_*, memory_tier_*), the Balance challenge knobs (balance_*),
## and the shared challenge_* levers. If a future NON-challenge knob is ever added without a matching
## section, it would land here too; sort it into a real section (or add one) when that happens.
const CATCH_ALL_SECTION_TITLE := "Challenge Mode"

## Vertical breathing room (px) above the first section and below the last, between the scroll
## content and the scroll frame's edges (Tim, 2026-07-09 — the list felt cramped against the frame).
const SCROLL_VERTICAL_MARGIN := 24

## Width (px) permanently reserved at the right end of every section header for the
## "this section has modified values" asterisk (Tim, 2026-07-20). The space is reserved on
## EVERY header whether or not its asterisk is currently showing, so the header text never
## reflows when a value is overridden or reverted (project rule: no moving UI elements).
const SECTION_MARKER_WIDTH := 48
## Diameter of the "modified" dot on a section header. A drawn filled circle rather than a glyph
## (Tim, 2026-07-20: the gold asterisk was hard to read on the header background) — a solid white
## disc reads at arm's length regardless of the font's glyph coverage.
const SECTION_DOT_DIAMETER := 26

## Vertical travel (px) a touch/drag must cross before it counts as a SCROLL rather than a tap, so a
## drag that pans the list does not also toggle the section header it started on (Tim, 2026-07-22 — the
## collapsed headers tile the whole tab, leaving nowhere else to grab).
const DRAG_TOGGLE_THRESHOLD := 12.0


# One LineEdit per constant, keyed by constant name, read back on Apply.
var _value_edits: Dictionary = {}
# The constant's declared type (TYPE_INT / TYPE_FLOAT), keyed by name.
var _types: Dictionary = {}
# The baked default for each constant, keyed by name — Apply only stores values
# that differ from this, and rows that differ are flagged as overridden.
var _baked: Dictionary = {}
# Which collapsible section each constant was rendered into, keyed by constant name. Used to
# refresh only that section's "modified" asterisk when its value is edited.
var _section_of_knob: Dictionary = {}

var _list: VBoxContainer
# The scroll frame that holds the section list — kept so the drag-to-scroll handler can pan it.
var _scroll: ScrollContainer
# Drag-to-scroll state (Tim, 2026-07-22): the section headers are full-width buttons that tile the
# viewport when collapsed, so a touch landing on a header has nowhere neutral to grab. _pan_scroll_on_drag
# pans the list on any drag over a header or row; _drag_accum tracks the current gesture's travel and
# _drag_moved records once it has passed DRAG_TOGGLE_THRESHOLD, so that gesture's header tap is skipped.
var _drag_accum := 0.0
var _drag_moved := false
# Each collapsible section, keyed by its title → { "button": Button header, "body": VBoxContainer,
# "expanded": bool, "marker": Panel }. All sections start collapsed; the header-row arrow buttons
# drive them all. "marker" is the white dot shown when the section holds a modified value.
var _sections: Dictionary = {}
var _reset_dynasty_button: Button
# Two-tap guard on the destructive wipe: armed by the first tap, fires on the second.
var _reset_armed := false


## Build the static chrome once (header, scroll frame, footer buttons).
func setup() -> void:
	_build_chrome()


func _ready() -> void:
	# Hidden until the Settings tab's Balance Tuning button opens it; the tab's shared
	# cream panel provides all the framing.
	visible = false


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build_chrome() -> void:
	# The content column fills whatever slot hosts the panel (the Settings tab page).
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var title := Label.new()
	title.text = "Balance Tuning"
	title.add_theme_color_override("font_color", UiPalette.NAVY)
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	column.add_child(title)

	# Subtitle + the Collapse-All / Expand-All arrow buttons share one row: the subtitle expands
	# to take the slack and pushes the two icon buttons to the right edge (like the Estate tab).
	var subtitle_row := HBoxContainer.new()
	subtitle_row.add_theme_constant_override("separation", 10)
	column.add_child(subtitle_row)

	var subtitle := Label.new()
	subtitle.text = "Edit a value, then Apply & Reload. Gold = overridden."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # center against the taller buttons
	subtitle.add_theme_color_override("font_color", UiPalette.NAVY)
	subtitle.add_theme_font_size_override("font_size", SUBTITLE_SIZE)
	subtitle_row.add_child(subtitle)

	# Up arrow = collapse all (the list folds up); down arrow = expand all (it opens down) — the
	# same intuitive convention as the Estate tab. Icon-only so they stay narrow and right-aligned.
	var collapse_all_button := _make_bulk_button("res://art/icons/arrow_up.svg")
	collapse_all_button.pressed.connect(set_all_collapsed.bind(true))
	subtitle_row.add_child(collapse_all_button)

	var expand_all_button := _make_bulk_button("res://art/icons/arrow_down.svg")
	expand_all_button.pressed.connect(set_all_collapsed.bind(false))
	subtitle_row.add_child(expand_all_button)

	# ── Scrollable list of constant rows ──
	# The scroll wears the property ladder's full edge treatment (Tim, 2026-07-27 — one
	# "more content this way" vocabulary everywhere): tappable ScrollEdgeArrows strips
	# overlaid on a plain Control host, plus the visible-fraction edge fade on the rows
	# (see _update_edge_fade / ScrollEdgeArrows.apply_edge_fade).
	var scroll_host := Control.new()
	scroll_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll_host)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	scroll_host.add_child(scroll)
	var arrows := ScrollEdgeArrows.new()
	arrows.setup(scroll)
	scroll_host.add_child(arrows)
	scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _update_edge_fade())
	scroll.resized.connect(_update_edge_fade)
	_scroll = scroll  # kept for the drag-to-scroll handler (see _pan_scroll_on_drag)

	# Right margin keeps every row clear of the overlaid scrollbar (see SCROLLBAR_GAP); the
	# top/bottom margins give the section list breathing room off the scroll frame's edges.
	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_right", SCROLLBAR_GAP)
	list_margin.add_theme_constant_override("margin_top", SCROLL_VERTICAL_MARGIN)
	list_margin.add_theme_constant_override("margin_bottom", SCROLL_VERTICAL_MARGIN)
	list_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_margin)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_margin.add_child(_list)

	# ── Footer: two button rows ──
	var top_buttons := HBoxContainer.new()
	top_buttons.add_theme_constant_override("separation", 12)
	column.add_child(top_buttons)

	# Mustard (not red): Apply is the routine confirm, so red stays reserved for
	# the one truly destructive control below (the dynasty wipe).
	var apply_button := _make_button("APPLY & RELOAD", false)
	apply_button.pressed.connect(_on_apply_pressed)
	top_buttons.add_child(apply_button)

	var defaults_button := _make_button("RESET TO DEFAULTS", false)
	defaults_button.pressed.connect(_on_defaults_pressed)
	top_buttons.add_child(defaults_button)

	var bottom_buttons := HBoxContainer.new()
	bottom_buttons.add_theme_constant_override("separation", 12)
	column.add_child(bottom_buttons)

	# Red because it wipes the save — the one destructive action on this panel.
	_reset_dynasty_button = _make_button("RESET GAME", true)
	_reset_dynasty_button.pressed.connect(_on_reset_dynasty_pressed)
	bottom_buttons.add_child(_reset_dynasty_button)

	var close_button := _make_button("CLOSE", false)
	close_button.pressed.connect(_on_close_pressed)
	bottom_buttons.add_child(close_button)


## A footer button sized for thumbs (UI notes §1), expanding to share its row.
func _make_button(text: String, is_action: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 96)
	button.add_theme_font_size_override("font_size", BUTTON_SIZE)
	UiPalette.style_button(button, is_action)
	return button


# ---------------------------------------------------------------------------
# Collapsible sections (same pattern as the Estate Planning tab)
# ---------------------------------------------------------------------------

## Build one collapsible section into `_list`: a full-width header button that toggles a body
## VBoxContainer holding that section's rows. Every section starts COLLAPSED. Returns the body for
## the caller to fill with constant rows. All sections share the dev-tool blue plate, since these
## are developer groupings (not the color-coded player categories of the Estate tab).
func _add_collapsible_section(title: String) -> VBoxContainer:
	var header := Button.new()
	header.custom_minimum_size = Vector2(0, 62)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_size_override("font_size", ROW_LABEL_SIZE)
	# Caret + name read from the left like a typical section/disclosure header.
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_theme_stylebox_override("normal", _make_section_plate(UiPalette.CYCLE_BLUE))
	header.add_theme_stylebox_override("hover", _make_section_plate(UiPalette.CYCLE_BLUE))
	header.add_theme_stylebox_override("pressed", _make_section_plate(UiPalette.CYCLE_BLUE.darkened(0.15)))
	header.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		header.add_theme_color_override(state, UiPalette.CREAM)
	# A TAP toggles the section; a DRAG over the header pans the scroll list instead (the header would
	# otherwise be a dead zone for scrolling — see _pan_scroll_on_drag). button_down starts a fresh
	# gesture; pressed toggles ONLY if the gesture never crossed the drag threshold.
	header.button_down.connect(_begin_drag_gesture)
	header.gui_input.connect(_pan_scroll_on_drag)
	header.pressed.connect(_on_section_header_pressed.bind(title))
	_list.add_child(header)

	# The "section contains modified values" asterisk, overlaid on the header's right end rather
	# than appended to the header's text. Two reasons: the button's text is left-aligned, so an
	# appended "*" would sit next to the title instead of at the right edge; and an overlay
	# occupies no layout space, so showing or hiding it cannot move the header text. The matching
	# right-hand content margin in _make_section_plate keeps the title from ever running underneath.
	# A solid white disc, drawn as a Panel with a fully-rounded stylebox rather than a text glyph,
	# so it reads regardless of the header font's glyph set (Tim, 2026-07-20). Pinned to the
	# right-center of the header, vertically centered on a fixed diameter.
	var marker := Panel.new()
	var dot := StyleBoxFlat.new()
	dot.bg_color = Color.WHITE
	dot.set_corner_radius_all(SECTION_DOT_DIAMETER / 2)
	marker.add_theme_stylebox_override("panel", dot)
	marker.anchor_left = 1.0
	marker.anchor_right = 1.0
	marker.anchor_top = 0.5
	marker.anchor_bottom = 0.5
	marker.offset_left = -SECTION_DOT_DIAMETER - 12
	marker.offset_right = -12
	marker.offset_top = -SECTION_DOT_DIAMETER / 2.0
	marker.offset_bottom = SECTION_DOT_DIAMETER / 2.0
	# Let taps fall through to the header button underneath, or the dot would eat the
	# right end of the header's tap target.
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.visible = false
	header.add_child(marker)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.visible = false   # collapsed by default
	_list.add_child(body)

	_sections[title] = {"button": header, "body": body, "expanded": false, "marker": marker}
	_update_section_header(title)
	return body


## The Playtest "jump ahead" section: teleport to any epoch, grant Legacy, or grant spending cash —
## so the mid/late game and a prestiged heir can be sampled in seconds instead of the hours a real
## run takes (Tim 2026-07-13). Each button just emits a signal; Main applies it to the live game,
## saves, and reloads. Starts EXPANDED, since it is the reason a tester opens this panel.
func _add_playtest_section() -> void:
	var title := "Playtest — jump ahead"
	var body := _add_collapsible_section(title)

	body.add_child(_playtest_label("Jump to epoch (teleport + entry cash):"))
	# A FLOW container, not an HBox: with the full 26-epoch ladder, one row of E1..E26
	# buttons is far wider than the panel and would push everything off the right edge
	# (an HBox never wraps). The flow lays the buttons left-to-right and wraps to a new
	# line when the panel width runs out.
	var epoch_row := HFlowContainer.new()
	epoch_row.add_theme_constant_override("h_separation", 8)
	epoch_row.add_theme_constant_override("v_separation", 8)
	for tier in range(1, EpochCatalog.tier_count() + 1):
		var t := tier
		var eb := _playtest_button("E%d" % t)
		# Fixed width instead of expand-to-fill: expanding buttons in a flow container
		# stretch a partly-filled last line to giant widths, so the grid would look ragged.
		eb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		eb.custom_minimum_size = Vector2(118, 84)
		eb.pressed.connect(func() -> void: jump_epoch_requested.emit(t))
		epoch_row.add_child(eb)
	body.add_child(epoch_row)

	body.add_child(_playtest_label("Grant Legacy (to spend in the Estate Office):"))
	var legacy_row := HBoxContainer.new()
	legacy_row.add_theme_constant_override("separation", 8)
	for pair in [["+1K", 1000], ["+100K", 100_000], ["+10M", 10_000_000]]:
		var amount := int(pair[1])
		var lb := _playtest_button(String(pair[0]))
		lb.pressed.connect(func() -> void: grant_legacy_requested.emit(amount))
		legacy_row.add_child(lb)
	body.add_child(legacy_row)

	body.add_child(_playtest_label("Grant spending cash (× this epoch's clear target):"))
	var cash_row := HBoxContainer.new()
	cash_row.add_theme_constant_override("separation", 8)
	for mult in [1.0, 10.0, 100.0]:
		var m: float = mult
		var cb := _playtest_button("x%d" % int(m))
		cb.pressed.connect(func() -> void: grant_cash_requested.emit(m))
		cash_row.add_child(cb)
	body.add_child(cash_row)

	body.add_child(_playtest_label("Rare Events (trigger on demand):"))
	var event_row := HFlowContainer.new()
	event_row.add_theme_constant_override("h_separation", 8)
	event_row.add_theme_constant_override("v_separation", 8)

	var btn_crash := _playtest_button("CRASH")
	btn_crash.pressed.connect(func() -> void: trigger_crash_requested.emit())
	event_row.add_child(btn_crash)

	var btn_audit := _playtest_button("AUDIT")
	btn_audit.pressed.connect(func() -> void: trigger_audit_requested.emit())
	event_row.add_child(btn_audit)

	var btn_windfall := _playtest_button("WINDFALL")
	btn_windfall.pressed.connect(func() -> void: trigger_windfall_requested.emit())
	event_row.add_child(btn_windfall)

	var btn_clear := _playtest_button("CLEAR ALL")
	btn_clear.pressed.connect(func() -> void: clear_events_requested.emit())
	event_row.add_child(btn_clear)
	body.add_child(event_row)

	body.add_child(_playtest_label("Diagnostics & Crash Trace Log:"))
	var trace_row := HBoxContainer.new()
	trace_row.add_theme_constant_override("separation", 8)
	var tb := _playtest_button("PRINT LAST RUN LOG")
	tb.pressed.connect(_show_trace_modal)
	trace_row.add_child(tb)
	body.add_child(trace_row)

	_toggle_section(title)  # open it by default


## Display an on-screen scrollable modal overlay with the last session's action trace log.
func _show_trace_modal() -> void:
	var trace_text := ActionTracer.get_last_run_trace()
	print("=== LAST RUN ACTION TRACE LOG ===")
	print(trace_text)
	print("=================================")

	var existing := get_node_or_null("TraceLogModal")
	if existing != null:
		existing.queue_free()

	var modal := PanelContainer.new()
	modal.name = "TraceLogModal"
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.process_mode = Node.PROCESS_MODE_ALWAYS
	modal.z_index = 100

	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.CREAM
	style.set_content_margin_all(24)
	modal.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "Last Session Action Trace Log"
	title_lbl.add_theme_color_override("font_color", UiPalette.NAVY)
	title_lbl.add_theme_font_size_override("font_size", TITLE_SIZE)
	vbox.add_child(title_lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var content := Label.new()
	content.text = trace_text
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_color_override("font_color", UiPalette.INK_NAVY)
	content.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	scroll.add_child(content)

	var close_btn := _make_button("CLOSE LOG", true)
	close_btn.pressed.connect(func() -> void: modal.queue_free())
	vbox.add_child(close_btn)

	add_child(modal)


## A wide button for the Playtest section, sharing its row evenly with its siblings.
func _playtest_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 84)
	button.add_theme_font_size_override("font_size", BUTTON_SIZE)
	UiPalette.style_button(button, false)
	return button


## A caption line above a Playtest button row.
func _playtest_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	label.add_theme_color_override("font_color", UiPalette.INK_NAVY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


## A blue plate (dev-tool CYCLE_BLUE fill, navy border) for a section header button — the same
## plate shape as the Estate tab's section headers, but one shared color for the whole panel.
func _make_section_plate(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = UiPalette.NAVY
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	# Keep the header's own text clear of the asterisk's reserved column at the right end,
	# so a long section title wraps/clips before it can collide with the marker.
	style.set_content_margin(SIDE_RIGHT, SECTION_MARKER_WIDTH)
	return style


## A compact icon utility button (Collapse All / Expand All — an arrow glyph), styled as a
## standard (non-spend) button. Icon-only, so it stays narrow; expand_icon scales the arrow to fill.
func _make_bulk_button(icon_path: String) -> Button:
	var button := Button.new()
	button.icon = load(icon_path)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(84, 62)
	button.add_theme_constant_override("icon_max_width", 48)
	UiPalette.style_button(button, false)
	return button


## Flip one section between expanded and collapsed (its header was tapped).
func _toggle_section(title: String) -> void:
	var section: Dictionary = _sections[title]
	section["expanded"] = not bool(section["expanded"])
	(section["body"] as Control).visible = bool(section["expanded"])
	_update_section_header(title)
	# The list just re-laid-out (a body appeared or vanished) — refresh the edge fade once
	# the new layout has settled (deferred: sizes are stale until the next layout pass).
	_update_edge_fade.call_deferred()


## The shared property-ladder edge treatment (ScrollEdgeArrows.apply_edge_fade), fading
## whatever the scroll is clipping at either edge. Items are collected fresh each call —
## the section headers plus, for every EXPANDED section, its individual rows — so a tall
## open body fades row by row like the ladder rather than dimming as one giant block.
func _update_edge_fade() -> void:
	if _scroll == null or _list == null:
		return
	var items: Array = []
	for child in _list.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		if control is VBoxContainer:
			items.append_array((control as VBoxContainer).get_children())
		else:
			items.append(control)
	ScrollEdgeArrows.apply_edge_fade(_scroll, items)


# ---------------------------------------------------------------------------
# Drag-to-scroll (Tim, 2026-07-22)
# ---------------------------------------------------------------------------
# The section headers are full-width buttons, so when they are all collapsed they tile the whole tab and
# a touch that lands on one has nowhere neutral to grab — the list can't be scrolled. Rather than fight
# Godot's mouse_filter propagation (a header's STOP swallows the touch before the ScrollContainer sees
# it), we pan the scroll ourselves from a drag over any header or row, the same tactic Main.gd uses for
# the epoch-swipe gesture. A short press still registers as a tap (toggles the section); once a gesture's
# travel passes DRAG_TOGGLE_THRESHOLD it is treated as a scroll and that header's tap is suppressed.

## Start tracking a fresh press gesture (a header's button_down, before any drag).
func _begin_drag_gesture() -> void:
	_drag_accum = 0.0
	_drag_moved = false


## Pan the scroll list when a touch/left-drag crosses a header or row. Never consumes the event, so the
## button's own tap and any text field still work. Accumulates travel so _on_section_header_pressed can
## tell a scroll from a tap. Handles both touch (InputEventScreenDrag) and desktop mouse-drag.
func _pan_scroll_on_drag(event: InputEvent) -> void:
	var delta_y := 0.0
	if event is InputEventScreenDrag:
		delta_y = event.relative.y
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		# Desktop only. Godot's emulate_mouse_from_touch (on by default) synthesises a mouse motion
		# for EVERY InputEventScreenDrag, so on a phone this branch fired alongside the one above:
		# the list panned at twice the speed of the finger and _drag_accum hit the 12px threshold
		# after ~6px of real travel, making a tap read as a scroll far too easily.
		if OS.has_feature("mobile"):
			return
		delta_y = event.relative.y
	else:
		return
	# Drag DOWN (finger moves down, delta_y > 0) reveals earlier rows → scroll_vertical decreases.
	_scroll.scroll_vertical -= int(delta_y)
	_drag_accum += absf(delta_y)
	if _drag_accum >= DRAG_TOGGLE_THRESHOLD:
		_drag_moved = true


## A header was released: toggle it ONLY when the gesture was a genuine tap. If the press turned into a
## scroll (travel past the threshold), swallow the toggle so scrolling never flips sections open/closed.
func _on_section_header_pressed(title: String) -> void:
	if _drag_moved:
		return
	_toggle_section(title)


## Expand or collapse every section at once (the header-row Collapse-All / Expand-All arrows).
func set_all_collapsed(collapsed: bool) -> void:
	for title in _sections:
		var section: Dictionary = _sections[title]
		section["expanded"] = not collapsed
		(section["body"] as Control).visible = not collapsed
		_update_section_header(String(title))
	_update_edge_fade.call_deferred()  # every body just appeared/vanished — re-fade post-layout


## Refresh a section header's caret + name to match its expanded state. "+" invites a tap to open a
## collapsed section; "-" shows it is already open.
func _update_section_header(title: String) -> void:
	var section: Dictionary = _sections[title]
	var marker := "-" if bool(section["expanded"]) else "+"
	(section["button"] as Button).text = "%s  %s" % [marker, title.to_upper()]


## True when this constant's editor currently holds a value that differs from its baked default —
## i.e. it is a live override. This deliberately reads the LineEdit rather than the value the row
## was seeded with, so the flag tracks what the user has typed, not just what was loaded from
## user://tuning_overrides.json. The parse matches _on_apply_pressed exactly (same int rounding),
## so "modified" always means "Apply would write an override for this knob".
##
## A half-typed entry ("", "-", "0.") is not a number yet, so it counts as NOT modified — the same
## way Apply skips it. That keeps the asterisk from flickering on every keystroke mid-edit.
func _is_knob_modified(name: String) -> bool:
	if not _value_edits.has(name):
		return false
	var text: String = (_value_edits[name] as LineEdit).text.strip_edges()
	if not text.is_valid_float():
		return false
	var value: Variant
	if _types[name] == TYPE_INT:
		value = int(round(text.to_float()))
	else:
		value = text.to_float()
	return value != _baked[name]


## Show or hide one section's white "modified" dot to match whether any knob in it is modified.
func _refresh_section_marker(title: String) -> void:
	if not _sections.has(title):
		return
	var any_modified := false
	for name in _section_of_knob:
		if String(_section_of_knob[name]) == title and _is_knob_modified(String(name)):
			any_modified = true
			break
	var section: Dictionary = _sections[title]
	(section["marker"] as Panel).visible = any_modified


## Re-evaluate every section's asterisk (used once the rows are built).
func _refresh_all_section_markers() -> void:
	for title in _sections:
		_refresh_section_marker(String(title))


# ---------------------------------------------------------------------------
# Showing / populating
# ---------------------------------------------------------------------------

## (Re)build the constant rows and show the panel. `effective_tuning` is the live
## config (baked defaults with any overrides already applied) whose values seed the
## editors; `baked_tuning` is a pristine baked copy used to tell which constants are
## currently overridden and, on Apply, which edited values to store.
func open(effective_tuning: TuningConfig, baked_tuning: TuningConfig) -> void:
	_disarm_reset()
	_value_edits.clear()
	_types.clear()
	_baked.clear()
	_sections.clear()
	_section_of_knob.clear()
	for child in _list.get_children():
		child.queue_free()

	# Playtest jump tools first, above the tuning-knob sections (Tim 2026-07-13).
	_add_playtest_section()

	# Reflection: every exported int/float on TuningConfig, in declaration order (so related
	# constants stay grouped exactly as they read in the source file). We first sort each knob
	# into its section by name prefix, then render section by section — so a section's rows share
	# their source order, and the sections themselves appear in the fixed SECTIONS order.
	var knobs_by_section: Dictionary = {}   # section title → Array of [name, type] pairs
	for prop in effective_tuning.get_property_list():
		var usage: int = prop["usage"]
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var type: int = prop["type"]
		if type != TYPE_INT and type != TYPE_FLOAT:
			continue
		var name: String = prop["name"]
		var section_title := _section_title_for(name)
		if not knobs_by_section.has(section_title):
			knobs_by_section[section_title] = []
		knobs_by_section[section_title].append([name, type])

	# Render the sections in the fixed SECTIONS order, then the catch-all ("Challenge Mode") last. Only
	# a section that actually owns at least one knob gets a header (empty sections are skipped).
	var ordered_titles: Array = []
	for section in SECTIONS:
		ordered_titles.append(String(section["title"]))
	ordered_titles.append(CATCH_ALL_SECTION_TITLE)

	for title in ordered_titles:
		if not knobs_by_section.has(title):
			continue
		var body := _add_collapsible_section(String(title))
		for pair in knobs_by_section[title]:
			var name: String = pair[0]
			var type: int = pair[1]
			_section_of_knob[name] = String(title)
			_add_constant_row(body, name, type, effective_tuning.get(name), baked_tuning.get(name))

	# Sections start collapsed, so the asterisks are the only way to see which ones hold overrides.
	_refresh_all_section_markers()

	visible = true
	_update_edge_fade.call_deferred()  # rows just rebuilt — fade once they have laid out


## The title of the section a knob belongs to: the first SECTIONS entry with a prefix the knob
## name starts with, or the catch-all ("Challenge Mode") when nothing matches. A prefix that is a
## full knob name simply matches only that knob.
func _section_title_for(name: String) -> String:
	for section in SECTIONS:
		for prefix in section["prefixes"]:
			if name.begins_with(String(prefix)):
				return String(section["title"])
	return CATCH_ALL_SECTION_TITLE


## One constant row, added to `parent` (its collapsible section's body): the name and a concise
## description stacked on the left, an editable value on the right. A row whose current value
## differs from the baked default is tinted gold and marked, so an active override is obvious at a
## glance. Every row's LineEdit is still registered in _value_edits, so Apply reads it back
## unchanged whichever section it lives in.
func _add_constant_row(parent: VBoxContainer, name: String, type: int, current_value: Variant, baked_value: Variant) -> void:
	_types[name] = type
	_baked[name] = baked_value
	var is_overridden: bool = current_value != baked_value

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	# A drag over the row's TEXT area (not the value field) pans the scroll list, so an expanded
	# section is scrollable too (Tim, 2026-07-22). The row keeps STOP and receives the drag because its
	# text column + labels are set IGNORE below; the LineEdit stays interactive for editing.
	row.gui_input.connect(_pan_scroll_on_drag)
	parent.add_child(row)

	# Name (top) + description (beneath) share the left column; the editor sits to
	# their right, vertically centered against the stacked text.
	var text_column := VBoxContainer.new()
	text_column.add_theme_constant_override("separation", 2)
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Transparent to input so a drag falls through to the row (which pans the scroll); the labels
	# below are IGNORE for the same reason. Only the LineEdit stays interactive.
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_column)

	var label := Label.new()
	# Plain-language name: capitalize() turns the constant's snake_case into spaced
	# Pascal Case ("wage_hold_taps_per_second" → "Wage Hold Taps Per Second"), so the
	# list reads like settings, not source code (Tim, 2026-07-06); a few jargon-y names
	# get hand-picked replacements instead (DISPLAY_NAMES). The exact variable name
	# still keys everything internally (edits, overrides, descriptions).
	var display_name: String = DISPLAY_NAMES.get(name, name.capitalize())
	label.text = ("● " if is_overridden else "") + display_name
	label.add_theme_color_override(
		"font_color", UiPalette.MUSTARD_GOLD if is_overridden else UiPalette.NAVY)
	label.add_theme_font_size_override("font_size", ROW_LABEL_SIZE)
	# Wrap a long name instead of forcing the whole row wider than the panel (Tim, 2026-07-09).
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # let a drag fall through to the row (scroll)
	text_column.add_child(label)

	var description: String = DESCRIPTIONS.get(name, "")
	if description != "":
		var desc_label := Label.new()
		desc_label.text = description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Muted navy so the description reads as secondary to the constant's name.
		desc_label.add_theme_color_override("font_color", Color(UiPalette.NAVY, 0.7))
		desc_label.add_theme_font_size_override("font_size", ROW_DESC_SIZE)
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # let a drag fall through to the row (scroll)
		text_column.add_child(desc_label)

	var edit := LineEdit.new()
	edit.text = _format_value(current_value)
	edit.custom_minimum_size = Vector2(VALUE_COLUMN_WIDTH, VALUE_HEIGHT)
	# LEFT-aligned, not right (Tim, 2026-07-20 — "it is not operating like a standard text
	# editing field"). With right alignment, tapping near the end of the value put the caret on
	# the wrong character, so backspace deleted the wrong one: Godot's LineEdit maps a tap to a
	# caret column through the text's own left-to-right layout, and the extra offset that pushes
	# right-aligned text over is not accounted for in that hit test. Left alignment removes the
	# offset entirely, which is what makes the field behave like every other text box.
	edit.alignment = HORIZONTAL_ALIGNMENT_LEFT
	edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	edit.add_theme_font_size_override("font_size", ROW_VALUE_SIZE)
	# The STANDARD phone keyboard, not the numeric keypad: the values are numbers, but
	# the numeric keypad has no arrow keys, which made moving the caret inside a long
	# value nearly impossible (Tim, 2026-07-06).
	edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	# Nothing rewrites the text WHILE typing — assigning to LineEdit.text resets the caret to the
	# start, which would fight every keystroke. The value is parsed and tidied only on COMMIT
	# (Enter or leaving the field); see _normalize_value_text.
	edit.text_submitted.connect(func(_submitted: String) -> void: _normalize_value_text(name))
	edit.focus_exited.connect(func() -> void: _normalize_value_text(name))
	# Read-only: keeps the section asterisk live as the user types, without touching the text.
	edit.text_changed.connect(func(_new_text: String) -> void: _on_value_text_changed(name))
	row.add_child(edit)

	_value_edits[name] = edit


## Compact string for a constant's value. Godot's str() already renders these
## cleanly (0.005, 1.15, 103600000000000), so no custom formatting is needed.
func _format_value(value: Variant) -> String:
	return str(value)


## A value editor changed. This only READS the field — it never writes to it, because assigning to
## LineEdit.text moves the caret and would break normal typing. All it does is keep the owning
## section's "modified" asterisk in step with what is currently in the box.
func _on_value_text_changed(name: String) -> void:
	if _section_of_knob.has(name):
		_refresh_section_marker(String(_section_of_knob[name]))


## Tidy one value editor on COMMIT — when Enter is pressed or focus leaves the field, never while
## the user is still typing. This is where stray whitespace (the phone keyboard's autocorrect likes
## to add a trailing space) and odd-but-valid spellings like "1." or "1e3" get rendered back in the
## panel's normal form, so the field ends up showing exactly the number Apply will store.
##
## A half-finished entry is left completely alone: if the text is not a number yet ("", "-", "0."),
## or is already in normal form, nothing is assigned. That matters because assigning to .text resets
## the caret, so the rule is to write only when the text genuinely has to change.
func _normalize_value_text(name: String) -> void:
	if not _value_edits.has(name):
		return
	var edit: LineEdit = _value_edits[name]
	var text: String = edit.text.strip_edges()
	if not text.is_valid_float():
		return   # mid-edit or nonsense — leave it as typed; Apply already skips it
	var value: Variant
	if _types[name] == TYPE_INT:
		value = int(round(text.to_float()))
	else:
		value = text.to_float()
	var normalized := _format_value(value)
	if edit.text != normalized:
		edit.text = normalized
		# The assignment above sent the caret to column 0; park it at the end, which is where a
		# text field normally leaves it after a committed edit.
		edit.caret_column = normalized.length()
	_on_value_text_changed(name)


# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------

## Collect every edited value, keep only the ones that differ from the baked
## default, and hand them to Main to persist + reload. Invalid (non-numeric) entries
## are skipped, so they simply revert to the baked value on reload.
func _on_apply_pressed() -> void:
	var overrides: Dictionary = {}
	for name in _value_edits.keys():
		var text: String = (_value_edits[name] as LineEdit).text.strip_edges()
		if not text.is_valid_float():
			push_warning("DevTuningPanel: '%s' = '%s' is not a number, skipping" % [name, text])
			continue
		var value: Variant
		if _types[name] == TYPE_INT:
			value = int(round(text.to_float()))
		else:
			value = text.to_float()
		# Store only genuine changes — typing the default back removes the override.
		if value != _baked[name]:
			overrides[name] = value
	visible = false
	apply_requested.emit(overrides)


func _on_defaults_pressed() -> void:
	visible = false
	defaults_requested.emit()


## First tap arms the wipe (turns the button into a confirm); second tap fires it.
## Any other exit (Close) disarms it again — see _disarm_reset.
func _on_reset_dynasty_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_dynasty_button.text = "TAP AGAIN TO WIPE"
		return
	visible = false
	reset_dynasty_requested.emit()


func _on_close_pressed() -> void:
	_disarm_reset()
	visible = false
	closed.emit()


func _disarm_reset() -> void:
	_reset_armed = false
	if _reset_dynasty_button != null:
		_reset_dynasty_button.text = "RESET GAME"
