class_name DebtState

# One generation's debt (GDD §8.5, Mechanics Spec §8). Headless and scene-tree
# free, like the rest of the core, so the simulator drives it directly.
#
# Debt is paid on milestone triggers, NEVER on a wall clock — an idle game must
# not punish idling (GDD §0.1). A loan is an ordered list of payments, each of
# which comes due only when the player's NET WORTH climbs past a threshold ("your
# success has been noticed; first payment is now due"). Because every trigger sits
# above the loan principal, you can never owe a payment you haven't already grown
# enough to afford — time away is always safe.
#
# When a payment comes due the player gets a GRACE WINDOW measured in seconds of
# ACTIVE play (it does not tick down while away). Let it lapse unpaid and the
# generation defaults — the only clock that runs against the player. A default is
# surfaced to Main, which forces the bankruptcy generation-end (creditors seize the
# estate before tax; see EstateWaterfall and DynastyState).
#
# One loan is active at a time (GDD §8.6); OfferSystem enforces that before
# take_loan is called.


## Dollars still owed across all unpaid scheduled payments (including any due now).
var outstanding_balance: float = 0.0

## Upcoming payments in trigger order; index 0 is the next one. Each entry is a
## Dictionary { "trigger_net_worth": float, "amount": float }. The currently-due
## payment (if any) has already been removed from here and lives in `due_amount`.
var schedule: Array = []

## The payment awaiting payment right now, or 0.0 if nothing is due.
var due_amount: float = 0.0

## Seconds of ACTIVE play left to pay the due payment before defaulting. Only
## meaningful while due_amount > 0.
var grace_remaining: float = 0.0

## Set true the instant a due payment's grace lapses unpaid — the bankruptcy
## trigger. Latches until a new generation (a fresh DebtState) is created.
var defaulted: bool = false

## Full grace window in active-play seconds, captured at construction from tuning.
var _grace_seconds: float = 90.0


func _init(grace_seconds: float = 90.0) -> void:
	_grace_seconds = grace_seconds


# ---------------------------------------------------------------------------
# Taking on debt
# ---------------------------------------------------------------------------

## Whether a loan is currently outstanding (one at a time, GDD §8.6).
func has_active_loan() -> bool:
	return outstanding_balance > 0.0


## Install a concrete repayment schedule from a loan template (an accepted offer or
## an origin debt). The caller credits the principal to cash separately — this only
## sets up what must be repaid. Each payment is amount = principal × interest ÷ count,
## triggered at successively higher net-worth milestones (LoanTier defines the
## multiples). Assumes no loan is currently active.
func take_loan(tier: LoanTier) -> void:
	var amount_each := floorf(tier.principal * tier.interest_multiplier / float(tier.payment_count))
	for k in range(tier.payment_count):
		var trigger := tier.principal * (tier.first_trigger_multiple + float(k) * tier.trigger_step_multiple)
		schedule.append({
			"trigger_net_worth": trigger,
			"amount": amount_each,
		})
		outstanding_balance += amount_each


# ---------------------------------------------------------------------------
# Simulation driver
# ---------------------------------------------------------------------------

## Advance the debt by `delta` active-play seconds at the current `net_worth`.
##   • If a payment is due, burn down the grace window; default when it lapses.
##   • Otherwise, promote the next scheduled payment to "due" once net worth
##     crosses its trigger.
## Pure bookkeeping — paying happens via pay() in response to the player.
func tick(net_worth: float, delta: float) -> void:
	if due_amount > 0.0:
		grace_remaining -= delta
		if grace_remaining <= 0.0:
			grace_remaining = 0.0
			defaulted = true
		return

	if not schedule.is_empty():
		var next: Dictionary = schedule[0]
		if net_worth >= float(next["trigger_net_worth"]):
			due_amount = float(next["amount"])
			grace_remaining = _grace_seconds
			schedule.remove_at(0)


# ---------------------------------------------------------------------------
# Paying
# ---------------------------------------------------------------------------

## Whether there is a payment due that the player can currently afford.
func can_pay(economy: EconomyState) -> bool:
	return due_amount > 0.0 and economy.cash >= due_amount


## Pay the due payment in full from cash. Returns false if nothing is due or the
## player can't afford it (partial payment is not allowed — Spec §8). Paying clears
## the due state and reduces the outstanding balance; the next payment will become
## due later when net worth crosses its own trigger.
func pay(economy: EconomyState) -> bool:
	if not can_pay(economy):
		return false
	economy.cash -= due_amount
	outstanding_balance -= due_amount
	due_amount = 0.0
	grace_remaining = 0.0
	return true


# ---------------------------------------------------------------------------
# Save / load
# ---------------------------------------------------------------------------

func to_save_dict() -> Dictionary:
	return {
		"outstanding_balance": outstanding_balance,
		"schedule": schedule.duplicate(true),
		"due_amount": due_amount,
		"grace_remaining": grace_remaining,
		"defaulted": defaulted,
	}


func load_save_dict(data: Dictionary) -> void:
	outstanding_balance = float(data.get("outstanding_balance", 0.0))
	due_amount = float(data.get("due_amount", 0.0))
	grace_remaining = float(data.get("grace_remaining", 0.0))
	defaulted = bool(data.get("defaulted", false))
	schedule = []
	for entry in data.get("schedule", []):
		schedule.append((entry as Dictionary).duplicate())
