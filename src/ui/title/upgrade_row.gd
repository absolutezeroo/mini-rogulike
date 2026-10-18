class_name UpgradeRow
extends PanelContainer
## One upgrade at the shrine: icon, name, level, what it does, and its price.

signal buy_requested(upgrade: UpgradeDef)

var upgrade: UpgradeDef

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _description: Label = %Description
@onready var _buy: Button = %BuyButton


func _ready() -> void:
	_buy.pressed.connect(func() -> void: buy_requested.emit(upgrade))


func setup(def: UpgradeDef) -> void:
	upgrade = def
	_icon.texture = def.icon
	refresh()


func refresh() -> void:
	if upgrade == null:
		return
	var level := Profile.level_of(upgrade)
	var name_text := upgrade.display_name
	if upgrade.max_level > 1:
		name_text += "   %d / %d" % [level, upgrade.max_level]
	elif level > 0:
		name_text += "   (done)"
	_name.text = name_text
	_name.add_theme_color_override("font_color", upgrade.color.lerp(Color.WHITE, 0.4))
	var text := upgrade.description
	if upgrade.bonuses and upgrade.kind == UpgradeDef.Kind.STATS:
		text += ("\n" if not text.is_empty() else "") + upgrade.bonuses.describe() + " per level"
	_description.text = text
	if level >= upgrade.max_level:
		_buy.text = "Max"
		_buy.disabled = true
	else:
		_buy.text = "%d souls" % upgrade.cost_for_level(level)
		_buy.disabled = not Profile.can_buy(upgrade)
