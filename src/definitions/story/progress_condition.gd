class_name ProgressCondition
extends Resource
## Something the player has done across runs that opens a piece of the story: a warden slain so
## many times, a floor reached, a fragment found, a deed done (docs/lore.md section 7: what is
## revealed when). Chronicle chapters, a warden's waking lines and fragments are gated by a list
## of these; NPC dialogue can be too. Subclass it for a new kind (src/definitions/story/conditions/
## and deeds/): override is_met() and describe(). Read through Narrative, never by the UI.
##
## `subject` is whom the gated text is about (a warden's BossDef for its chronicle): a condition
## left without its own target ("slay it 3 times") reads it.


## True once the player has done it (Profile).
func is_met(_subject: Resource = null) -> bool:
	return true


## How to meet it, in plain words for the codex ("Slay it 3 times"). A deed answers with its
## riddle until a fragment gives the rule away (DeedCondition).
func describe(_subject: Resource = null) -> String:
	return ""


## The deeds inside it (an AllCondition holds others): the HuntTracker watches these at a
## warden's death.
func deeds() -> Array[DeedCondition]:
	return []


## Every condition of `conditions` is met.
static func all_met(conditions: Array[ProgressCondition], subject: Resource = null) -> bool:
	for condition in conditions:
		if condition and not condition.is_met(subject):
			return false
	return true


## The plain lines of the conditions still to meet (the codex's lock), in order.
static func describe_unmet(conditions: Array[ProgressCondition], subject: Resource = null) -> PackedStringArray:
	var lines := PackedStringArray()
	for condition in conditions:
		if condition and not condition.is_met(subject):
			var text := condition.describe(subject)
			if not text.is_empty():
				lines.append(text)
	return lines
