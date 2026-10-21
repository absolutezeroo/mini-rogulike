class_name RuneDef
extends ItemDef
## A rune stone. Found on elites, bosses and in chests; set into a weapon at a forge (Forge),
## it changes how that weapon fights for as long as it stays there: flames on the hits,
## lightning, frost, life drawn back... Each weapon has 1 to 3 sockets, by rarity
## (ItemRarity.SOCKETS). The smith takes a rune back out, intact, for gold.
## Listed in content_db.tres > Runes (not with the items: merchants and chests don't sell
## or hold them by chance); `min_depth` and `spawn_weight` as usual.

## Its family (fire, frost, blood, storm, arcane): its color and where it belongs.
@export var family: SynergyDef
## What it does while set in the worn weapon (like a perk's). Say it in `description`.
@export var passives: Array[Passive] = []
@export var bonuses: StatBlock


func get_type_label() -> String:
	return tr("%s rune") % tr(family.display_name) if family else tr("Rune")


func rarity_color() -> Color:
	return family.color if family else super.rarity_color()


func get_details() -> String:
	var text := tr(description)
	if bonuses:
		var bonus_text := bonuses.describe()
		if not bonus_text.is_empty():
			text += "\n" + bonus_text
	return text + "\n" + tr("Set it into a weapon at a forge.")
