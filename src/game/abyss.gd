class_name Abyss
extends Node
## Runs the Deeps (AbyssDef) for the Game. When the hero falls into a hole on a floor (Player asks
## `can_take()` at the bottom of his fall), he does not climb out: the floor freezes where it is
## (SubWorld: its monsters, a pact's fight, the shots in the air wait), the veil falls, and he
## lands deeper in the Well, in an AbyssWorld built beside the floor, hurt by the fall. Demons come
## in waves while he looks for the Dawn Breach. Stepping into it brings him back to the last safe
## spot by the hole with his Health as it is, a moment of grace, and the dawn's gift if he was
## quick. Dying down there ends the run, unless a second life opens the Threshold: the trial
## then takes him from the Deeps and, won, brings him back into the Deeps (they nest).
## Never on a boss floor (a boss must not be frozen), the hidden floor, or from the Threshold:
## there, a fall is the old rule (lose Health, climb out). Nothing is saved while he is down
## there (Game._save_run()); the run's clock keeps counting. The HUD follows the signals
## (Hud.bind_abyss()).

## He landed: the Deeps are built, the HUD can show their name.
signal opened(abyss: AbyssDef)
## The veil lifted: the demons start coming.
signal started
## He reached the door (the way back starts).
signal ended(escaped: bool)
## He is back on his floor (`escaped`), or the stay was cut short (a new run, the debug panel).
signal closed(escaped: bool)

const GROUP := &"abyss"
const WORLD_SCENE := preload("res://src/world/abyss_world.tscn")
## Over the HUD and the hints, under the menus (as the Threshold's).
const VEIL_LAYER := 9

enum State { CLOSED, ENTERING, SEARCHING, LEAVING }

var state := State.CLOSED
var def: AbyssDef
## The Deeps while the hero is in them.
var depths: AbyssWorld
## Set by the Game: its world, hero, ambience and content.
var game: Game
## Seconds since the veil lifted (the dawn's gift is for a quick way out).
var time_in := 0.0
## The dawn's gift was given on the way back (for the HUD and the tests).
var gifted := false

var _hero: Player
var _stay: SubWorld
## Where he comes back to: the last safe spot by the hole.
var _return_at := Vector2.ZERO
## Where he fell in (Vector2.INF: unknown), sealed on the way back (AbyssDef.seal_hole).
var _hole := Vector2.INF
var _torch_level := -1
var _tween: Tween
var _veil: ColorRect


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var layer := CanvasLayer.new()
	layer.name = "Veil"
	layer.layer = VEIL_LAYER
	add_child(layer)
	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.color = Color(0, 0, 0, 0)
	layer.add_child(_veil)


## The game goes (quit to the title from the Deeps): the floor waiting out of the tree goes too.
func _exit_tree() -> void:
	if _stay:
		_stay.discard()


## The Abyss of the game `node` is in (null: none, e.g. the balance tools' bare arena).
static func of(node: Node) -> Abyss:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as Abyss


## The hero is down there (or on his way in or out).
func is_open() -> bool:
	return state != State.CLOSED


func is_searching() -> bool:
	return state == State.SEARCHING


## On the way in or out, under the veil (no menus then).
func is_passing() -> bool:
	return state == State.ENTERING or state == State.LEAVING


## The hero is in the Deeps right now (not in the Threshold from there, nor home).
func holds(hero: Actor) -> bool:
	return depths != null and is_instance_valid(hero) and hero.world == depths


## Whether a fall of `hero` opens the Deeps: the game's hero, on his floor in play (not a pocket
## world), not on a boss floor nor the hidden floor, nothing else on (the Threshold, the Deeps).
func can_take(hero: Actor) -> bool:
	if state != State.CLOSED or def == null or game == null or not hero is Player or hero != game.player or hero.is_dead:
		return false
	var home := game.world
	if home == null or hero.world != home or not home.is_inside_tree() or home.map == null:
		return false
	if home.arena != null or home.is_boss_fight() or home.hidden_floor != null:
		return false
	return not game.threshold.is_open()


## `hero` fell into a hole (at `hole`): down into the Deeps. He comes back to `return_at` (the
## last safe spot by the hole), and the hole closes behind him if AbyssDef.seal_hole.
func open(hero: Player, return_at: Vector2, hole: Vector2 = Vector2.INF) -> void:
	state = State.ENTERING
	_hero = hero
	_return_at = return_at
	_hole = hole
	_stay = SubWorld.new(game, hero)
	gifted = false
	time_in = 0.0
	# Not now: this is the end of the fall's tween.
	_enter.call_deferred()


## Cuts the stay short at once (a new run, the debug panel): the floor and the hero go back as
## they were, without effects.
func abort() -> void:
	if state == State.CLOSED:
		return
	if _tween:
		_tween.kill()
	_veil.color.a = 0.0
	_bring_back()
	state = State.CLOSED
	closed.emit(false)


func _physics_process(delta: float) -> void:
	if state == State.SEARCHING:
		time_in += delta


# --- The way down ------------------------------------------------------------

func _enter() -> void:
	if state != State.ENTERING or not is_instance_valid(_hero):
		return
	HitStop.reset()
	_stay.freeze()
	_tween = create_tween()
	_veil.color = Color(def.veil_color, 0.0)
	_tween.tween_property(_veil, "color:a", 1.0, def.fade_time)
	_tween.tween_callback(_cross_over)
	_tween.tween_interval(0.2)
	_tween.tween_property(_veil, "color:a", 0.0, def.fade_time * 1.4)
	_tween.tween_callback(_begin)


## Under the veil: the floor leaves the tree as it is, the Deeps take the hero, hurt by the fall.
func _cross_over() -> void:
	var hero := _hero
	depths = WORLD_SCENE.instantiate() as AbyssWorld
	depths.name = "AbyssWorld"
	_stay.cross(depths)
	depths.build_depths(_stay.home.depth, game.content, def, randi())
	depths.door_reached.connect(_on_door_reached)
	depths.take_in(hero)
	hero.stand_up()
	hero.statuses.clear()
	hero.temperature.reset()
	var torch := hero.get_node_or_null("Torch") as LightSource
	if torch:
		_torch_level = torch.level
		torch.level = def.torch_level
	play_mood()
	Vfx.dust(depths, hero.global_position, 1.5)
	if not def.lore.is_empty():
		Events.log_message(tr(def.lore), def.color)
	Events.log_message(tr("You fall into the Deeps. Find the Dawn Breach to climb back up."), def.color)
	opened.emit(def)
	hero.take_fall(def.fall_damage)


## The Deeps' sound and look (when the hero lands, and back from the Threshold down there).
func play_mood() -> void:
	if depths == null or not is_instance_valid(_hero):
		return
	game.ambience.play(def.ambience, depths, _hero)
	if def.music:
		Sfx.play_music(def.music)


func _begin() -> void:
	if state != State.ENTERING:
		return
	state = State.SEARCHING
	if is_instance_valid(_hero) and not _hero.is_dead:
		depths.start_waves()
		show_the_way()
		if def.guide_every > 0.0:
			_guide_later()
	started.emit()


## A light runs ahead of the hero along the way to the door (when the veil lifts, then now and
## then while he searches).
func show_the_way() -> void:
	if depths == null or not is_instance_valid(_hero) or not holds(_hero):
		return
	var path := depths.way_to_door(_hero.global_position)
	if not path.is_empty():
		depths.spawn_vfx(GuideWisp.create(_hero.global_position + Vector2(0, -18), path))


func _guide_later() -> void:
	var stay := _stay
	await get_tree().create_timer(def.guide_every, false).timeout
	if state == State.SEARCHING and _stay == stay:
		show_the_way()
		_guide_later()


func _on_door_reached() -> void:
	if state != State.SEARCHING or not is_instance_valid(_hero) or _hero.is_dead:
		return
	_end.call_deferred(true)  # (in a physics callback)


# --- The way back up ---------------------------------------------------------

## He stepped into the Dawn Breach: the Deeps stop, the dawn's light fills the screen, he is home.
func _end(escaped: bool) -> void:
	if state != State.SEARCHING:
		return
	state = State.LEAVING
	depths.waves_on = false
	depths.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED)
	Sfx.play_ui(Sfx.bank.stairs)
	Events.log_message(tr("The light takes you back up."), def.color)
	ended.emit(escaped)
	_tween = create_tween()
	_veil.color = Color(def.return_veil_color, 0.0)
	_tween.tween_property(_veil, "color:a", 1.0, def.fade_time)
	_tween.tween_callback(_go_home)
	_tween.tween_property(_veil, "color:a", 0.0, def.fade_time * 1.4)


func _go_home() -> void:
	var hero := _hero
	var quick := time_in <= def.quick_time_for(_stay.home.depth, game.content.dungeon)
	_bring_back()
	state = State.CLOSED
	if is_instance_valid(hero) and not hero.is_dead:
		hero.shield_for(def.return_grace)
		Vfx.magic(hero.world, hero.global_position, def.return_veil_color, VfxElementDef.named(&"holy"))
		Events.stat_counted.emit("abyss_escapes", 1)
		if quick:
			_give_gift(hero)
	closed.emit(true)


## Out quick: gold at his feet (the floor's gold rules), and a roll of the gift's loot.
func _give_gift(hero: Player) -> void:
	gifted = true
	var home := hero.world
	var gold := def.gift_gold_for(home.depth, game.content.dungeon)
	if gold > 0:
		home.spawn_gold(hero.global_position + Vector2(0, 12), gold)
	if def.gift_loot:
		for item in def.gift_loot.roll(home.rng):
			home.spawn_loot(item, home.find_open_point_near(hero.global_position, 36.0))
	Events.log_message(tr("Out before the dark closed in: the dawn leaves you a gift."), Palette.GOLD)


## The floor back in the tree as it was, the Deeps gone, the hero at the safe spot by the hole,
## his torch as it was.
func _bring_back() -> void:
	var hero := _hero if is_instance_valid(_hero) else null
	if depths:
		depths.waves_on = false
	if hero:
		var torch := hero.get_node_or_null("Torch") as LightSource
		if torch and _torch_level >= 0:
			torch.level = _torch_level
		_torch_level = -1
		hero.stand_up()
	if _stay:
		var home := _stay.home
		var at := _return_at
		if is_instance_valid(home) and home.map and not home.is_solid_ground(at):
			at = home.nearest_free_point(at)
		_stay.come_back(at)
		# Back in the tree: the hole he fell through fills in behind him.
		if def and def.seal_hole and _hole != Vector2.INF and is_instance_valid(home) and home.map:
			home.seal_hole(home.map.world_to_cell(_hole))
	_hole = Vector2.INF
	depths = null
	game.play_floor_mood()
