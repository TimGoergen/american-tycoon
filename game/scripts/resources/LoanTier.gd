class_name LoanTier
extends Resource

# One rung of the credit-offer table (GDD §8.6, Mechanics Spec §8/§11).
# Loaded from res://config/loans/*.tres — never hardcoded.
#
# Credit comes to you, and the terms improve as you need them less: a payday
# lender for the bootstrapper, prime rates on enormous sums, a bailout once you
# are "load-bearing." Each tier is eligible for a net-worth band; when an offer is
# rolled, the system picks the tier whose band the player currently sits in.
#
# A tier is a TEMPLATE. When the player accepts an offer, DebtState turns the
# template into a concrete repayment schedule (see DebtState.take_loan).


## Display name for the offer ("Payday Advance", "Prime Credit Line", "Federal Bailout").
@export var tier_name: String = ""

## Deadpan pitch shown in the offer mail (the narrator is a true believer, §1.2).
@export var flavor: String = ""

## Net-worth band this tier is offered in. A rolled offer uses the tier whose
## [min, max] band contains the player's current net worth. The top tier should
## set a very large max so it always covers the high end.
@export var eligibility_min_net_worth: float = 0.0
@export var eligibility_max_net_worth: float = 1.0e18

## Cash handed over up front when the offer is accepted.
@export var principal: float = 1000.0

## Total repaid = principal × this. 1.0 would be interest-free; payday terms are
## brutal (e.g. 1.5), prime is gentle (e.g. 1.1), a bailout can be ≤ 1.0.
@export var interest_multiplier: float = 1.3

## How many milestone-triggered payments the loan is split into.
@export var payment_count: int = 3

## Payment 1 comes due when net worth reaches principal × this multiple — i.e. once
## the player has visibly grown past the loan ("your success has been noticed").
## Keeping the trigger ABOVE the principal guarantees idling never triggers a
## payment: you only owe once you've already grown enough to pay (GDD §8.5).
@export var first_trigger_multiple: float = 3.0

## Each later payment's trigger adds this × principal of net worth on top of the
## previous one, so payments space out as the fortune climbs.
@export var trigger_step_multiple: float = 3.0
