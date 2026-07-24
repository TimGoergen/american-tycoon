class_name TutorialCatalog

# The copy for every one-time tutorial tip, in one editable place (Plans/Tutorial_Onboarding_Plan.md).
# Each entry teaches ONE system the first time it becomes relevant. Keyed by a stable tip id that
# TutorialProgress uses to remember "already seen" and that Main fires from the matching verb.
#
# Voice: clarity first (the player must understand the mechanic), with a light wry capitalist tilt
# (GDD §1.2). First-draft copy by Claude (2026-07-23) — Tim to tweak. Ids never start with "_"
# (that prefix is reserved for TutorialProgress's own flags).
#
# A few concepts are taught in their own beat rather than as a floating card, so their entry here
# feeds the Settings glossary but is NOT fired by _maybe_show_tip: welcome_back is a permanent line
# ON the welcome-back screen (WelcomeBackOverlay), and minigames is the Get Ready gate's own stakes
# line (MinigameScreen — "Play well to earn a BONUS…", exactly where the player is about to play,
# so a game-screen card afterward was redundant; Tim, 2026-07-23).

const TIPS := {
	# The very first beat: on a fresh launch the only thing to do is Clock In until the first
	# business is affordable, so this points at the wage button before anything else fires.
	"getting_started": {
		"title": "Clock in for cash",
		"body": "Tap CLOCK IN to earn a wage. Bank enough and you can buy your first business.",
	},
	"first_property": {
		"title": "Buy your first business",
		"body": "You've banked enough! Tap a business's price to buy it — it runs a cycle, then pays out.",
	},
	"first_rush": {
		"title": "Rush for a boost",
		"body": "Press and hold a business to RUSH it — its cycles finish faster for a burst of income. Your thumb is the engine.",
	},
	"first_milestone": {
		"title": "Milestone bonus",
		"body": "Every 25, 50, 100… units you own of a business doubles its income. Nice round numbers pay.",
	},
	"buy_mode": {
		"title": "Buy in bulk",
		"body": "Switch between ×1, ×10, NEXT (exactly up to the next milestone), and MAX to buy several at once.",
	},
	"turbo_ready": {
		"title": "TURBO is charged",
		"body": "Tap TURBO to burn the meter for a temporary income multiplier across every business at once.",
	},
	"overdrive": {
		"title": "Push into Overdrive",
		"body": "You've reached cruise — safe and steady. Tap OVR to push past it for escalating bonuses. Careful: overdrive runs hot and always ends in an overheat.",
	},
	"vent_window": {
		"title": "Vent the overdrive",
		"body": "When the vent window opens, lift and re-press on the beat to bleed off heat — or Rush Momentum overheats and shuts the rush down.",
	},
	"first_hire": {
		"title": "Hire a manager",
		"body": "You can afford a manager now — hire one and this business runs itself, even while the app is closed.",
	},
	"epochs": {
		"title": "First contact",
		"body": "You've earned an entire economy. A new civilization opens a market — and a new tier of staff — orders of magnitude larger.",
	},
	"epoch_blocked": {
		"title": "Own the whole era first",
		"body": "You've earned enough to reach the next civilization — but first you need at least one of every business in this era. Grab this one to keep climbing.",
	},
	"prestige": {
		"title": "Plan your estate",
		"body": "You've built enough to pass it on. Open the Estate tab to hand your fortune to an heir — it becomes Legacy to spend on permanent upgrades the whole dynasty keeps.",
	},
	"family_ledger": {
		"title": "Your family history",
		"body": "Every tycoon before you is recorded here — the fortune they built and how their run came to an end.",
	},
	"welcome_back": {
		"title": "While you were out",
		"body": "Your staffed businesses kept working. Here's the pile that stacked up since you last checked in.",
	},
	"staff_retention": {
		"title": "Keep your best people",
		"body": "In the Estate Office you can retain a staffer through death, so your heir doesn't have to hire them all over again.",
	},
	"minigames": {
		"title": "Play for a bonus",
		"body": "Do well here and the payout goes up. You never lose your base reward — this is only a chance to earn extra.",
	},
}


## The {title, body} for a tip id, or an empty Dictionary if the id is unknown.
static func get_tip(tip_id: String) -> Dictionary:
	return TIPS.get(tip_id, {})
