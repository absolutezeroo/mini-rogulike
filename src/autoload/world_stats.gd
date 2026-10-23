extends Node
## The world counters, "The Well's Toll" (autoload "WorldStats"; docs/online.md "World
## counters"): numbers every player adds to, kept by Talo as global game stats (the demons slain in
## the Well by everyone, the bells rung, the souls offered to the Tree...), and each player's own
## share. The counters are data (data/online/world_stats.tres, WorldStatsDef, WorldStatDef).
##
## Counting: it listens to the Events bus during a run (kills, bosses, floors, potions, a death, a
## new Dawn Knell) and at the shrine (souls offered); a run's counts wait in `pending` and join the
## queue when the run ends (Events.run_ended, then Events.ending_chosen for the ending), capped to
## each counter's max change. The queue is sent with **one update per counter** (Talo's PUT, its
## maxChange and rate limits respected: never one call per kill), through the leaderboards' server
## and player (Leaderboards: same device id). Without network it waits in its own file,
## user://world_stats.json, and is tried again every retry_seconds, at the next run's end and when
## the app comes back.
##
## Consent: the counts are tied to the player on Talo (its own totals, and a snapshot of each
## update), so they are part of the **gameplay statistics**: only with Privacy.analytics_allowed()
## (16 or older, accepted, for the current consent version); refusing or withdrawing drops what
## waited. Never from a debug run, nor from a debug build (Talo adds a dev build's updates to the
## world's numbers: its PUT ignores X-Talo-Dev-Build), nor in the tests (no file, no consent).
##
## Reading: the world's numbers are read (one GET for all) at most every refresh_seconds, only once
## the player turned an online feature on (published their scores, or accepted the statistics):
## before that choice the game makes no call at all. The player's own share is read only with the
## statistics' consent. Offline, without a key or a choice: nothing is shown (title_lines() is empty,
## the page says why), and nothing fails.

## The world's numbers, the player's share or what waits changed (the screens follow).
signal changed

const PATH := "user://world_stats.json"
const DEFS := "res://data/online/world_stats.tres"
const VERSION := 1

## Empty = nothing is read or written (tests).
var path := PATH
var config: WorldStatsDef
## The run going on (or a run left unfinished): counted, not queued yet. Internal name -> amount.
var pending := {}
## Waiting to be sent: internal name -> amount (runs played offline add up).
var queue := {}
## The world's numbers last read (internal name -> value), in memory only: hidden until read.
var world := {}
## The player's own lifetime share (the server's when read, plus what was sent since).
var mine := {}
## When the world's numbers were read (Unix seconds; 0: not yet), and how the last read went.
var read_at := 0
var read_status: BoardBackend.Status = BoardBackend.Status.UNAVAILABLE
## A debug build sends nothing (its updates would count in the world's numbers on Talo). The
## tests turn it on, on a fake server.
var debug_builds_send := false

var _player: Player
## The deepest floor of the run reached so far (a floor is counted once, not when a run resumes).
var _depth := 1
var _flushing := false
var _reading := false
var _retry: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = load(DEFS) as WorldStatsDef
	load_state()
	Events.run_started.connect(_on_run_started)
	Events.run_ended.connect(_on_run_ended)
	Events.monster_killed.connect(_on_monster_killed)
	Events.boss_defeated.connect(func(_boss: Monster) -> void: count(WorldStatDef.Feed.BOSSES))
	Events.depth_changed.connect(_on_depth_changed)
	Events.ending_chosen.connect(_on_ending_chosen)
	Events.souls_offered.connect(_on_souls_offered)
	Privacy.changed.connect(_on_choices_changed)
	Leaderboards.changed.connect(_on_choices_changed)
	_retry = Timer.new()
	_retry.one_shot = true
	_retry.timeout.connect(flush)
	add_child(_retry)


## The tests: no file, nothing counted or read, debug builds kept silent.
func use_for_tests() -> void:
	path = ""
	debug_builds_send = false
	reset()


func reset() -> void:
	pending.clear()
	queue.clear()
	world.clear()
	mine.clear()
	read_at = 0
	read_status = BoardBackend.Status.UNAVAILABLE
	_depth = 1
	_bind(null)


## The player's shares may be counted and sent now: the statistics accepted, a server, a release
## build (or the tests').
func may_send() -> bool:
	return Privacy.analytics_allowed() and Leaderboards.is_available() and (debug_builds_send or not OS.is_debug_build())


## The world's numbers may be read: a server, and the player turned an online feature on.
func may_read() -> bool:
	return Leaderboards.is_available() and (Leaderboards.shown or Privacy.analytics_allowed())


## The world's number for `def` (-1: not known: not read, offline, or not allowed).
func world_value(def: WorldStatDef) -> float:
	if not may_read() or not world.has(def.internal_name):
		return -1.0
	return float(world[def.internal_name])


## The player's own share of `def`, sent or waiting (-1: not counted: no consent).
func my_value(def: WorldStatDef) -> float:
	if not may_send():
		return -1.0
	return float(mine.get(def.internal_name, 0.0)) + float(queue.get(def.internal_name, 0)) + float(pending.get(def.internal_name, 0))


## The title screen's lines, each with its number in the game's language: the counters that have
## one and reached title_min_count. Empty when nothing is known.
func title_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for def in config.enabled_stats():
		var value := world_value(def)
		if def.title_line.is_empty() or value < config.title_min_count:
			continue
		lines.append(tr(def.title_line).format({ "count": NumberText.of(int(value)) }))
	return lines


# --- Counting -------------------------------------------------------------------------

## Adds `amount` to the counters fed by `feed` (an ENDING feed: only the one for `ending`), for the
## run going on. Nothing without consent, nor in a debug run.
func count(feed: WorldStatDef.Feed, amount: int = 1, ending: StringName = &"") -> void:
	if amount <= 0 or not may_send() or DebugCheats.debug_run:
		return
	for def in config.enabled_stats():
		if def.feed == feed and (feed != WorldStatDef.Feed.ENDING or def.ending == ending):
			pending[def.internal_name] = int(pending.get(def.internal_name, 0)) + amount


## The run's counts join the queue (each capped to its counter's max change: no real run adds
## more), then go.
func commit() -> void:
	for internal_name: String in pending.keys():
		var def := config.stat(internal_name)
		var amount := int(pending[internal_name])
		if def == null or not def.enabled or amount <= 0:
			continue
		queue[internal_name] = int(queue.get(internal_name, 0)) + mini(amount, def.max_change)
	pending.clear()
	save_state()
	changed.emit()
	flush()


func _on_run_started(run: RunState, player: Player) -> void:
	_bind(player)
	_depth = run.depth
	if run.is_daily() and run.time <= 0.0:
		count(WorldStatDef.Feed.DAILY_RUNS)  # (a new Dawn Knell, not one resumed)


func _bind(player: Player) -> void:
	if _player and is_instance_valid(_player) and _player.consumable_used.is_connected(_on_consumable_used):
		_player.consumable_used.disconnect(_on_consumable_used)
	_player = player
	if player:
		player.consumable_used.connect(_on_consumable_used)


func _on_monster_killed(monster: Monster) -> void:
	if not monster.summoned:  # (called in by another: not a kill, as RunRecords counts them)
		count(WorldStatDef.Feed.KILLS)


func _on_depth_changed(depth: int) -> void:
	if depth > _depth:
		count(WorldStatDef.Feed.FLOORS, depth - _depth)
	_depth = maxi(_depth, depth)


func _on_consumable_used(item: ItemDef) -> void:
	if item is ConsumableDef and Player.heals(item as ConsumableDef):
		count(WorldStatDef.Feed.POTIONS)


func _on_run_ended(summary: RunSummary) -> void:
	if summary.debug or DebugCheats.debug_run:
		pending.clear()  # (a debug run's counts never go anywhere)
		save_state()
		return
	if _player and is_instance_valid(_player) and _player.is_dead:
		count(WorldStatDef.Feed.DEATHS)
	commit()


func _on_ending_chosen(ending: EndingDef) -> void:
	count(WorldStatDef.Feed.ENDING, 1, ending.id)
	commit()


func _on_souls_offered(amount: int) -> void:
	count(WorldStatDef.Feed.SOULS_OFFERED, amount)
	if not pending.is_empty():
		commit()


## Consent withdrawn (or the scores unpublished): nothing waits any more, nothing is shown.
func _on_choices_changed() -> void:
	if not may_send() and (not pending.is_empty() or not queue.is_empty()):
		pending.clear()
		queue.clear()
		save_state()
	if not may_read() and not world.is_empty():
		world.clear()
		read_at = 0
		read_status = BoardBackend.Status.UNAVAILABLE
	changed.emit()


## "Delete my online data": every count, share and number forgotten.
func forget() -> void:
	reset()
	save_state()
	changed.emit()


# --- The server -------------------------------------------------------------------------

## Sends what waits: one update per counter (a share past its max change goes in parts). Without
## network, tries again in retry_seconds; a counter the server refuses is dropped (not resent).
func flush() -> void:
	if _flushing or queue.is_empty() or not may_send():
		return
	_flushing = true
	var status := await Leaderboards.identity()
	for internal_name: String in queue.keys():
		if status != BoardBackend.Status.OK or not may_send():
			break
		var def := config.stat(internal_name)
		if def == null or not def.enabled:
			queue.erase(internal_name)
			continue
		while int(queue.get(internal_name, 0)) > 0:
			var part := mini(int(queue[internal_name]), def.max_change)
			@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
			status = await Leaderboards.backend.add_to_stat(internal_name, part)
			if status == BoardBackend.Status.OFFLINE or status == BoardBackend.Status.UNAVAILABLE or not queue.has(internal_name):
				break
			if status == BoardBackend.Status.REJECTED:
				queue.erase(internal_name)  # refused for good (no such counter, a change it won't take)
				status = BoardBackend.Status.OK
				break
			queue[internal_name] = int(queue[internal_name]) - part
			mine[internal_name] = float(mine.get(internal_name, 0.0)) + part
			if world.has(internal_name):
				world[internal_name] = float(world[internal_name]) + part
		if int(queue.get(internal_name, 0)) <= 0:
			queue.erase(internal_name)
	save_state()
	_flushing = false
	changed.emit()
	if status != BoardBackend.Status.OK and not queue.is_empty() and _retry:
		_retry.start(config.retry_seconds)


## Reads the world's numbers (and the player's own share, with consent), unless they were read less
## than refresh_seconds ago (`force`: read anyway, the page's Try again). What waits is sent first.
func refresh(force: bool = false) -> void:
	if _reading or not may_read():
		return
	var now := int(Time.get_unix_time_from_system())
	if not force and read_at > 0 and now - read_at < config.refresh_seconds:
		return
	_reading = true
	await flush()
	@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
	var read := await Leaderboards.backend.fetch_world_stats()
	if not may_read():
		_reading = false
		return
	read_status = read.status
	if read.status == BoardBackend.Status.OK:
		world.clear()
		for def in config.enabled_stats():
			if read.values.has(def.internal_name):
				world[def.internal_name] = float(read.values[def.internal_name])
		read_at = now
		if may_send() and await Leaderboards.identity() == BoardBackend.Status.OK:
			@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
			var own := await Leaderboards.backend.fetch_my_stats()
			if own.status == BoardBackend.Status.OK:
				for internal_name: String in own.values:
					# (the server's answer may be a little older than what was just sent)
					mine[internal_name] = maxf(float(own.values[internal_name]), float(mine.get(internal_name, 0.0)))
				save_state()
	_reading = false
	changed.emit()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			save_state()  # (a run's counts so far, if the app is closed in the middle of it)
		NOTIFICATION_APPLICATION_RESUMED:
			if not queue.is_empty() and _retry and _retry.is_stopped():
				flush()


# --- The file ------------------------------------------------------------------

func save_state() -> void:
	if path.is_empty():
		return
	SafeFile.write_json(path, { "version": VERSION, "pending": pending, "queue": queue, "mine": mine })


func load_state() -> void:
	reset()
	if path.is_empty():
		return
	var data: Variant = SafeFile.read_json(path)
	if not data is Dictionary:
		return
	for key in ["pending", "queue", "mine"]:
		var saved: Variant = (data as Dictionary).get(key, {})
		if not saved is Dictionary:
			continue
		var into: Dictionary = get(key)
		for internal_name: Variant in saved:
			var value: Variant = (saved as Dictionary)[internal_name]
			if (value is int or value is float) and float(value) > 0.0:
				if key == "mine":
					into[str(internal_name)] = float(value)
				else:
					into[str(internal_name)] = int(value)
	if not may_send():
		pending.clear()  # (the consent was withdrawn meanwhile: nothing goes)
		queue.clear()
