extends Node
## Runs a play session: creates the player, moves between floors, offers perks and relics,
## pauses for menus and handles game over. Main scene of the project.

const PLAYER_SCENE := preload("res://src/entities/player/player.tscn")
const TITLE_SCENE := "res://src/ui/title/title_screen.tscn"
const PERK_CHOICES := 3
## Pause between the boss' death and the relic choice, to enjoy the explosions.
const RELIC_DELAY := 1.6

@export var content: ContentDB

var depth := 1
var kills := 0
var difficulty: DifficultyDef
var bosses_slain := 0
var player: Player
## The last act's boss fell this run (the rest is endless mode).
var has_won := false
## Souls already added to the profile for this run (victory, then death in endless mode).
var _souls_awarded := 0

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
	game_over_panel.continue_requested.connect(_on_continue_endless)
	game_over_panel.title_requested.connect(func() -> void:
		_set_paused(false)
		get_tree().change_scene_to_file(TITLE_SCENE))
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
	difficulty = content.get_difficulty(Profile.difficulty)
	if difficulty and not Profile.is_unlocked(difficulty):
		difficulty = content.default_difficulty
	world.difficulty = difficulty
	depth = 1
	kills = 0
	bosses_slain = 0
	has_won = false
	_souls_awarded = 0
	player = PLAYER_SCENE.instantiate() as Player
	player.setup(content.player)
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_player_leveled_up)
	player.damaged.connect(func(damage: int) -> void:
		screen_fx.kick(clampf(float(damage) / player.get_max_hp() * 5.0, 0.3, 1.0)))
	_apply_profile()
	Profile.count_run()
	hud.bind_player(player)
	_enter_floor()


## Shrine upgrades bought with souls: stats, starting items and perks, unlocked items.
func _apply_profile() -> void:
	content.unlocked_items.clear()
	for upgrade in content.upgrades:
		var level := Profile.level_of(upgrade)
		if level <= 0:
			continue
		match upgrade.kind:
			UpgradeDef.Kind.STATS:
				if upgrade.bonuses:
					player.base_stats = player.base_stats.plus(upgrade.bonuses.times(level))
			UpgradeDef.Kind.STARTING_ITEMS:
				for i in level:
					for item in upgrade.items:
						player.inventory.add(item)
			UpgradeDef.Kind.STARTING_PERK:
				if upgrade.perk:
					player.perks.add(upgrade.perk)
			UpgradeDef.Kind.UNLOCK:
				content.unlocked_items.append_array(upgrade.items)
	player.invalidate_stats()
	player.hp = player.get_max_hp()


## Adds this run's souls to the profile (only what was not added yet).
func _award_souls(won_now: bool) -> int:
	var total := Profile.souls_for_run(kills, depth, bosses_slain, has_won, difficulty.souls if difficulty else 1.0)
	var earned := total - _souls_awarded
	_souls_awarded = total
	Profile.record_run(earned, depth, won_now, difficulty.id if difficulty else &"")
	return earned


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
	if depth > 1 and difficulty and difficulty.heal_on_new_floor > 0.0:
		player.heal(roundi(player.get_max_hp() * difficulty.heal_on_new_floor))
	if world.theme:
		Sfx.play_music(world.theme.music)
	Events.depth_changed.emit(depth)
	var act := content.dungeon.act_for_depth(depth)
	if act and content.dungeon.floor_in_act(depth) == 1:
		# A new act: its name instead of the depth.
		hud.show_banner(act.title)
		Events.log_message("%s: %s" % [act.subtitle, act.title], Color("ffd166"))
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
	bosses_slain += 1
	hud.show_banner("Victory!")
	Sfx.play_ui(Sfx.bank.boss_defeated)
	Events.log_message("%s is defeated! The way down is open." % boss.display_name, Color("ffd166"))
	if world.theme:
		Sfx.play_music(world.theme.music)
	var def := boss.def as BossDef
	var winner := player
	await get_tree().create_timer(RELIC_DELAY, false).timeout
	if player != winner or player.is_dead:
		return  # the run ended in the meantime
	if content.dungeon.is_final_floor(depth) and not has_won:
		# The last boss: the run is won. Keep going offers the relic, then endless floors.
		has_won = true
		_set_paused(true)
		Sfx.play_ui(Sfx.bank.stairs)
		var earned := _award_souls(true)
		game_over_panel.show_victory(_run_summary() + _souls_text(earned))
		return
	_offer_relic(def)


func _offer_relic(def: BossDef) -> void:
	if def and def.relic_choices > 0:
		_queue_offer(PerkDef.Rarity.RARE, def.relic_choices, "Relic", "The boss left a relic behind. Choose one.")


func _on_continue_endless() -> void:
	_set_paused(false)
	var act := content.dungeon.act_for_depth(depth)
	Events.log_message("Endless mode: the dungeon goes on, harder and harder.", Color("ff6b6b"))
	_offer_relic(act.boss if act else null)


func _souls_text(earned: int) -> String:
	return "\n+%d souls (%d to spend at the shrine)" % [earned, Profile.souls]


func _run_summary() -> String:
	var act := content.dungeon.act_for_depth(depth)
	return "%s - %s, depth %d, level %d\n%d monsters slain, %d bosses" % [
		difficulty.display_name if difficulty else "Normal", act.title if act else "Dungeon", depth, player.level, kills, bosses_slain]


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
	var earned := _award_souls(false)
	game_over_panel.show_result(_run_summary() + _souls_text(earned))
