class_name PerkTray
extends HFlowContainer
## Row of small icons showing the awakened families (framed in their color), then the perks
## collected this run, with their level.

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
	for synergy in _perks.awakened():
		var badge := Panel.new()
		badge.custom_minimum_size = ICON_SIZE + Vector2(6, 6)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(synergy.color, 0.25)
		frame.border_color = synergy.color
		frame.set_border_width_all(2)
		frame.set_corner_radius_all(4)
		badge.add_theme_stylebox_override("panel", frame)
		var icon := TextureRect.new()
		icon.texture = synergy.icon
		icon.position = Vector2(3, 3)
		icon.size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(icon)
		add_child(badge)
	for entry in _perks.entries:
		var icon := TextureRect.new()
		icon.texture = entry.perk.icon
		icon.custom_minimum_size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = tr(entry.perk.display_name)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if entry.stacks > 1:
			var level := Label.new()
			level.text = str(entry.stacks)
			level.add_theme_font_size_override("font_size", 12)
			level.position = Vector2(16, 10)
			icon.add_child(level)
		add_child(icon)
