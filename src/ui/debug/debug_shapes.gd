class_name DebugShapes
extends Node2D
## Draws what the rules see over the floor, in debug builds (DebugPanel's Tools tab,
## DebugCheats.show_shapes): every body on screen (its collision circle), the hero's weapon reach,
## each monster's attack range (red) and how far it notices the hero (dim), and a line to its
## target. In the world's coordinates (a child of the Game, under the camera); only reads.

const BODY := Color(0.4, 1.0, 0.5, 0.9)
const REACH := Color(1.0, 0.85, 0.3, 0.8)
const ATTACK := Color(1.0, 0.3, 0.25, 0.85)
const SIGHT := Color(0.6, 0.75, 1.0, 0.35)
const TARGET := Color(1.0, 0.3, 0.25, 0.5)

var game: Game


func _init() -> void:
	name = "DebugShapes"
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX - 1
	hide()


func _process(_delta: float) -> void:
	visible = DebugCheats.show_shapes
	if visible:
		queue_redraw()


func _draw() -> void:
	var world := game.player.world if game and game.player and is_instance_valid(game.player.world) else null
	if world == null or not world.is_inside_tree():
		return
	var view := world.view_rect()
	for actor in world.get_actors():
		if not is_instance_valid(actor) or actor.is_dead or not view.has_point(actor.global_position):
			continue
		var at := actor.global_position
		draw_arc(at, actor.radius, 0.0, TAU, 24, BODY, 1.0)
		var weapon := actor.get_weapon()
		if actor is Monster:
			var monster := actor as Monster
			draw_arc(at, monster.detect_radius(), 0.0, TAU, 64, SIGHT, 1.0)
			if weapon:
				var reach := monster.attack_range(game.player) if game.player else weapon.reach
				draw_arc(at, reach, 0.0, TAU, 32, ATTACK, 1.0)
			if is_instance_valid(monster.target):
				draw_line(at, monster.target.global_position, TARGET, 1.0)
		elif weapon:
			draw_arc(at, actor.radius + weapon.reach, 0.0, TAU, 32, REACH, 1.0)
