class_name ArmorDef
extends EquipmentDef
## Head or body protection. All of its numbers live in `bonuses`.

@export_group("Look when worn")
## Layer drawn over the wearer, with the same animations as the hero (idle_down, walk_left...).
## Grayscale art: `wear_color` gives it its color, so one style serves many armors.
## Styles live in res://data/visuals/wear/ (hood, helm, tunic, mail, plate).
@export var wear_frames: SpriteFrames
@export var wear_color: Color = Color.WHITE


func get_type_label() -> String:
	return tr("Armor (%s)") % tr(SLOT_NAMES[slot])
