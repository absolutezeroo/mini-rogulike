class_name UpgradeRow
extends PanelContainer
## One upgrade at the shrine, in the game's skin: its icon, name and level ("Level 2 / 5"),
## what it is, what you have now and what the next level adds ("Now: +16 max health  >  Next:
## +24 max health"), the items it unlocks, and the Buy button with its price (or why you can't).

signal buy_requested(upgrade: UpgradeDef)

const ICON_SIDE := 64.0
const ITEM_SIDE := 44.0

var upgrade: UpgradeDef

var _icon: TextureRect
var _name: Label
var _level: Label
var _description: Label
var _status: Label
var _items: HBoxContainer
var _buy: Button
var _background: StyleBoxFlat


func _ready() -> void:
	_build()


func setup(def: UpgradeDef) -> void:
	upgrade = def
	_icon.texture = def.icon
	_name.text = tr(def.display_name)
	_name.add_theme_color_override("font_color", def.color.lerp(Color.WHITE, 0.35))
	_description.text = description_of(def)
	_description.visible = not _description.text.is_empty()
	for child in _items.get_children():
		_items.remove_child(child)
		child.queue_free()
	if def.kind == UpgradeDef.Kind.UNLOCK:
		for item in def.items:
			var slot := ItemSlot.new(ITEM_SIDE)
			slot.item = item
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_items.add_child(slot)
			_items.add_child(UiSkin.label(tr(item.display_name), Fonts.BODY, item.rarity_color()))
	_items.visible = _items.get_child_count() > 0
	refresh()


func refresh() -> void:
	if upgrade == null:
		return
	var level := Profile.level_of(upgrade)
	var maxed := level >= upgrade.max_level
	_level.text = level_text(upgrade, level)
	_level.add_theme_color_override("font_color", UiSkin.GOLD if maxed else UiSkin.DIM)
	_status.text = status_text(upgrade, level)
	_status.add_theme_color_override("font_color", UiSkin.GOLD if maxed else UiSkin.TEXT)
	var cost := upgrade.cost_for_level(level)
	if maxed:
		_buy.text = tr("Unlocked") if upgrade.kind == UpgradeDef.Kind.UNLOCK else (tr("Maxed") if upgrade.max_level > 1 else tr("Owned"))
		_buy.disabled = true
	elif Profile.can_buy(upgrade):
		_buy.text = tr("Buy\n%d souls") % cost
		_buy.disabled = false
	else:
		_buy.text = tr("Need\n%d souls") % cost
		_buy.disabled = true
	_background.bg_color = Color(1.0, 0.8, 0.35, 0.1) if maxed else Color(0.0, 0.0, 0.0, 0.16)


# --- Words --------------------------------------------------------------------------

## "Level 2 / 5"; one-level upgrades say "Not bought yet" / "Bought".
static func level_text(def: UpgradeDef, level: int) -> String:
	if def.max_level > 1:
		return (TranslationServer.tr("Level %d / %d  (max)") if level >= def.max_level else TranslationServer.tr("Level %d / %d")) % [level, def.max_level]
	if def.kind == UpgradeDef.Kind.UNLOCK:
		return TranslationServer.tr("Unlocked") if level > 0 else TranslationServer.tr("Locked")
	return TranslationServer.tr("Bought") if level > 0 else TranslationServer.tr("Not bought yet")


## What it is, in a sentence (the data's description, or the stats it raises).
static func description_of(def: UpgradeDef) -> String:
	if not def.description.is_empty():
		return TranslationServer.tr(def.description)
	if def.kind == UpgradeDef.Kind.STATS:
		return TranslationServer.tr("Your hero starts every run stronger.")
	return ""


## What `level` levels give, in plain words ("+16 max health", "2 extra Health Potions").
static func effect_at(def: UpgradeDef, level: int) -> String:
	match def.kind:
		UpgradeDef.Kind.STATS:
			return def.bonuses.times(level).describe() if def.bonuses else ""
		UpgradeDef.Kind.STARTING_ITEMS:
			var names := PackedStringArray()
			for item in def.items:
				names.append(TranslationServer.tr(item.display_name))
			return TranslationServer.tr("start with %d extra %s") % [level, " + ".join(names)]
		UpgradeDef.Kind.STARTING_PERK:
			return TranslationServer.tr("start with the %s perk") % TranslationServer.tr(def.perk.display_name) if def.perk else ""
		UpgradeDef.Kind.UNLOCK:
			return TranslationServer.tr("these items can drop in every run")
		UpgradeDef.Kind.REROLLS:
			return (TranslationServer.tr("%d extra rerolls per run") if level > 1 else TranslationServer.tr("%d extra reroll per run")) % level
		UpgradeDef.Kind.BANISHES:
			return (TranslationServer.tr("%d extra banishes per run") if level > 1 else TranslationServer.tr("%d extra banish per run")) % level
		UpgradeDef.Kind.RULES:
			var parts := PackedStringArray()
			if def.max_hp_scale != 1.0:
				parts.append(TranslationServer.tr("%+d%% max health") % roundi((def.max_hp_scale - 1.0) * 100.0))
			if def.healing_scale != 1.0:
				var heals := TranslationServer.tr("heals %d%% weaker") if def.healing_scale < 1.0 else TranslationServer.tr("heals %d%% stronger")
				parts.append(heals % absi(roundi((def.healing_scale - 1.0) * 100.0)))
			if def.heal_on_clear > 0.0:
				parts.append(TranslationServer.tr("heal %d%% of max health when a floor is won") % roundi(def.heal_on_clear * level * 100.0))
			if def.shop_price_scale != 1.0:
				parts.append(TranslationServer.tr("merchant prices %+d%%") % roundi((def.shop_price_scale - 1.0) * 100.0))
			if def.shop_extra_items > 0:
				parts.append(TranslationServer.tr("%d more items at the merchant") % (def.shop_extra_items * level))
			if def.elite_magic_drop:
				parts.append(TranslationServer.tr("elites always drop Magic gear"))
			if def.cartographer:
				parts.append(TranslationServer.tr("the minimap shows stairs, merchant and forge"))
			if def.armory:
				parts.append(TranslationServer.tr("pick your starting weapon"))
			return ", ".join(parts)
		UpgradeDef.Kind.RANDOM_STARTING_ITEM:
			return TranslationServer.tr("start with a random spell tome")
		UpgradeDef.Kind.OATH:
			return TranslationServer.tr("a new oath to swear before a run")
	return ""


## What you have, and what buying adds: "Now: +16 max health  >  Next: +24 max health".
static func status_text(def: UpgradeDef, level: int) -> String:
	if def.max_level <= 1:
		if level > 0:
			return TranslationServer.tr("Active: %s") % effect_at(def, 1)
		return TranslationServer.tr("Gives: %s") % effect_at(def, 1)
	if level <= 0:
		return TranslationServer.tr("Level 1 gives: %s") % effect_at(def, 1)
	if level >= def.max_level:
		return TranslationServer.tr("Now: %s  (maxed)") % effect_at(def, level)
	return TranslationServer.tr("Now: %s   >   Next: %s") % [effect_at(def, level), effect_at(def, level + 1)]


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	_background = StyleBoxFlat.new()
	_background.bg_color = Color(0.0, 0.0, 0.0, 0.16)
	_background.set_content_margin_all(8)
	_background.content_margin_left = 10
	_background.content_margin_right = 10
	_background.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", _background)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)

	var frame := PanelContainer.new()
	var slot := StyleBoxTexture.new()
	slot.texture = UiSkin.SLOT
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		slot.set_texture_margin(side, 15)
		slot.set_content_margin(side, 10)
	frame.add_theme_stylebox_override("panel", slot)
	frame.custom_minimum_size = Vector2(ICON_SIDE, ICON_SIDE)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(frame)
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_icon)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	text.add_child(head)
	_name = UiSkin.label("", Fonts.BODY)
	head.add_child(_name)
	_level = UiSkin.label("", Fonts.BODY, UiSkin.DIM)
	_level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_level)
	_description = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	text.add_child(_description)
	_status = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	text.add_child(_status)
	_items = HBoxContainer.new()
	_items.add_theme_constant_override("separation", 8)
	text.add_child(_items)

	_buy = MenuWindow.button("", Fonts.BODY, 60)
	_buy.custom_minimum_size.x = 150
	_buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_buy.pressed.connect(func() -> void: buy_requested.emit(upgrade))
	row.add_child(_buy)
	MenuWindow.expose(_buy, "BuyButton", self)
