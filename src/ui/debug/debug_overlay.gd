class_name DebugOverlay
extends Label
## A line of numbers over the game in debug builds (DebugPanel's Tools tab): frames per second,
## monsters (awake / on the floor), shots in the air, nodes, draw calls; and, whatever the Tools
## tab says, the cheats that are on (DebugCheats.summary()) and whether the run is a debug run, so
## a cheat is never forgotten on. Hidden when there is nothing to say. Only reads.

## Seconds between two refreshes (the numbers would flicker otherwise).
const REFRESH := 0.25

var game: Game
var _timer := 0.0


func _init() -> void:
	name = "DebugOverlay"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = 4
	UiSkin.set_text_style(self, Fonts.SMALL)
	add_theme_color_override("font_color", Color(1, 0.94, 0.82))
	hide()


func _process(delta: float) -> void:
	_timer -= HitStop.real_delta(delta)
	if _timer > 0.0:
		return
	_timer = REFRESH
	refresh()


## The overlay's text now (and shown or hidden by it).
func refresh() -> void:
	var lines := PackedStringArray()
	if DebugCheats.show_stats:
		lines.append(stats_line())
	var cheats := DebugCheats.summary()
	if not cheats.is_empty():
		lines.append("Cheats: %s" % cheats)
	if DebugCheats.debug_run:
		lines.append("Debug run: nothing is saved or recorded")
	text = "\n".join(lines)
	visible = not lines.is_empty()


func stats_line() -> String:
	var world := game.player.world if game and game.player and is_instance_valid(game.player.world) else null
	var monsters := get_tree().get_nodes_in_group("monsters").size()
	var awake := world.activity.awake.size() if world else 0
	var shots := world.get_node("Projectiles").get_child_count() if world else 0
	return "%d fps | monsters %d awake / %d | shots %d | nodes %d | draw calls %d" % [
		Engine.get_frames_per_second(), awake, monsters, shots,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
