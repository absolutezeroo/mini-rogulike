class_name EncounterNiche
extends Resource
## An empty niche standing beside an encounter (EncounterDef.niche): the Keeper's Statue has the
## one cut for the last keeper, Tôma's (docs/lore.md, "The keepers"). Drawn on the floor beside
## it, told under its description in its panel. Its inscription says nothing to the player until
## `reveal` (the keeper may be named: `keeper_named`); then `revealed_text` is shown instead.

## What the niche shows before the reveal: an empty niche, an inscription no one explains.
@export_multiline var text: String
## What it shows once `reveal` is met (it may name the keeper).
@export_multiline var revealed_text: String
## The progress that lets it be read (docs/lore.md section 7).
@export var reveal: ProgressCondition
## Where it stands, from the encounter's middle (world units).
@export var offset: Vector2 = Vector2(30, -4)
## The stone it is cut in, lit side first (the statue's grey).
@export var stone: Color = Color(0.62, 0.66, 0.72)


## The text the niche shows now (English key, translated where shown).
func shown_text() -> String:
	if reveal and not revealed_text.is_empty() and reveal.is_met():
		return revealed_text
	return text
