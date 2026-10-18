class_name PerkTray
extends HFlowContainer
## Row of small icons showing the perks collected this run, with their level.

const ICON_SIZE := Vector2(24, 24)

var _perks: PerkSet


func bind(perks: PerkSet) -> void:
	if _perks:
		_perks.changed.disconnect(_rebuild)
	_perks = perks
	_perks.changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for entry in _perks.entries:
		var icon := TextureRect.new()
		icon.texture = entry.perk.icon
		icon.custom_minimum_size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = entry.perk.display_name
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if entry.stacks > 1:
			var level := Label.new()
			level.text = str(entry.stacks)
			level.add_theme_font_size_override("font_size", 12)
			level.position = Vector2(16, 10)
			icon.add_child(level)
		add_child(icon)
