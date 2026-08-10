class_name AudioEventCatalog
extends Resource

# The set of sounds the game knows how to play, loaded once by the Audio autoload from
# game/config/audio_events.tres.
#
# A flat list rather than a Dictionary because Godot's inspector edits arrays of sub-resources well
# and Dictionaries of them badly — and this file exists to be edited by hand while auditioning
# samples. The lookup Dictionary is built once at load (see `index`), so the flat list costs nothing
# at play time.

## Every sound. Order is irrelevant; `id` is the key.
@export var events: Array[AudioEvent] = []


## Build a lookup of id → event. Called once by Audio; the result is what gets queried per play.
##
## A duplicate id is a silent-loser bug — one of the two would simply never be reachable — so it is
## reported rather than tolerated.
func index() -> Dictionary:
	var by_id: Dictionary = {}
	for event in events:
		if event == null or event.id == &"":
			push_warning("AudioEventCatalog: skipping an entry with no id")
			continue
		if by_id.has(event.id):
			push_warning("AudioEventCatalog: duplicate id '%s'; keeping the first" % event.id)
			continue
		by_id[event.id] = event
	return by_id
