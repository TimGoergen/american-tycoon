class_name EventDef

# Event definitions and static catalog (GDD §9 / Mechanics Spec §10).
# Defines the schemas, constants, copy, and eligibility checks for Rare Events.

enum Type {
	WEATHER,   # Ongoing background modifier (Market Crash). Non-blocking.
	DILEMMA,   # Player choice with immediate financial stakes (The Audit).
	GRANT,     # One-time positive windfall (The Windfall).
}

const ID_CRASH := "market_crash"
const ID_AUDIT := "the_audit"
const ID_WINDFALL := "the_windfall"

const ALL_EVENTS: Array[String] = [
	ID_CRASH,
	ID_AUDIT,
	ID_WINDFALL,
]

## Check if an event is currently eligible to trigger for the given game state.
static func is_eligible(event_id: String, game: GameState) -> bool:
	if game == null or game.economy == null:
		return false
	match event_id:
		ID_CRASH:
			# Needs at least one owned property with positive income
			return game.economy.get_passive_income_per_sec() > 0.0 or game.peak_net_worth > 100.0
		ID_AUDIT:
			# Needs meaningful net worth / earnings so paying an audit is meaningful
			return game.peak_net_worth >= 5000.0 or game.economy.cash_earned_this_gen >= 5000.0
		ID_WINDFALL:
			# Available anytime after initial start
			return game.peak_net_worth > 0.0 or game.economy.cash > 0.0
		_:
			return false

## Get the event type.
static func get_type(event_id: String) -> Type:
	match event_id:
		ID_CRASH:
			return Type.WEATHER
		ID_AUDIT:
			return Type.DILEMMA
		ID_WINDFALL:
			return Type.GRANT
		_:
			return Type.WEATHER

## Get the headline title.
static func get_title(event_id: String) -> String:
	match event_id:
		ID_CRASH:
			return "MARKET CRASH"
		ID_AUDIT:
			return "THE AUDIT"
		ID_WINDFALL:
			return "THE WINDFALL"
		_:
			return "SPECIAL EVENT"

## Get the eyebrow / banner tag.
static func get_eyebrow(event_id: String) -> String:
	match event_id:
		ID_CRASH:
			return "◄  FINANCIAL HEADLINE  ►"
		ID_AUDIT:
			return "◄  INTERNAL REVENUE SERVICE  ►"
		ID_WINDFALL:
			return "◄  LEGAL NOTICE  ►"
		_:
			return "◄  NOTICE  ►"

## Get the body copy / explanation.
static func get_description(event_id: String) -> String:
	match event_id:
		ID_CRASH:
			return "Wall Street is in panic! Property capital returns are cut in half for the duration. Honest wage labor remains completely unaffected."
		ID_AUDIT:
			return "Federal examiners are reviewing your past tax filings and corporate deductions. You must choose how to respond to the inquiry."
		ID_WINDFALL:
			return "A distant relative you have never heard of has passed away in Palm Beach, naming your dynasty as the sole beneficiary."
		_:
			return ""

## Get the narrator's satirical commentary (GDD §9).
static func get_narrator_quote(event_id: String) -> String:
	match event_id:
		ID_CRASH:
			return "“See? Honest elbow grease is 100% crash-proof. It just doesn't buy the country club membership.”"
		ID_AUDIT:
			return "“The loophole tree only has teeth if you forgot to cultivate your friends in Washington.”"
		ID_WINDFALL:
			return "“Nothing honors the American work ethic quite like unearned generational capital arriving in the mail.”"
		_:
			return ""
