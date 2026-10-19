class_name Game
extends Node
## Runs a play session: creates the player, moves between floors, offers perks and relics,
## pauses for menus and handles game over. Main scene of the project.

const PLAYER_SCENE := preload("res://src/entities/player/player.tscn")
const TITLE_SCENE := "res://src/ui/title/title_screen.tscn"
const PERK_CHOICES := 3
## Pause between the boss' death and the relic choice, to enjoy the explosions.
const RELIC_DELAY := 1.6
## Seconds of fade to black when taking the stairs.
const FADE_TIME := 0.3

## Set by the title screen's Continue button: pick up the saved run instead of starting one.
static var resume_requested := false

@export var content: ContentDB
## A title card on black when an act begins (tests turn it off to save time).
@export var show_act_cards := true

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
## The choice on screen right now (saved with the run if the app closes meanwhile).
var _shown_offer := {}
## Gold picked up this run (for the records), and the purse a moment ago.
var _run_gold := 0
var _last_gold := 0
## The run is in the history already (a won run is recorded once, when it ends).
var _history_recorded := false
## Between taking the stairs and the next floor showing: no menus, no saves, no second descent.
var _transitioning := false
## The boss of the last cleared boss floor (its relic, in endless mode).
var _last_boss: BossDef

@onready var world: World = $World
@onready var hud: Hud = $Hud
@onready var inventory_panel: InventoryPanel = $Menus/InventoryPanel
@onready var perk_panel: PerkChoicePanel = $Menus/PerkChoicePanel
@onready var game_over_panel: GameOverPanel = $Menus/GameOverPanel
@onready var pause_menu: PauseMenu = $Menus/PauseMenu
@onready var shop_panel: ShopPanel = $Menus/ShopPanel
@onready var encounter_panel: EncounterPanel = $Menus/EncounterPanel
@onready var screen_fx: ScreenEffects = $ScreenFx/Effects
@onready var ambience: Ambience = $Ambience
@onready var _fade: ColorRect = $Fade/Black
@onready var act_card: ActCard = $Fade/ActCard


func _ready() -> void:
	if content.sounds:
		Sfx.bank = content.sounds
	world.stairs_reached.connect(_on_stairs_reached)
	hud.bind_world(world)
	hud.inventory_requested.connect(open_inventory)
	hud.pause_requested.connect(open_pause_menu)
	pause_menu.resume_requested.connect(func() -> void:
		pause_menu.hide()
		_on_menu_closed())
	pause_menu.quit_requested.connect(func() -> void:
		_save_run()
		_set_paused(false)
		get_tree().change_scene_to_file(TITLE_SCENE))
	pause_menu.abandon_requested.connect(func() -> void:
		pause_menu.hide()
		_set_paused(false)
		player._invulnerable_time = 0.0
		player.perks.clear()  # no last-second save from a relic
		player.take_hit(Combat.make_secondary_hit(null, player.get_max_hp() * 100)))
	inventory_panel.closed.connect(_on_menu_closed)
	shop_panel.closed.connect(_on_menu_closed)
	Events.shop_requested.connect(open_shop)
	encounter_panel.closed.connect(_on_menu_closed)
	Events.encounter_requested.connect(open_encounter)
	Events.perk_offer_requested.connect(func(rarity: int, title: String, subtitle: String) -> void:
		_queue_offer(rarity as PerkDef.Rarity, PERK_CHOICES, title, subtitle))
	perk_panel.chosen.connect(_on_perk_chosen)
	game_over_panel.restart_requested.connect(start_run)
	game_over_panel.continue_requested.connect(_on_continue_endless)
	game_over_panel.title_requested.connect(func() -> void:
		_record_history()
		_set_paused(false)
		get_tree().change_scene_to_file(TITLE_SCENE))
	Events.monster_killed.connect(_on_monster_killed)
	Events.stat_counted.connect(func(stat: String, amount: int) -> void:
		Profile.add_stat(stat, amount)
		_check_achievements())
	Events.soul_gathered.connect(func() -> void: hud.set_souls(run_souls(), true))
	Events.boss_started.connect(_on_boss_started)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.ambush_started.connect(func(_room: AmbushRoom) -> void:
		hud.show_banner("Ambush!", Color("ff6b6b"))
		Events.log_message("It's a trap! Survive the waves.", Color("ff6b6b")))
	Events.ambush_cleared.connect(func(_room: AmbushRoom) -> void:
		Sfx.play_ui(Sfx.bank.boss_defeated)
		Events.log_message("The room falls silent. A chest appears...", Color("ffd166")))
	var saved := RunSave.read() if resume_requested else {}
	resume_requested = false
	if saved.is_empty():
		start_run()
	else:
		resume_run(saved)


func start_run() -> void:
	_begin_run({})


## Picks up a run saved by RunSave: same depth (a new floor), the hero as saved.
func resume_run(saved: Dictionary) -> void:
	_begin_run(saved)


func _begin_run(saved: Dictionary) -> void:
	if has_won:
		_record_history()  # leaving a won run for a new one
	_set_paused(false)
	_fade.color.a = 0.0
	game_over_panel.hide()
	inventory_panel.hide()
	shop_panel.hide()
	encounter_panel.hide()
	perk_panel.hide()
	_pending_offers.clear()
	_shown_offer = {}
	_transitioning = false
	if player:
		player.get_parent().remove_child(player)
		player.queue_free()

	world.rng.randomize()
	difficulty = content.get_difficulty(StringName(saved.get("difficulty", Profile.difficulty)))
	if difficulty == null or not Profile.is_unlocked(difficulty):
		difficulty = content.default_difficulty  # never null from here on
	var ascension := int(saved.get("ascension", Profile.ascension if saved.is_empty() else 0))
	if difficulty.has_ascensions and ascension > 0:
		difficulty = AscensionDef.apply_levels(difficulty, content.ascensions, mini(ascension, Profile.ascension_unlocked))
	world.difficulty = difficulty
	world.run_bosses = _load_bosses(saved.get("bosses", [])) if saved.has("bosses") else _draw_bosses()
	depth = int(saved.get("depth", 1))
	if saved.get("boss_slain", false):
		depth += 1  # saved after the floor's boss died: on to the next floor
	kills = int(saved.get("kills", 0))
	bosses_slain = int(saved.get("bosses_slain", 0))
	has_won = bool(saved.get("has_won", false))
	_souls_awarded = int(saved.get("souls_awarded", 0))
	_run_gold = int(saved.get("run_gold", 0))
	_history_recorded = bool(saved.get("history_recorded", false))
	player = PLAYER_SCENE.instantiate() as Player
	player.setup(content.player)
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_player_leveled_up)
	player.damaged.connect(func(damage: int) -> void:
		screen_fx.kick(clampf(float(damage) / player.get_max_hp() * 5.0, 0.3, 1.0)))
	_apply_unlocks()
	if saved.is_empty():
		_apply_profile()
		Profile.count_run()
	else:
		player.load_state(saved.get("player", {}))
		for offer: Dictionary in saved.get("offers", []):
			offer.rarity = int(offer.get("rarity", 0))
			offer.count = int(offer.get("count", PERK_CHOICES))
			_pending_offers.append(offer)
	_last_gold = player.gold
	player.gold_changed.connect(_on_gold_changed)  # after loading: the saved purse is not new gold
	hud.bind_player(player)
	if show_act_cards:
		# Start on black: the first act's card, then the floor fades in.
		_fade.color.a = 1.0
		_set_paused(true)
		_transitioning = true
		_enter_floor(not saved.is_empty())
		await _show_act_card()
		_transitioning = false
		_set_paused(is_menu_open())
		create_tween().tween_property(_fade, "color:a", 0.0, FADE_TIME * 1.5)
	else:
		_enter_floor(not saved.is_empty())
	_show_next_offer.call_deferred()  # choices left open in a saved run


## One boss per act for this run, drawn among the act's bosses.
func _draw_bosses() -> Array:
	var result := []
	for act in content.dungeon.acts:
		var bosses := act.all_bosses()
		result.append(bosses[world.rng.randi_range(0, bosses.size() - 1)] if not bosses.is_empty() else null)
	return result


func _load_bosses(saved: Array) -> Array:
	return saved.map(func(reference: Variant) -> Resource: return RunSave.load_ref(reference))


## Items the shrine unlocked can be found in the dungeon.
func _apply_unlocks() -> void:
	content.unlocked_items.clear()
	for upgrade in content.upgrades:
		if upgrade.kind == UpgradeDef.Kind.UNLOCK and Profile.level_of(upgrade) > 0:
			content.unlocked_items.append_array(upgrade.items)


## Shrine upgrades bought with souls for a new run: stats, starting items and perks.
func _apply_profile() -> void:
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
						player.store(item)
			UpgradeDef.Kind.STARTING_PERK:
				if upgrade.perk:
					player.perks.add(upgrade.perk)
	if difficulty.hero_max_hp != 1.0:
		player.base_stats.max_hp = roundi(player.base_stats.max_hp * difficulty.hero_max_hp)
	player.invalidate_stats()
	player.hp = player.get_max_hp()


## Souls this run is worth so far (what the shrine gets when it ends).
func run_souls() -> int:
	return Profile.souls_for_run(kills, depth, bosses_slain, has_won, difficulty.souls)


## Adds this run's souls to the profile (only what was not added yet).
func _award_souls(won_now: bool) -> int:
	var total := run_souls()
	var earned := total - _souls_awarded
	_souls_awarded = total
	Profile.record_run(earned, depth, won_now, difficulty.id)
	if won_now and difficulty.has_ascensions:
		Profile.win_ascension(difficulty.ascension, content.ascensions.size())
	_check_achievements()
	return earned


func is_menu_open() -> bool:
	return _transitioning or inventory_panel.visible or perk_panel.visible or game_over_panel.visible or pause_menu.visible \
		or shop_panel.visible or encounter_panel.visible


func open_encounter(encounter: Encounter) -> void:
	if player == null or player.is_dead or is_menu_open():
		return
	Sfx.play_ui(Sfx.bank.ui_open)
	_set_paused(true)
	encounter_panel.open(encounter, player)


func open_shop(merchant: Merchant) -> void:
	if player == null or player.is_dead or is_menu_open():
		return
	Sfx.play_ui(Sfx.bank.ui_open)
	_set_paused(true)
	shop_panel.open(merchant, player)


func open_pause_menu() -> void:
	if player == null or player.is_dead or is_menu_open() or act_card.visible:
		return
	Sfx.play_ui(Sfx.bank.ui_open)
	_set_paused(true)
	pause_menu.open()


func open_inventory() -> void:
	if player == null or player.is_dead or is_menu_open():
		return
	_set_paused(true)
	inventory_panel.open(player)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and not is_menu_open():
		get_viewport().set_input_as_handled()
		open_inventory()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


## Escape or the phone's back button: closes what is open, or pauses.
func _back() -> void:
	if pause_menu.visible:
		pause_menu.back()
	elif inventory_panel.visible:
		inventory_panel.close()
	elif shop_panel.visible:
		shop_panel.close()
	elif encounter_panel.visible:
		encounter_panel.close()
	elif not is_menu_open():
		open_pause_menu()


func _set_paused(paused: bool) -> void:
	HitStop.reset()
	get_tree().paused = paused


# --- Floors ------------------------------------------------------------------

## `resumed`: picking a saved run back up (no free heal for quitting and coming back).
func _enter_floor(resumed: bool = false) -> void:
	world.build_floor(depth, content)
	world.place_player(player)
	var mood := world.theme.ambience if world.theme else null
	if world.floor_event and world.floor_event.ambience:
		mood = world.floor_event.ambience
	ambience.play(mood, world, player)
	if not resumed and depth > 1 and difficulty.heal_on_new_floor > 0.0:
		player.heal(roundi(player.get_max_hp() * difficulty.heal_on_new_floor))
	if world.theme:
		Sfx.play_music(world.theme.music)
	_save_run()
	Profile.best_depth = maxi(Profile.best_depth, depth)
	_check_achievements()
	Events.depth_changed.emit(depth)
	hud.set_souls(run_souls())
	var act := content.dungeon.act_for_depth(depth)
	if act and content.dungeon.floor_in_act(depth) == 1:
		# A new act: its name instead of the depth (on its own card, see _show_act_card()).
		if not show_act_cards:
			hud.show_banner(act.title)
		Events.log_message("%s: %s" % [act.subtitle, act.title], Color("ffd166"))
	if world.floor_event:
		hud.show_banner(world.floor_event.display_name, world.floor_event.color)
		Events.log_message(world.floor_event.description, world.floor_event.color)
	if world.arena:
		Events.log_message("Depth %d. Something big is waiting..." % depth, Color("ff6b6b"))
	else:
		Events.log_message("Depth %d. Find the stairs!" % depth, Color("ffd166"))


func _on_stairs_reached() -> void:
	if _transitioning or player == null or player.is_dead:
		return
	Sfx.play_ui(Sfx.bank.stairs)
	_transitioning = true
	# Fade to black, build the next floor, fade back in.
	# (Deferred: we are inside a physics callback, where the level can't be rebuilt.)
	_descend.call_deferred()


func _descend() -> void:
	_set_paused(true)
	var fade_out := create_tween()
	fade_out.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	await fade_out.finished
	depth += 1  # only now: a save during the fade still points at the floor being left
	_enter_floor()
	await _show_act_card()
	_transitioning = false
	_set_paused(is_menu_open())
	_show_next_offer()
	create_tween().tween_property(_fade, "color:a", 0.0, FADE_TIME * 1.5)


## On the first floor of an act (and with cards on): its title card, over black.
func _show_act_card() -> void:
	var act := content.dungeon.act_for_depth(depth)
	if show_act_cards and act and content.dungeon.floor_in_act(depth) == 1:
		await act_card.play(act)


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
	_last_boss = def
	var winner := player
	# Decided now, not after the pause: the stairs are already there, and a save (app put away)
	# in between must keep the win or the relic.
	var won_now := content.dungeon.is_final_floor(depth) and not has_won
	var earned := 0
	if won_now:
		has_won = true
		earned = _award_souls(true)
	elif def and def.relic_choices > 0:
		_pending_offers.append(_relic_offer(def))
	_save_run()
	await get_tree().create_timer(RELIC_DELAY, false).timeout
	if player != winner or player.is_dead:
		return  # the run ended in the meantime
	if won_now:
		# The last boss: the run is won. Keep going offers the relic, then endless floors.
		_set_paused(true)
		Sfx.play_ui(Sfx.bank.stairs)
		var story := content.story.victory_text + "\n\n" if content.story else ""
		_show_on_top(game_over_panel)
		game_over_panel.show_victory(story + _run_summary() + _souls_text(earned))
		return
	_show_next_offer()


func _relic_offer(def: BossDef) -> Dictionary:
	return { "rarity": PerkDef.Rarity.RARE, "count": def.relic_choices, "title": "Relic", "subtitle": "The boss left a relic behind. Choose one." }


func _on_continue_endless() -> void:
	_set_paused(false)
	Events.log_message("Endless mode: the dungeon goes on, harder and harder.", Color("ff6b6b"))
	if _last_boss and _last_boss.relic_choices > 0:
		_pending_offers.append(_relic_offer(_last_boss))
	_show_next_offer()


## Closes whatever is open and puts `panel` above everything (game over, victory).
func _show_on_top(panel: Control) -> void:
	for other: Control in [inventory_panel, shop_panel, encounter_panel, perk_panel, pause_menu]:
		other.hide()
	panel.move_to_front()


func _souls_text(earned: int) -> String:
	return "\n+%d souls (%d to spend at the shrine)" % [earned, Profile.souls]


func _run_summary() -> String:
	var act := content.dungeon.act_for_depth(depth)
	return "%s - %s, depth %d, level %d\n%d monsters slain, %d bosses" % [
		difficulty.display_name, act.title if act else "Dungeon", depth, player.level, kills, bosses_slain]


# --- Perks -------------------------------------------------------------------

func _on_player_leveled_up(level: int) -> void:
	Profile.raise_stat("run_level", level)
	_check_achievements()
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
		_shown_offer = offer
		_set_paused(true)
		perk_panel.open(offer.title, offer.subtitle, perks, player.perks)
		return


func _on_perk_chosen(perk: PerkDef) -> void:
	_shown_offer = {}
	player.perks.add(perk)
	Events.log_message("%s (level %d)" % [perk.display_name, player.perks.stacks_of(perk)], perk.color)
	Vfx.sparkles(world, player.global_position, perk.color)
	_on_menu_closed()


## Resumes the game, or shows the next perk choice if one is waiting.
func _on_menu_closed() -> void:
	if player and player.is_dead:
		return  # the game over screen takes it from here
	_set_paused(is_menu_open())
	_show_next_offer()


func _on_player_died(_actor: Actor) -> void:
	RunSave.erase()
	_pending_offers.clear()
	# Souls and history right away (the app may be closed during the pause below).
	var earned := _award_souls(false)
	_record_history()
	Profile.save_profile()
	await get_tree().create_timer(1.2).timeout
	Sfx.play_ui(Sfx.bank.game_over)
	var story := content.story.random_death_line() + "\n\n" if content.story else ""
	_show_on_top(game_over_panel)
	game_over_panel.show_result(story + _run_summary() + _souls_text(earned))


# --- Saving ------------------------------------------------------------------

## Saves the run (see RunSave). Called when a floor begins and when the app is put away.
func _save_run() -> void:
	if player == null or player.is_dead:
		return
	var offers: Array[Dictionary] = []
	if perk_panel.visible and not _shown_offer.is_empty():
		offers.append(_shown_offer)
	offers.append_array(_pending_offers)
	RunSave.write({
		"depth": depth,
		"kills": kills,
		"bosses_slain": bosses_slain,
		"has_won": has_won,
		"boss_slain": world.arena != null and world.arena.is_defeated,
		"souls_awarded": _souls_awarded,
		"run_gold": _run_gold,
		"history_recorded": _history_recorded,
		"bosses": RunSave.refs(world.run_bosses),
		"difficulty": String(difficulty.id),
		"ascension": difficulty.ascension,
		"player": player.save_state(),
		"offers": offers,
	})


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			_save_run()
			Profile.save_profile()  # kills and stats since the last save
			# Coming back to the phone, the game waits on the pause menu.
			if what == NOTIFICATION_APPLICATION_PAUSED:
				open_pause_menu()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_back()


# --- Records -----------------------------------------------------------------

func _on_monster_killed(monster: Monster) -> void:
	kills += 1
	Profile.record_kill(monster.def.id)
	Profile.add_stat("kills")
	if monster.is_elite():
		Profile.add_stat("elites")
	if monster.is_boss():
		Profile.add_stat("bosses")
	if monster.has_fallen() and monster.last_attacker is Player:
		Profile.add_stat("pushed")
	_check_achievements()


func _on_gold_changed(gold: int) -> void:
	if gold > _last_gold:
		_run_gold += gold - _last_gold
		Profile.raise_stat("run_gold", _run_gold)
		_check_achievements()
	_last_gold = gold


## Unlocks (and pays) every achievement whose goal is reached.
func _check_achievements() -> void:
	for achievement in AchievementDef.unlock_reached(content.achievements):
		Events.achievement_unlocked.emit(achievement)


## Adds this run to the history (once).
func _record_history() -> void:
	if _history_recorded or player == null:
		return
	_history_recorded = true
	var weapon := player.get_weapon()
	Profile.add_history({
		"difficulty": difficulty.display_name,
		"depth": depth,
		"level": player.level,
		"kills": kills,
		"bosses": bosses_slain,
		"won": has_won,
		"souls": _souls_awarded,
		"weapon": weapon.display_name if weapon else "Bare hands",
		"cause": player.killed_by if player.is_dead else "",
	})
