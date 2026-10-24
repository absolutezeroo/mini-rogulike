extends Node
## The online leaderboards (autoload "Leaderboards"; design/progression.md "Online leaderboards",
## docs/online.md). Listens for runs that end (Events.run_ended, a RunSummary from RunRecords),
## queues the scores the boards take (LeaderboardDef.accepts(): the Dawn Knell's official attempt
## for now), sends them through its backend and keeps trying while there is no network; reads the
## boards for the Leaderboards page. UI asks it, never the other way round.
##
## Its own file, user://leaderboards.json (never the player's save, never the Profile): the
## device's anonymous id (and the Talo player it became), the pseudonym, "publish my scores
## online" and the scores waiting to be sent. Nothing is sent for a debug run, a practice
## attempt, a run that fails RunSummary.check(), in the tests (they give it an offline backend
## and no file), and **nothing at all, not even a read of a board, until the player chose to
## publish their scores** (PseudonymDialog: the choice is the consent the law asks for, docs/
## privacy-ops.md). The gameplay statistics (Telemetry) use the same device id and server.
##
## Without an access key (TaloBackend.read_key()) the backend is BoardBackend's offline one:
## nothing is sent, nothing fails, the page says the leaderboards are unavailable.

## Something the page shows changed: the name, the opt-out, a score sent or waiting.
signal changed

const PATH := "user://leaderboards.json"
const CONFIG := "res://data/leaderboards/leaderboards.tres"
## 2: the choice to publish became explicit (off until chosen); a version-1 file is asked again.
const VERSION := 2
## Seconds after the game starts before what waits is sent (the start isn't slowed).
const START_DELAY := 3.0

## Empty = nothing is read or written (tests).
var path := PATH
var config: LeaderboardsConfig
var backend: BoardBackend
## Made on the device the first time it is needed (a feature turned on), random, never derived
## from the device: the player on the server. Shown in Options > Privacy (for a deletion request).
var device_id := ""
## The server's id for that player once identified ("" before): goes in a deletion request.
var player_id := ""
## The pseudonym on the boards; `name_chosen`: the player picked it (or kept the default) once.
var pseudonym := ""
var name_chosen := false
## The name the server has for this player ("" none yet).
var synced_name := ""
## "Publish my scores online": off (the default until the player says yes), nothing is ever sent
## or read (and what waited is dropped).
var shown := false
## Scores waiting to be sent, oldest first: {board, period, score, props, at}.
var queue: Array[Dictionary] = []
## Why the last run ended wasn't queued (RunSummary.check()), for the tests.
var last_rejection := ""
## Places on the boards the server gave as scores were sent this session: "board/period" -> rank.
var last_ranks := {}

var _flushing := false
var _identified := false
## Seeds the default name before the device has an id (never saved).
var _session_seed := str(randi())
var _retry: Timer


## What the page shows for one board and period.
class View:
	extends RefCounted
	var status: BoardBackend.Status = BoardBackend.Status.UNAVAILABLE
	## The top of the board (config.top_count at most).
	var top: Array[BoardBackend.Entry] = []
	## The player's own line (null: none), and the lines around it when it is past the top.
	var mine: BoardBackend.Entry
	var around: Array[BoardBackend.Entry] = []
	## Entries on the board for that period.
	var total := 0
	## The player's score for that period still waits to be sent (its score, -1: none).
	var waiting := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = load(CONFIG) as LeaderboardsConfig
	load_state()
	if backend == null:
		use_backend(TaloBackend.new() if not str(TaloBackend.read_key().key).is_empty() else BoardBackend.new())
	Events.run_ended.connect(record)
	_retry = Timer.new()
	_retry.one_shot = true
	_retry.timeout.connect(flush)
	add_child(_retry)
	_retry.start(START_DELAY)


## Talks to `new_backend` from now on (the tests' fake or offline one).
func use_backend(new_backend: BoardBackend) -> void:
	if backend and is_instance_valid(backend):
		remove_child(backend)
		backend.queue_free()
	backend = new_backend
	_identified = false
	add_child(backend)


## The tests: no file, an offline backend (or `fake`), everything forgotten.
func use_for_tests(fake: BoardBackend = null) -> void:
	path = ""
	use_backend(fake if fake else BoardBackend.new())
	reset()


## Everything forgotten (not the file: save_state() does).
func reset() -> void:
	device_id = ""
	player_id = ""
	pseudonym = ""
	name_chosen = false
	synced_name = ""
	shown = false
	queue.clear()
	last_rejection = ""
	last_ranks.clear()
	_identified = false


## There is a server (an access key in this build).
func is_available() -> bool:
	return backend != null and backend.is_configured()


## The player hasn't chosen yet whether to publish their scores (ask before anything is sent).
func needs_name() -> bool:
	return is_available() and not name_chosen


## The name on the boards: the one picked, or a default ("Soul 4821": from the device's id once
## there is one; before, from a number of this session, so asking makes no id).
func display_name() -> String:
	if not pseudonym.is_empty():
		return pseudonym
	return PlayerName.default_for(device_id if not device_id.is_empty() else _session_seed, config)


## Sets the pseudonym (tidied) if it passes PlayerName.problem(); returns the problem otherwise.
func set_pseudonym(text: String) -> PlayerName.Problem:
	var problem := PlayerName.problem(text, config)
	if problem != PlayerName.Problem.NONE:
		return problem
	pseudonym = PlayerName.tidy(text)
	name_chosen = true
	save_state()
	changed.emit()
	flush()
	return problem


## The default name kept as the pseudonym: not asked again.
func keep_default_name() -> void:
	if pseudonym.is_empty():
		pseudonym = display_name()
	name_chosen = true
	save_state()
	changed.emit()


## "Publish my scores online", the player's own choice (the dialog, the Options). Off drops what
## waits and never sends nor reads again until it is on. Either way it is an answer: not asked
## again.
func set_shown(on: bool) -> void:
	shown = on
	if on:
		_device()  # (the default name then comes from this device's id, and stays)
	else:
		queue.clear()
	name_chosen = true
	save_state()
	changed.emit()


## "Delete my online data" (Privacy.forget_online()): off, and the device's id, its server player,
## the pseudonym and the queue forgotten. A new random id is made if the player turns a feature on
## again, so this device is no longer linked to the old record.
func forget() -> void:
	device_id = ""
	player_id = ""
	pseudonym = ""
	synced_name = ""
	shown = false
	name_chosen = true
	queue.clear()
	last_ranks.clear()
	_identified = false
	if backend:
		backend.forget()
	save_state()
	changed.emit()


## A run ended: its scores queued for the boards that take it, then sent. Returns how many were
## queued (none without a server: an offline build keeps nothing).
func record(summary: RunSummary) -> int:
	last_rejection = ""
	if not is_available() or not shown or summary.debug or RemoteConfig.scores_off():
		return 0  # (scores_off: the remote kill switch)
	var boards := config.boards.filter(func(def: LeaderboardDef) -> bool: return def.accepts(summary))
	if boards.is_empty():
		return 0
	last_rejection = summary.check(config)
	if not last_rejection.is_empty():
		return 0
	var props := summary.props()
	props[TaloBackend.NAME_PROP] = display_name()
	for def: LeaderboardDef in boards:
		var key := def.period_of(summary)
		var entry_props := props.duplicate()
		if not period_prop(def).is_empty():
			entry_props[period_prop(def)] = key
		_enqueue({ "board": String(def.id), "period": key, "score": def.score_of(summary), "props": entry_props, "at": int(Time.get_unix_time_from_system()) })
	save_state()
	changed.emit()
	flush()
	return boards.size()


## The prop an entry of `board` keeps its period in ("day", "week"; "" for all time): the page
## asks the server for one period's entries by it.
static func period_prop(board: LeaderboardDef) -> String:
	match board.period:
		LeaderboardDef.Period.DAILY:
			return "day"
		LeaderboardDef.Period.WEEKLY:
			return "week"
	return ""


## The score waiting for `board` in period `key`, or -1.
func waiting_score(board: LeaderboardDef, key: String) -> float:
	for item in queue:
		if item.board == String(board.id) and item.period == key:
			return float(item.score)
	return -1.0


## Sends what waits, in order; on no network, tries again in config.retry_seconds. A score whose
## period is over (yesterday's, the board emptied at midnight UTC) or refused by the server is
## dropped. One flush at a time.
func flush() -> void:
	if _flushing or not is_available() or not shown or RemoteConfig.scores_off():
		return
	if queue.is_empty() and (not name_chosen or synced_name == display_name()):
		return
	_flushing = true
	var status := await _ensure_identity()
	if status == BoardBackend.Status.OK and synced_name != display_name() and (name_chosen or not queue.is_empty()):
		var named := display_name()
		@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
		status = await backend.set_pseudonym(named)
		if status == BoardBackend.Status.OK:
			synced_name = named
			save_state()
	while status != BoardBackend.Status.OFFLINE and not queue.is_empty():
		var item: Dictionary = queue[0]
		var def := config.board(StringName(item.board))
		if def == null or not def.submits or not def.is_open(str(item.period)):
			queue.pop_front()
			continue
		@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
		var sent := await backend.submit(def, float(item.score), str(item.period), item.props)
		status = sent.status
		if status == BoardBackend.Status.OFFLINE:
			break
		if not queue.is_empty() and queue[0] == item:
			queue.pop_front()
		if status == BoardBackend.Status.OK and sent.rank > 0:
			last_ranks["%s/%s" % [item.board, item.period]] = sent.rank
	save_state()
	_flushing = false
	changed.emit()
	if status == BoardBackend.Status.OFFLINE and (not queue.is_empty() or synced_name != display_name()):
		_retry.start(config.retry_seconds)


## The board for the period `back` periods ago (0: today), as the page shows it: the top, the
## player's line and those around it. What waits is sent first.
func load_board(board: LeaderboardDef, back: int = 0) -> View:
	var view := View.new()
	if not is_available() or not shown:
		return view  # (not chosen to publish: the server isn't even read)
	await flush()
	var key := board.period_key(back)
	var past := back > 0
	view.waiting = waiting_score(board, key)
	var identity_status := await _ensure_identity()
	@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
	var top := await backend.fetch(board, key, past, 0)
	view.status = top.status
	if top.status != BoardBackend.Status.OK:
		return view
	view.total = top.total
	view.top.assign(top.entries.slice(0, config.top_count))
	if identity_status != BoardBackend.Status.OK or backend.alias_id() == 0:
		return view
	var me := backend.alias_id()
	for entry in top.entries:
		if entry.alias_id == me:
			view.mine = entry
			if entry.rank <= config.top_count:
				return view
	# Past the top: the player's entry, then the page around it.
	var page_size := BoardBackend.PAGE_SIZE
	if view.mine == null:
		@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
		var mine := await backend.fetch_mine(board, key, past)
		if mine.status != BoardBackend.Status.OK or mine.entries.is_empty():
			return view
		view.mine = mine.entries[0]
		if not mine.ranks_reliable:
			view.mine.rank = 0
			for page_index in range(1, config.rank_scan_pages):
				if top.last_page:
					break
				@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
				var page := await backend.fetch(board, key, past, page_index)
				if page.status != BoardBackend.Status.OK:
					break
				top = page
				for entry in page.entries:
					if entry.alias_id == me:
						view.mine = entry
						_fill_around(view, page.entries)
						return view
			return view
	var around := top
	var wanted := floori(float(view.mine.rank - 1) / page_size)
	if wanted != 0:
		@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
		around = await backend.fetch(board, key, past, wanted)
	if around.status == BoardBackend.Status.OK:
		_fill_around(view, around.entries)
	return view


func _fill_around(view: View, entries: Array[BoardBackend.Entry]) -> void:
	var index := -1
	for i in entries.size():
		if entries[i].alias_id == view.mine.alias_id:
			index = i
	if index < 0:
		view.around.append(view.mine)
		return
	view.mine = entries[index]
	view.around.assign(entries.slice(maxi(index - config.around, 0), index + config.around + 1))


## The device's player on the server, made the first time (the gameplay statistics use it too:
## Telemetry). Only called once the player turned a feature on.
func identity() -> BoardBackend.Status:
	return await _ensure_identity()


func _ensure_identity() -> BoardBackend.Status:
	if _identified:
		return BoardBackend.Status.OK
	@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
	var status := await backend.identify(_device())
	_identified = status == BoardBackend.Status.OK
	if _identified and backend.player_id() != player_id:
		player_id = backend.player_id()
		save_state()
	return status


## The device's id, made the first time (and kept in the file).
func _device() -> String:
	if device_id.is_empty():
		device_id = Crypto.new().generate_random_bytes(16).hex_encode()
		save_state()
	return device_id


## A score into the queue: one per board and period, the better one kept.
func _enqueue(item: Dictionary) -> void:
	var def := config.board(StringName(item.board))
	for i in queue.size():
		var other: Dictionary = queue[i]
		if other.board == item.board and other.period == item.period:
			var better := float(item.score) > float(other.score) if def.higher_first else float(item.score) < float(other.score)
			if better:
				queue[i] = item
			return
	queue.append(item)
	while queue.size() > config.max_queue:
		queue.pop_front()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if not queue.is_empty() and _retry and _retry.is_stopped():
			flush()


# --- The file ------------------------------------------------------------------

func save_state() -> void:
	if path.is_empty():
		return
	SafeFile.write_json(path, {
		"version": VERSION,
		"device_id": device_id,
		"player_id": player_id,
		"name": pseudonym,
		"name_chosen": name_chosen,
		"synced_name": synced_name,
		"shown": shown,
		"queue": queue,
	})


func load_state() -> void:
	reset()
	if path.is_empty():
		return
	var data: Variant = SafeFile.read_json(path)
	if not data is Dictionary:
		return
	device_id = str(data.get("device_id", ""))
	player_id = str(data.get("player_id", ""))
	pseudonym = str(data.get("name", ""))
	synced_name = str(data.get("synced_name", ""))
	# Before version 2, "shown" was on unless turned off: the player is asked again.
	if int(data.get("version", 1)) >= 2:
		name_chosen = bool(data.get("name_chosen", false))
		shown = bool(data.get("shown", false))
	var saved: Variant = data.get("queue", []) if shown else []
	if saved is Array:
		for item: Variant in saved:
			if item is Dictionary and (item as Dictionary).has_all(["board", "period", "score", "props"]):
				queue.append(item)
