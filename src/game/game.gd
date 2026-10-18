extends Node
## Runs a play session: creates the player, moves between floors, pauses for the
## inventory and handles game over. Main scene of the project.

const PLAYER_SCENE := preload("res://src/entities/player/player.tscn")

@export var content: ContentDB

var depth := 1
var kills := 0
var player: Player

@onready var world: World = $World
@onready var hud: Hud = $Hud
@onready var inventory_panel: InventoryPanel = $Menus/InventoryPanel
@onready var game_over_panel: GameOverPanel = $Menus/GameOverPanel


func _ready() -> void:
	if content.sounds:
		Sfx.bank = content.sounds
	world.stairs_reached.connect(_on_stairs_reached)
	hud.inventory_requested.connect(open_inventory)
	inventory_panel.closed.connect(_on_inventory_closed)
	game_over_panel.restart_requested.connect(start_run)
	Events.monster_killed.connect(func(_monster: Monster) -> void: kills += 1)
	start_run()


func start_run() -> void:
	HitStop.reset()
	get_tree().paused = false
	game_over_panel.hide()
	inventory_panel.hide()
	if player:
		player.get_parent().remove_child(player)
		player.queue_free()

	world.rng.randomize()
	depth = 1
	kills = 0
	player = PLAYER_SCENE.instantiate() as Player
	player.setup(content.player)
	player.died.connect(_on_player_died)
	hud.bind_player(player)
	_enter_floor()


func open_inventory() -> void:
	if player == null or player.is_dead or game_over_panel.visible:
		return
	HitStop.reset()
	get_tree().paused = true
	inventory_panel.open(player)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and not inventory_panel.visible:
		get_viewport().set_input_as_handled()
		open_inventory()


func _enter_floor() -> void:
	world.build_floor(depth, content)
	world.place_player(player)
	if world.theme:
		Sfx.play_music(world.theme.music)
	Events.depth_changed.emit(depth)
	Events.log_message("Depth %d. Find the stairs!" % depth, Color("ffd166"))


func _on_stairs_reached() -> void:
	Sfx.play_ui(Sfx.bank.stairs)
	depth += 1
	# Deferred: we are inside a physics callback, where the level can't be rebuilt.
	_enter_floor.call_deferred()


func _on_inventory_closed() -> void:
	get_tree().paused = false


func _on_player_died(_actor: Actor) -> void:
	await get_tree().create_timer(1.2).timeout
	Sfx.play_ui(Sfx.bank.game_over)
	game_over_panel.show_result(depth, player.level, kills)
