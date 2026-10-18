extends Node
## Runs a play session: creates the player, moves between floors, offers perks and relics,
## pauses for menus and handles game over. Main scene of the project.

const PLAYER_SCENE := preload("res://src/entities/player/player.tscn")
const PERK_CHOICES := 3
## Pause between the boss' death and the relic choice, to enjoy the explosions.
const RELIC_DELAY := 1.6

@export var content: ContentDB

var depth := 1
var kills := 0
var player: Player

## Perk choices waiting to be shown: [{ rarity, count, title, subtitle }]
var _pending_offers: Array[Dictionary] = []

@onready var world: World = $World
@onready var hud: Hud = $Hud
@onready var inventory_panel: InventoryPanel = $Menus/InventoryPanel
@onready var perk_panel: PerkChoicePanel = $Menus/PerkChoicePanel
@onready var game_over_panel: GameOverPanel = $Menus/GameOverPanel
@onready var screen_fx: ScreenEffects = $ScreenFx/Effects


func _ready() -> void:
	if content.sounds:
		Sfx.bank = content.sounds
	world.stairs_reached.connect(_on_stairs_reached)
	hud.inventory_requested.connect(open_inventory)
	inventory_panel.closed.connect(_on_menu_closed)
	perk_panel.chosen.connect(_on_perk_chosen)
	game_over_panel.restart_requested.connect(start_run)
	Events.monster_killed.connect(func(_monster: Monster) -> void: kills += 1)
	Events.boss_started.connect(_on_boss_started)
	Events.boss_defeated.connect(_on_boss_defeated)
	start_run()


func start_run() -> void:
	_set_paused(false)
	game_over_panel.hide()
	inventory_panel.hide()
	perk_panel.hide()
	_pending_offers.clear()
	if player:
		player.get_parent().remove_child(player)
		player.queue_free()

	world.rng.randomize()
	depth = 1
	kills = 0
	player = PLAYER_SCENE.instantiate() as Player
	player.setup(content.player)
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_player_leveled_up)
	player.damaged.connect(func(damage: int) -> void:
		screen_fx.kick(clampf(float(damage) / player.get_max_hp() * 5.0, 0.3, 1.0)))
	hud.bind_player(player)
	_enter_floor()


func is_menu_open() -> bool:
	return inventory_panel.visible or perk_panel.visible or game_over_panel.visible


func open_inventory() -> void:
	if player == null or player.is_dead or is_menu_open():
		return
	_set_paused(true)
	inventory_panel.open(player)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and not is_menu_open():
		get_viewport().set_input_as_handled()
		open_inventory()


func _set_paused(paused: bool) -> void:
	HitStop.reset()
	get_tree().paused = paused


# --- Floors ------------------------------------------------------------------

func _enter_floor() -> void:
	world.build_floor(depth, content)
	world.place_player(player)
	if world.theme:
		Sfx.play_music(world.theme.music)
	Events.depth_changed.emit(depth)
	if world.arena:
		Events.log_message("Depth %d. Something big is waiting..." % depth, Color("ff6b6b"))
	else:
		Events.log_message("Depth %d. Find the stairs!" % depth, Color("ffd166"))


func _on_stairs_reached() -> void:
	Sfx.play_ui(Sfx.bank.stairs)
	depth += 1
	# Deferred: we are inside a physics callback, where the level can't be rebuilt.
	_enter_floor.call_deferred()


# --- Bosses ------------------------------------------------------------------

func _on_boss_started(boss: Monster) -> void:
	var def := boss.def as BossDef
	hud.show_banner(boss.display_name, Color("ff6b6b"))
	if def and not def.title.is_empty():
		Events.log_message("%s, %s" % [boss.display_name, def.title], Color("ff6b6b"))
	var music := def.music if def and def.music else Sfx.bank.boss_music
	if music:
		Sfx.play_music(music)


func _on_boss_defeated(boss: Monster) -> void:
	hud.show_banner("Victory!")
	Sfx.play_ui(Sfx.bank.boss_defeated)
	Events.log_message("%s is defeated! The way down is open." % boss.display_name, Color("ffd166"))
	if world.theme:
		Sfx.play_music(world.theme.music)
	var def := boss.def as BossDef
	if def and def.relic_choices > 0:
		var winner := player
		await get_tree().create_timer(RELIC_DELAY, false).timeout
		if player != winner or player.is_dead:
			return  # the run ended in the meantime
		_queue_offer(PerkDef.Rarity.RARE, def.relic_choices, "Relic", "The boss left a relic behind. Choose one.")


# --- Perks -------------------------------------------------------------------

func _on_player_leveled_up(level: int) -> void:
	_queue_offer(PerkDef.Rarity.COMMON, PERK_CHOICES, "Level %d!" % level, "Choose an upgrade")


func _queue_offer(rarity: PerkDef.Rarity, count: int, title: String, subtitle: String) -> void:
	_pending_offers.append({ "rarity": rarity, "count": count, "title": title, "subtitle": subtitle })
	# Deferred: level ups happen in the middle of combat code.
	_show_next_offer.call_deferred()


func _show_next_offer() -> void:
	while not _pending_offers.is_empty():
		if is_menu_open() or player == null or player.is_dead:
			return
		var offer: Dictionary = _pending_offers.pop_front()
		var perks := content.pick_perks(player.perks, offer.count, offer.rarity, world.rng)
		if perks.is_empty():
			continue  # everything is maxed out
		_set_paused(true)
		perk_panel.open(offer.title, offer.subtitle, perks, player.perks)
		return


func _on_perk_chosen(perk: PerkDef) -> void:
	player.perks.add(perk)
	Events.log_message("%s (level %d)" % [perk.display_name, player.perks.stacks_of(perk)], perk.color)
	Vfx.sparkles(world, player.global_position, perk.color)
	_on_menu_closed()


## Resumes the game, or shows the next perk choice if one is waiting.
func _on_menu_closed() -> void:
	_set_paused(false)
	_show_next_offer()


func _on_player_died(_actor: Actor) -> void:
	_pending_offers.clear()
	await get_tree().create_timer(1.2).timeout
	Sfx.play_ui(Sfx.bank.game_over)
	game_over_panel.show_result(depth, player.level, kills)
