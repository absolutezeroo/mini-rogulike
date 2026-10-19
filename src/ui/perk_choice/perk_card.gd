class_name PerkCard
extends Button
## One choice of the perk screen: icon, name, level, what it does, and its families
## (SynergyDef): how many you hold, or a bright line when this card would wake one.
## The card grows to fit its text (never less than its base size), so nothing spills out.

const RARE_COLOR := Palette.GOLD

@onready var _rarity: Label = %Rarity
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _level: Label = %Level
@onready var _description: Label = %Description
@onready var _families: VBoxContainer = %Families

## This card would wake a family.
var completes := false


func show_perk(perk: PerkDef, owned: PerkSet) -> void:
	var owned_stacks := owned.stacks_of(perk)
	_rarity.text = "RELIC" if perk.rarity == PerkDef.Rarity.RARE else ""
	_rarity.visible = perk.rarity == PerkDef.Rarity.RARE
	_icon.texture = perk.icon
	_name.text = perk.display_name
	_name.add_theme_color_override("font_color", perk.color.lerp(Color.WHITE, 0.4))
	if owned_stacks == 0:
		_level.text = "New!" if perk.max_stacks == 1 else "New!  (max %d)" % perk.max_stacks
	else:
		_level.text = "Level %d  >  %d" % [owned_stacks, owned_stacks + 1]
	_description.text = perk.describe()
	completes = false
	for synergy in perk.synergies:
		if synergy:
			_families.add_child(_family_row(synergy, owned, perk))
	FitToContent.grow_later(self, $Margin)  # long text: a taller card, nothing spills out


## "Inferno 1/3" (dim), "Inferno awake" or, when taking this card wakes it, "Wakes Inferno!".
func _family_row(synergy: SynergyDef, owned: PerkSet, perk: PerkDef) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.texture = synergy.icon
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	var have := owned.pieces_of(synergy)
	if owned.would_complete(perk, synergy):
		completes = true
		label.text = "Wakes %s!" % synergy.display_name
		label.add_theme_color_override("font_color", synergy.color.lerp(Color.WHITE, 0.3))
		var tween := label.create_tween().set_loops()
		tween.tween_property(label, "modulate", Color(1.4, 1.4, 1.4), 0.45)
		tween.tween_property(label, "modulate", Color.WHITE, 0.45)
	elif owned.is_awake(synergy):
		label.text = "%s (awake)" % synergy.display_name
		label.add_theme_color_override("font_color", synergy.color)
	else:
		var after := have + (1 if owned.stacks_of(perk) == 0 else 0)
		label.text = "%s %d/%d" % [synergy.display_name, after, synergy.pieces]
		label.add_theme_color_override("font_color", synergy.color.lerp(Color(0.6, 0.6, 0.6), 0.45))
	row.add_child(label)
	return row
