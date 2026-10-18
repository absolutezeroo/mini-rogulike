class_name DifficultyCard
extends Button
## One difficulty on the title screen: name, what changes, and how to unlock it.

var difficulty: DifficultyDef

@onready var _name: Label = %Name
@onready var _description: Label = %Description
@onready var _details: Label = %Details


func show_difficulty(def: DifficultyDef, unlocked: bool, selected: bool) -> void:
	difficulty = def
	_name.text = def.display_name + ("  *" if selected else "")
	_name.add_theme_color_override("font_color", def.color)
	_description.text = def.description
	if unlocked:
		_details.text = _describe(def)
	else:
		_details.text = "Locked: win a run on %s" % def.unlocked_by.display_name
	disabled = not unlocked
	modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.55)


static func _describe(def: DifficultyDef) -> String:
	var lines := PackedStringArray()
	lines.append("Monster HP x%s" % _number(def.monster_hp))
	lines.append("Monster damage x%s" % _number(def.monster_damage))
	lines.append("Time to dodge x%s" % _number(def.telegraph_time))
	if def.extra_monsters > 0:
		lines.append("+%d monster%s per room" % [def.extra_monsters, "s" if def.extra_monsters > 1 else ""])
	if def.heal_on_new_floor > 0.0:
		lines.append("Heal %d%% per floor" % roundi(def.heal_on_new_floor * 100.0))
	lines.append("Souls x%s" % _number(def.souls))
	return "\n".join(lines)


static func _number(value: float) -> String:
	return ("%.2f" % value).rstrip("0").rstrip(".")
