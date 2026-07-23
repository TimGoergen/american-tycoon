class_name TutorialCatalog

# The copy for every one-time tutorial tip, in one editable place (Plans/Tutorial_Onboarding_Plan.md).
# Each entry teaches ONE system the first time it becomes relevant. Keyed by a stable tip id that
# TutorialProgress uses to remember "already seen" and that Main fires from the matching verb.
#
# Voice: clarity first (the player must understand the mechanic), with a light wry capitalist tilt
# (GDD §1.2). First-draft copy by Claude (2026-07-23) — Tim to tweak. Ids never start with "_"
# (that prefix is reserved for TutorialProgress's own flags).
#
# A few of these (epochs / prestige / welcome_back) are ALSO woven into the existing full-screen
# beats rather than shown as a floating card; their copy still lives here so it stays in one place
# and can feed the Settings glossary.

const TIPS := {
	"first_property": {
		"title": "Your first venture",
		"body": "It runs a cycle, then pays out. Tap it to collect and kick off the next one.",
	},
	"first_rush": {
		"title": "Rush it",
		"body": "Press and hold a business to RUSH — its cycles finish faster for a burst of income. Your thumb is the engine.",
	},
	"first_milestone": {
		"title": "Milestone bonus",
		"body": "Every 25, 50, 100… units you own of a business doubles its income. Nice round numbers pay.",
	},
	"buy_mode": {
		"title": "Buy in bulk",
		"body": "Switch between ×1, ×10, NEXT (exactly up to the next milestone), and MAX to buy more at once.",
	},
	"turbo_ready": {
		"title": "TURBO is charged",
		"body": "Tap TURBO to burn the meter for a temporary income multiplier across every business at once.",
	},
	"vent_window": {
		"title": "Vent the overdrive",
		"body": "When the vent window opens, lift and re-press on the beat to bleed off heat — or Rush Momentum overheats and shuts the rush down.",
	},
	"first_hire": {
		"title": "Hire a manager",
		"body": "A staffer runs this business hands-free — it keeps earning even while the app is closed.",
	},
	"epochs": {
		"title": "First contact",
		"body": "You've earned an entire economy. A new civilization opens a market — and a new tier of staff — orders of magnitude larger.",
	},
	"prestige": {
		"title": "The estate lives on",
		"body": "When a tycoon dies, a lifetime of earnings becomes Legacy. Spend it in the Estate Office on permanent upgrades your heirs inherit.",
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
