class_name Game
extends Node
## Runs a play session: creates the hero, moves between floors, offers perks and relics, pauses
## for menus and handles the end of the run. Main scene of the project.
## The run itself is a RunState; the profile's records follow it in RunRecords; perk choices
## wait in an OfferQueue; the panels live in GameMenus.

const PLAYER_SCENE := preload("res://src/entities/player/player.tscn")
const TITLE_SCENE := "res://src/ui/title/title_screen.tscn"
const PERK_CHOICES := 3
## Pause between the boss' death and the relic choice, to enjoy the explosions.
const RELIC_DELAY := 1.6
## Seconds of fade to black when taking the stairs.
const FADE_TIME := 0.3

## Set by the title screen's Continue button: pick up the saved run instead of starting one.
static var resume_requested := false
## Set by the title screen's Daily button: today's daily run (DailyRun) instead of a normal one.
static var daily_requested := false

@export var content: ContentDB
## Title cards on black (a new act, a curse). Tests turn them off to save time.
@export var show_act_cards := true

var run: RunState
var player: Player
var offers := OfferQueue.new()

## Shortcuts to the run.
var depth: int:
	get: return run.depth
	set(value): run.depth = value
var kills: int:
	get: return run.kills
	set(value): run.kills = value
var bosses_slain: int:
	get: return run.bosses_slain
	set(value): run.bosses_slain = value
var has_won: bool:
	get: return run.has_won
	set(value): run.has_won = value
var difficulty: DifficultyDef:
	get: return run.difficulty

## Between taking the stairs and the next floor showing: no menus, no saves, no second descent.
var _transitioning := false

@onready var world: World = $World
@onready var hud: Hud = $Hud
@onready var menus: GameMenus = $Menus
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
@onready var curse_card: CurseCard = $Fade/CurseCard

var _records := RunRecords.new()
## The bestiary challenges (how monsters are slain).
var _hunt := HuntTracker.new()
## The tutorial's hints, shown in `hint_box` (above the HUD, under the menus).
var tutorial := Tutorial.new()
var hint_box := HintBox.new()
## The run's in-game time (speedruns).
var run_timer := RunTimer.new()
## The trial of the Threshold, where a second life (Phoenix Feather) takes the hero.
var threshold := Threshold.new()
## The way to the hidden floor (its key, the sealed way, its boss' hoard).
var hidden := HiddenPassage.new()
## The hero took the hidden way: the next floor is the hidden one (same depth).
var _into_hidden := false


func _ready() -> void:
	if content.sounds:
		Sfx.bank = content.sounds
	_records.content = content
	add_child(_records)
	_hunt.content = content
	add_child(_hunt)
	_setup_tutorial()
	run_timer.name = "RunTimer"
	run_timer.hud = hud
	run_timer.is_counting = _is_clock_running
	add_child(run_timer)
	_setup_threshold()
	hidden.name = "HiddenPassage"
	hidden.game = self
	hidden.def = content.dungeon.hidden_floor
	add_child(hidden)  # (before the Game's own boss handler: its hoard is in the save)
	world.stairs_reached.connect(_on_stairs_reached)
	hud.bind_world(world)
	hud.inventory_requested.connect(open_inventory)
	hud.pause_requested.connect(open_pause_menu)
	hud.debug_requested.connect(open_debug)
	if menus.debug:
		menus.debug.closed.connect(_on_menu_closed)
	_connect_menus()
	_connect_events()
	var saved := RunSave.read() if resume_requested else {}
	var daily := daily_requested
	resume_requested = false
	daily_requested = false
	if saved.is_empty():
		start_run(daily)
	else:
		resume_run(saved)


func _connect_menus() -> void:
	pause_menu.content = content
	inventory_panel.content = content
	pause_menu.resume_requested.connect(func() -> void:
		pause_menu.hide()
		_on_menu_closed())
	pause_menu.quit_requested.connect(func() -> void:
		_save_run()
		_set_paused(false)
		Loader.go(TITLE_SCENE))
	pause_menu.abandon_requested.connect(func() -> void:
		pause_menu.hide()
		_set_paused(false)
		player.give_up())
	inventory_panel.closed.connect(_on_menu_closed)
	shop_panel.closed.connect(_on_menu_closed)
	menus.forge.closed.connect(_on_menu_closed)
	encounter_panel.closed.connect(_on_menu_closed)
	perk_panel.chosen.connect(_on_perk_chosen)
	perk_panel.reroll_requested.connect(_on_perk_reroll)
	perk_panel.banish_requested.connect(_on_perk_banish)
	game_over_panel.restart_requested.connect(start_run)
	game_over_panel.continue_requested.connect(_on_continue_endless)
	game_over_panel.title_requested.connect(func() -> void:
		_records.record_history()
		_set_paused(false)
		Loader.go(TITLE_SCENE))


func _connect_events() -> void:
	Events.shop_requested.connect(open_shop)
	Events.forge_requested.connect(open_forge)
	Events.encounter_requested.connect(open_encounter)
	Events.perk_offer_requested.connect(func(rarity: int, title: String, subtitle: String) -> void:
		_queue_offer(rarity as PerkDef.Rarity, PERK_CHOICES, title, subtitle))
	Events.soul_gathered.connect(func() -> void: hud.set_souls(run_souls(), true))
	Events.boss_started.connect(_on_boss_started)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.ambush_started.connect(func(_room: AmbushRoom) -> void:
		hud.show_banner(tr("Ambush!"), Palette.DANGER)
		Events.log_message(tr("It's a trap! Survive the waves."), Palette.DANGER))
	Events.ambush_cleared.connect(func(_room: AmbushRoom) -> void:
		Sfx.play_ui(Sfx.bank.boss_defeated)
		Events.log_message(tr("The room falls silent. A chest appears..."), Palette.GOLD))


# --- Runs --------------------------------------------------------------------

## `daily`: today's daily run (DailyRun) instead of a normal one.
func start_run(daily: bool = false) -> void:
	_begin_run({}, daily)


## Picks up a run saved by RunSave: same depth (a new floor), the hero as saved.
func resume_run(saved: Dictionary) -> void:
	_begin_run(saved)


func _begin_run(saved: Dictionary, daily: bool = false) -> void:
	if run and run.has_won:
		_records.record_history()  # leaving a won run for a new one
	threshold.abort()
	_set_paused(false)
	_fade.color.a = 0.0
	menus.hide_all()
	offers.clear()
	_transitioning = false
	_into_hidden = false
	if player:
		player.get_parent().remove_child(player)
		player.queue_free()

	world.rng.randomize()
	var day := DailyRun.today() if daily and saved.is_empty() else -1
	if day >= 0:
		world.rng.seed = DailyRun.seed_of(day)  # the same bosses all day
	run = RunState.create(content, saved, world.rng, day)
	if day >= 0:
		run.daily_official = not Profile.daily_played(day)
		if run.daily_official:
			Profile.start_daily(day)
	world.difficulty = run.difficulty
	world.run_bosses = run.bosses
	world.clear_floor()  # the last run's merchant must not pass its locked stock on
	world.floors_without_forge = int(saved.get("floors_without_forge", 0))
	world.kept_stock.clear()
	for saved_entry: Dictionary in saved.get("kept_stock", []):
		var item := LootRoller.from_data(saved_entry.get("item"))
		if item:
			world.kept_stock.append({ "item": item, "price": int(saved_entry.get("price", 1)), "locked": true })
	player = PLAYER_SCENE.instantiate() as Player
	player.setup(content.player)
	player.died.connect(_on_player_died)
	player.leveled_up.connect(func(level: int) -> void:
		_queue_offer(PerkDef.Rarity.COMMON, PERK_CHOICES, tr("Level %d!") % level, tr("Choose an upgrade")))
	player.damaged.connect(func(damage: int) -> void:
		screen_fx.kick(clampf(float(damage) / player.get_max_hp() * 5.0, 0.3, 1.0)))
	content.unlocked_items = ShrineUpgrades.unlocked_items(content)
	if saved.is_empty():
		if not run.is_daily():
			run.oath = sworn_oath(content)
		ShrineUpgrades.apply_to(player, content, run.difficulty, run.oath, null if run.is_daily() else picked_weapon(content))
		if run.is_daily():
			_give_daily_start()
		Profile.count_run()
	else:
		player.load_state(saved.get("player", {}))
		offers.load_data(saved.get("offers", []))
		world.restore_spent(saved.get("floor", {}))  # chests opened, stock bought before quitting
	# The tree's run rules and the oath's (gold, loot, the merchant, heals, crits, the minimap).
	world.boons = RunBoons.build(content, run.oath) if not run.is_daily() else RunBoons.new()
	player.healing_scale = world.boons.healing_scale
	player.crit_damage_bonus = world.boons.crit_damage_bonus
	_records.bind(run, player)
	run_timer.run = run
	_hunt.bind(player)
	hud.bind_player(player)
	tutorial.bind(player, world, hud)
	if show_act_cards:
		# Start on black: the first act's card, then the floor fades in.
		_fade.color.a = 1.0
		_set_paused(true)
		_transitioning = true
		_enter_floor(not saved.is_empty())
		await _show_cards()
		_transitioning = false
		_set_paused(is_menu_open())
		create_tween().tween_property(_fade, "color:a", 0.0, FADE_TIME * 1.5)
	else:
		_enter_floor(not saved.is_empty())
	tutorial.cue(&"run_start")
	_show_next_offer.call_deferred()  # choices left open in a saved run


## The run's time counts while playing and in the bag, the shop or a perk choice; not in the
## pause menu, nor while a floor loads (with its title cards), nor once the hero is dead.
func _is_clock_running() -> bool:
	return player != null and not player.is_dead and not _transitioning and not pause_menu.visible \
		and not game_over_panel.visible and not act_card.visible and not curse_card.visible


## The floor `floor_depth` is done: its split, against the record run's.
func _split(floor_depth: int) -> void:
	var time := run.split(floor_depth)
	var record := Profile.best_split(run.record_key(), floor_depth)
	hud.show_split(floor_depth, time, time - record if record > 0.0 else NAN)


func _setup_tutorial() -> void:
	tutorial.name = "Tutorial"
	tutorial.def = content.tutorial
	tutorial.box = hint_box
	tutorial.is_blocked = func() -> bool:
		return is_menu_open() or hud.is_banner_showing() or act_card.visible or curse_card.visible
	tutorial.hint_shown.connect(func(_hint: HintDef) -> void: hint_box.lowered = hud.is_boss_bar_showing())
	add_child(tutorial)
	var layer := CanvasLayer.new()
	layer.name = "Hints"
	layer.layer = 6  # above the HUD (5), under the menus (10)
	add_child(layer)
	hint_box.name = "HintBox"
	hint_box.dismissed.connect(tutorial.dismiss)
	layer.add_child(hint_box)


func _setup_threshold() -> void:
	threshold.name = "Threshold"
	threshold.game = self
	add_child(threshold)
	hud.bind_threshold(threshold)
	threshold.opened.connect(func(_trial: ThresholdDef, _needed: int, _seconds: float) -> void:
		tutorial.cue(&"threshold"))
	threshold.closed.connect(func(won: bool) -> void:
		if won:
			_show_next_offer())


## The daily run's weapon and relic (the same for everyone that day).
func _give_daily_start() -> void:
	var weapon := DailyRun.weapon(content, run.daily_day)
	if weapon:
		player.equipment.equip(weapon)
	var relic := DailyRun.relic(content, run.daily_day)
	if relic:
		player.perks.add(relic)
	player.invalidate_stats()
	player.hp = player.get_max_hp()


## The oath chosen for the next run (Profile.oath), if its node was bought; null otherwise.
static func sworn_oath(content: ContentDB) -> OathDef:
	if Profile.oath == &"" or content.soul_tree == null:
		return null
	for oath in content.soul_tree.open_oaths():
		if oath.id == Profile.oath:
			return oath
	return null


## The weapon picked to start with (the Armory node; any the dungeon holds), or null.
static func picked_weapon(content: ContentDB) -> WeaponDef:
	if Profile.starting_weapon == &"":
		return null
	for item in content.items + content.locked_items:
		if item is WeaponDef and item.id == Profile.starting_weapon:
			return item
	return null


## Souls this run is worth so far (what the shrine gets when it ends).
func run_souls() -> int:
	return run.souls()


func _award_souls(won_now: bool) -> int:
	var earned := run.award_souls(won_now, content.ascensions.size())
	if run.daily_official:
		Profile.finish_daily(run.daily_day, DailyRun.score(run))
	_records.check_achievements()
	return earned


# --- Menus -------------------------------------------------------------------

func is_menu_open() -> bool:
	return _transitioning or menus.any_open()


func open_encounter(encounter: Encounter) -> void:
	if _can_open_menu():
		Sfx.play_ui(Sfx.bank.ui_open)
		_set_paused(true)
		encounter_panel.open(encounter, player)


func open_shop(merchant: Merchant) -> void:
	if _can_open_menu():
		Sfx.play_ui(Sfx.bank.ui_open)
		_set_paused(true)
		shop_panel.open(merchant, player)


func open_forge(forge: Forge) -> void:
	if _can_open_menu():
		Sfx.play_ui(Sfx.bank.ui_open)
		_set_paused(true)
		menus.forge.open(forge, player)


func open_pause_menu() -> void:
	if _can_open_menu() and not act_card.visible and not curse_card.visible:
		Sfx.play_ui(Sfx.bank.ui_open)
		_set_paused(true)
		pause_menu.open()


## Not during the trial of the Threshold (a fight against the clock).
func open_inventory() -> void:
	if _can_open_menu() and not threshold.is_open():
		_set_paused(true)
		inventory_panel.open(player)
		tutorial.action(&"opened_bag")


## Dev tools (debug builds only).
func open_debug() -> void:
	if menus.debug and _can_open_menu():
		_set_paused(true)
		menus.debug.open(self)


## Debug: builds floor `target` right away, with that curse or event (or a plain floor).
func debug_enter_floor(target: int, curse: CurseDef = null, event: FloorEventDef = null, plain: bool = false) -> void:
	world.forced_curse = curse
	world.forced_event = event
	world.forced_plain = plain or (curse == null and event == null)
	threshold.abort()
	depth = target
	_transitioning = true
	_enter_floor(true)
	await _show_cards()
	_transitioning = false
	_set_paused(is_menu_open())
	_show_next_offer()


func _can_open_menu() -> bool:
	return player != null and not player.is_dead and not is_menu_open()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_F1:
		get_viewport().set_input_as_handled()
		open_debug()
	elif event.is_action_pressed("inventory") and not is_menu_open():
		get_viewport().set_input_as_handled()
		open_inventory()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


## Escape or the phone's back button: closes what is open, or pauses.
func _back() -> void:
	if not menus.back() and not is_menu_open():
		open_pause_menu()


## Resumes the game, or shows the next perk choice if one is waiting.
func _on_menu_closed() -> void:
	if player and player.is_dead:
		return  # the end of the run takes it from here
	_set_paused(is_menu_open())
	_show_next_offer()


func _set_paused(paused: bool) -> void:
	HitStop.reset()
	get_tree().paused = paused


# --- Floors ------------------------------------------------------------------

## `resumed`: picking a saved run back up (no free heal for quitting and coming back).
func _enter_floor(resumed: bool = false) -> void:
	if run.is_daily():
		world.rng.seed = DailyRun.floor_seed(run.daily_day, depth)  # the same floors all day
	else:
		world.rng.seed = hash("%d-floor-%d" % [run.seed, depth])  # quitting can't reroll a floor
	if run.hidden_floor:
		world.rng.seed = hash("hidden-%d" % world.rng.seed)  # not the boss floor of the same depth
	world.hidden_floor = content.dungeon.hidden_floor if run.hidden_floor else null
	world.hidden_floor_done = run.hidden_done
	world.next_routes = FloorRoute.offer(content, depth + 1, difficulty, run.route_seed(depth + 1))
	world.build_floor(depth, content, _route_to(depth))
	world.place_player(player)
	play_floor_mood()
	if not resumed and depth > 1 and difficulty.heal_on_new_floor > 0.0:
		player.heal(roundi(player.get_max_hp() * difficulty.heal_on_new_floor))
	_save_run()
	if run.difficulty.counts_feats:
		Profile.best_depth = maxi(Profile.best_depth, depth)
	_records.check_achievements()
	Events.depth_changed.emit(depth)
	hud.set_souls(run_souls())
	_announce_floor()
	tutorial.cue(&"floor_start")
	if world.curse:
		tutorial.cue(&"cursed_floor")
	if world.floor_event:
		tutorial.cue(&"event_floor")


## The floor's sound and look (its biome, its curse or event), and its music (the boss' during
## its fight). Also when the hero comes back from the Threshold.
func play_floor_mood() -> void:
	var mood := world.theme.ambience if world.theme else null
	if world.curse and world.curse.ambience:
		mood = world.curse.ambience
	ambience.play(mood, world, player, world.floor_event.atmosphere if world.floor_event else null)
	var boss_def := world.arena.boss.def as BossDef if world.is_boss_fight() else null
	if boss_def:
		Sfx.play_music(boss_def.music if boss_def.music else Sfx.bank.boss_music)
	elif world.theme:
		Sfx.play_music(world.theme.music)


## The log (and banners when the cards are off): the act, the floor's event or curse, the goal.
func _announce_floor() -> void:
	var act := content.dungeon.act_for_depth(depth)
	if act and content.dungeon.floor_in_act(depth) == 1:
		if not show_act_cards:
			hud.show_banner(tr(act.title))
		Events.log_message(tr("%s: %s") % [tr(act.subtitle), tr(act.title)], Palette.GOLD)
	if world.floor_event:
		hud.show_banner(tr(world.floor_event.display_name), world.floor_event.color)
		Events.log_message(tr(world.floor_event.description), world.floor_event.color)
	if world.curse:
		if not show_act_cards:
			hud.show_banner(tr(world.curse.display_name), world.curse.color)
		Events.log_message(tr("Cursed: %s. %s") % [tr(world.curse.display_name), tr(world.curse.description)], world.curse.color)
	if world.hidden_floor:
		hud.show_banner(tr(world.hidden_floor.title), world.hidden_floor.color)
		Events.log_message(tr(world.hidden_floor.lore), world.hidden_floor.color)
	if world.arena:
		Events.log_message(tr("Depth %d. Something vast waits in the dark...") % depth, Palette.DANGER)
	elif world.seal.is_sealed():
		Events.log_message(tr("Depth %d. The stairs are sealed: slay %d monsters to open them.") % [depth, world.seal.needed], Palette.SEAL)
	else:
		Events.log_message(tr("Depth %d. Find the stairs!") % depth, Palette.GOLD)


## The way the hero took to floor `floor_depth`, or null (no choice there).
func _route_to(floor_depth: int) -> FloorRoute:
	if not run.routes.has(floor_depth):
		return null
	var offered := FloorRoute.offer(content, floor_depth, difficulty, run.route_seed(floor_depth))
	var index: int = run.routes[floor_depth]
	return offered[index] if index >= 0 and index < offered.size() else null


func _on_stairs_reached(route: int = 0) -> void:
	if _transitioning or player == null or player.is_dead:
		return
	_into_hidden = route == HiddenPassage.ROUTE
	if _into_hidden:
		hidden.spend_key()
	elif world.next_routes.size() >= 2:
		run.routes[depth + 1] = clampi(route, 0, world.next_routes.size() - 1)
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
	if run.finish_time < 0.0 and not run.hidden_floor:
		_split(depth)  # (the hidden floor's time goes to the next floor's split)
	# The hidden floor keeps the depth of the boss before it (RunState.hidden_floor).
	run.hidden_floor = _into_hidden
	_into_hidden = false
	if not run.hidden_floor:
		depth += 1  # only now: a save during the fade still points at the floor being left
	_enter_floor()
	await _show_cards()
	_transitioning = false
	_set_paused(is_menu_open())
	_show_next_offer()
	create_tween().tween_property(_fade, "color:a", 0.0, FADE_TIME * 1.5)


## Over black, with cards on: the act's title card on its first floor, then the curse's card
## on a cursed floor.
func _show_cards() -> void:
	if not show_act_cards:
		return
	var act := content.dungeon.act_for_depth(depth)
	if world.hidden_floor:
		await act_card.play(world.hidden_floor.as_act())
	elif act and content.dungeon.floor_in_act(depth) == 1:
		await act_card.play(act)
	if world.curse:
		await curse_card.play(world.curse)


# --- Bosses ------------------------------------------------------------------

func _on_boss_started(boss: Monster) -> void:
	var def := boss.def as BossDef
	hud.show_banner(tr(boss.display_name), Palette.DANGER)
	if def and not def.title.is_empty():
		Events.log_message("%s, %s" % [tr(boss.display_name), tr(def.title)], Palette.DANGER)
	var music := def.music if def and def.music else Sfx.bank.boss_music
	if music:
		Sfx.play_music(music)


func _on_boss_defeated(boss: Monster) -> void:
	run.bosses_slain += 1
	if content.dungeon.rerolls_per_boss > 0:
		run.rerolls += content.dungeon.rerolls_per_boss
		Events.log_message(tr("+%d reroll for the perk choices.") % content.dungeon.rerolls_per_boss, Palette.GOLD)
	hud.show_banner(tr("Victory Achieved"))
	Sfx.play_ui(Sfx.bank.boss_defeated)
	Events.log_message(tr("%s falls. The way down lies open.") % tr(boss.display_name), Palette.GOLD)
	if world.theme:
		Sfx.play_music(world.theme.music)
	var def := boss.def as BossDef
	run.last_boss = def
	var winner := player
	# Decided now, not after the pause: the stairs are already there, and a save (app put away)
	# in between must keep the win or the relic.
	var won_now := content.dungeon.is_final_floor(depth) and not run.has_won
	var earned := 0
	var new_record := false
	if won_now:
		run.has_won = true
		run.finish_time = run.time
		_split(depth)
		new_record = Profile.record_time(run.record_key(), run.finish_time, run.splits)
		if new_record:
			Events.log_message(tr("New record: %s!") % TimeText.of(run.finish_time), Palette.GOLD)
		earned = _award_souls(true)
	else:
		offers.add_relic(def, boss.rank.extra_relics if boss.rank else 0)
	_save_run()
	await get_tree().create_timer(RELIC_DELAY, false).timeout
	if player != winner or player.is_dead:
		return  # the run ended in the meantime
	if won_now:
		# The last boss: the run is won. Keep going offers the relic, then endless floors.
		_set_paused(true)
		Sfx.play_ui(Sfx.bank.stairs)
		menus.show_on_top(game_over_panel)
		_show_end(true, earned, new_record)
		return
	_show_next_offer()


func _on_continue_endless() -> void:
	_set_paused(false)
	Events.log_message(tr("Endless mode: the dungeon goes on, harder and harder."), Palette.DANGER)
	offers.add_relic(run.last_boss)
	_show_next_offer()


## Beside a win's time: a new record, or the record to beat.
func _record_text(new_record: bool) -> String:
	if new_record:
		return tr("New record!")
	var record := Profile.best_time(run.record_key())
	return tr("(record %s)") % TimeText.of(record) if record > 0.0 else ""


## The end-of-run screen: how it ended (a line of the story), the run's numbers, the souls.
func _show_end(victory: bool, earned: int, new_record: bool = false) -> void:
	var story := ""
	if content.story:
		story = tr(content.story.victory_text if victory else content.story.random_death_line())
	var rows := run.summary_rows(content, player.level, _record_text(new_record) if victory else "")
	game_over_panel.show_end(victory, story, rows, earned, Profile.souls)


# --- Perks -------------------------------------------------------------------

func _queue_offer(rarity: PerkDef.Rarity, count: int, title: String, subtitle: String) -> void:
	offers.add(rarity, count, title, subtitle)
	# Deferred: level ups happen in the middle of combat code.
	_show_next_offer.call_deferred()


func _show_next_offer() -> void:
	while not offers.is_empty():
		if is_menu_open() or player == null or player.is_dead or threshold.is_open():
			return
		var offer := offers.pop()
		var perks := _pick_offer(offer.count, offer.rarity, [])
		if perks.is_empty():
			continue  # everything is maxed out
		offers.shown = offer
		_set_paused(true)
		perk_panel.open(offer.title, offer.subtitle, perks, player.perks, run.rerolls, run.banishes)
		return


## Perks for an offer: never banished ones nor `also_left_out`, leaning toward started families.
func _pick_offer(count: int, rarity: PerkDef.Rarity, also_left_out: Array[PerkDef]) -> Array[PerkDef]:
	var left_out: Array[PerkDef] = run.banished.duplicate()
	left_out.append_array(also_left_out)
	return content.pick_perks(player.perks, count, rarity, world.rng, left_out, content.dungeon.family_bias)


## Three new cards (others than those on the table, when there are enough).
func _on_perk_reroll() -> void:
	var shown := offers.shown
	if shown == null or run.rerolls <= 0:
		return
	var current := perk_panel.get_offered()
	var fresh := _pick_offer(current.size(), shown.rarity, current)
	if fresh.is_empty():
		Events.log_message(tr("Nothing else to offer."), Palette.DANGER)
		return
	run.rerolls -= 1
	perk_panel.set_charges(run.rerolls, run.banishes)
	perk_panel.show_cards(fresh)
	Sfx.play_ui(Sfx.bank.ui_open)


## The perk on card `index` is gone for the run; another takes its place (if any is left).
func _on_perk_banish(index: int) -> void:
	var shown := offers.shown
	var current := perk_panel.get_offered()
	if shown == null or run.banishes <= 0 or index < 0 or index >= current.size():
		return
	var gone := current[index]
	run.banishes -= 1
	run.banished.append(gone)
	Events.log_message(tr("%s is banished for this run.") % tr(gone.display_name), Palette.DANGER)
	var cards: Array[PerkDef] = current.duplicate()
	var replacement := _pick_offer(1, shown.rarity, current)
	if replacement.is_empty():
		cards.remove_at(index)
	else:
		cards[index] = replacement[0]
	perk_panel.set_charges(run.rerolls, run.banishes)
	if cards.is_empty():
		perk_panel.hide()
		offers.shown = null
		_on_menu_closed()
		return
	perk_panel.show_cards(cards)


func _on_perk_chosen(perk: PerkDef) -> void:
	offers.shown = null
	player.perks.add(perk)
	Events.log_message(tr("%s (level %d)") % [tr(perk.display_name), player.perks.stacks_of(perk)], perk.color)
	Vfx.sparkles(world, player.global_position, perk.color)
	tutorial.cue(&"perk_chosen")
	_on_menu_closed()


# --- End of the run -------------------------------------------------------------

func _on_player_died(_actor: Actor) -> void:
	RunSave.erase()
	offers.clear()
	# Souls and history right away (the app may be closed during the pause below).
	var earned := _award_souls(false)
	_records.record_history()
	Profile.save_profile()
	await get_tree().create_timer(1.2).timeout
	Sfx.play_ui(Sfx.bank.game_over)
	menus.show_on_top(game_over_panel)
	_show_end(false, earned)


# --- Saving ------------------------------------------------------------------

## Saves the run (see RunSave). Called when a floor begins and when the app is put away.
## Never during the trial of the Threshold: picked up again, the run is as it was before the
## killing blow.
func _save_run() -> void:
	if player == null or player.is_dead or run == null or threshold.is_open():
		return
	var data := run.to_data()
	data.boss_slain = world.arena != null and world.arena.is_defeated
	data.player = player.save_state()
	data.offers = offers.to_data(perk_panel.visible)
	data.floors_without_forge = world.forge_drought_at_start
	data.floor = world.spent_data()
	data.kept_stock = world.locked_stock().map(func(entry: Dictionary) -> Dictionary:
		return { "item": LootRoller.to_data(entry.item), "price": entry.price })
	RunSave.write(data)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			_save_run()
			Profile.save_profile()  # kills and stats since the last save
			# Coming back to the phone (or from the notification shade, a call), the game waits on
			# the pause menu.
			# (On a computer, clicking another window must not stop the game.)
			if what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile")):
				open_pause_menu()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_back()
