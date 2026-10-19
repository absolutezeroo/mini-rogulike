class_name PerkCard
extends Button
## One choice of the perk screen: icon, name, level and what it does.

const RARE_COLOR := Palette.GOLD

@onready var _rarity: Label = %Rarity
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _level: Label = %Level
@onready var _description: Label = %Description


func show_perk(perk: PerkDef, owned_stacks: int) -> void:
	_rarity.text = "RELIC" if perk.rarity == PerkDef.Rarity.RARE else ""
	_icon.texture = perk.icon
	_name.text = perk.display_name
	_name.add_theme_color_override("font_color", perk.color.lerp(Color.WHITE, 0.4))
	if owned_stacks == 0:
		_level.text = "New!" if perk.max_stacks == 1 else "New!  (max %d)" % perk.max_stacks
	else:
		_level.text = "Level %d  >  %d" % [owned_stacks, owned_stacks + 1]
	_description.text = perk.describe()
