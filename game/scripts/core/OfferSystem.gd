class_name OfferSystem

# Ongoing credit — the offers system (GDD §8.6, Mechanics Spec §8). Headless, one
# per generation. Credit comes TO you: a take-it-or-leave-it offer arrives as mail,
# and the terms improve as you need them less (payday → subprime → prime → bailout),
# because the eligible tier is chosen by the net-worth band you currently sit in.
#
# Cadence: an offer is rolled at generation start and again each time the player is
# promoted into a higher net-worth band (a new tier becomes eligible). There is
# never more than one pending offer, and none is rolled while a loan is active
# (one loan at a time, §8.6). An ignored offer simply expires when the band changes
# — the game never nags (Principle 5).


# The loan-tier table in ascending eligibility order (LoanTier configs).
var _tiers: Array = []

## The offer awaiting the player's decision, or null if none is pending.
var current_offer: LoanTier = null

## The net-worth band index an offer was last rolled for, so we roll exactly once
## per band: -1 means "nothing rolled yet" (forces a roll at generation start).
var _offered_band: int = -1


func _init(tiers: Array = []) -> void:
	_tiers = tiers


## (Re)supply the tier table — used after load, when configs are injected.
func set_tiers(tiers: Array) -> void:
	_tiers = tiers


# ---------------------------------------------------------------------------
# Rolling offers
# ---------------------------------------------------------------------------

## Index of the tier eligible at `net_worth` (its band contains it), or -1 if none.
func _band_index_for(net_worth: float) -> int:
	for i in range(_tiers.size()):
		var tier := _tiers[i] as LoanTier
		if net_worth >= tier.eligibility_min_net_worth and net_worth < tier.eligibility_max_net_worth:
			return i
	return -1


## Called each tick. Rolls a fresh offer when the player enters a band we have not
## offered for yet — but only when there is no pending offer and no active loan.
## Returns true if a NEW offer was just rolled (so Main can flag fresh mail).
func update(net_worth: float, debt: DebtState) -> bool:
	if current_offer != null or debt.has_active_loan():
		return false

	var band := _band_index_for(net_worth)
	if band >= 0 and band != _offered_band:
		current_offer = _tiers[band] as LoanTier
		_offered_band = band
		return true
	return false


func has_offer() -> bool:
	return current_offer != null


# ---------------------------------------------------------------------------
# Responding to an offer
# ---------------------------------------------------------------------------

## Accept the pending offer: returns the LoanTier to install (the caller credits the
## principal and calls DebtState.take_loan), and clears the pending offer. Returns
## null if nothing is pending.
func accept() -> LoanTier:
	var taken := current_offer
	current_offer = null
	return taken


## Decline the pending offer: it expires silently (no nagging). The same band will
## not be re-offered; the next offer waits for a band promotion.
func decline() -> void:
	current_offer = null


# ---------------------------------------------------------------------------
# Save / load
# ---------------------------------------------------------------------------

func to_save_dict() -> Dictionary:
	return {
		# Persist the offer by name; the tier object is rehydrated from the table.
		"current_offer": current_offer.tier_name if current_offer != null else "",
		"offered_band": _offered_band,
	}


func load_save_dict(data: Dictionary) -> void:
	_offered_band = int(data.get("offered_band", -1))
	var offer_name := String(data.get("current_offer", ""))
	current_offer = null
	if offer_name != "":
		for tier in _tiers:
			if (tier as LoanTier).tier_name == offer_name:
				current_offer = tier as LoanTier
				break
