class_name MessageLog
extends VBoxContainer
## Shows the last few game messages, each fading out after a while.

@export var max_lines := 5
@export var line_lifetime := 4.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	Events.message_logged.connect(add_message)


func add_message(text: String, color: Color) -> void:
	var line := Label.new()
	line.text = text
	line.mouse_filter = MOUSE_FILTER_IGNORE
	# Long lines wrap inside the column instead of stretching the HP bars across the screen.
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_color_override("font_color", color)
	line.add_theme_color_override("font_outline_color", Color.BLACK)
	line.add_theme_constant_override("outline_size", 5)
	add_child(line)
	while get_child_count() > max_lines:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()

	var tween := line.create_tween()
	tween.tween_interval(line_lifetime)
	tween.tween_property(line, "modulate:a", 0.0, 0.5)
	tween.tween_callback(line.queue_free)


func clear() -> void:
	for child in get_children():
		child.queue_free()
