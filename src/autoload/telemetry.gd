extends Node
## The gameplay statistics (autoload "Telemetry"; docs/online.md "Gameplay statistics"): with the
## player's consent only (Privacy.analytics_allowed()), the summary of each run that ends and the
## events of its boss fights, perk choices, purchases and pacts go to Talo's events, to balance
## the game and find its bugs. The list of events and of their fields is data
## (data/online/telemetry.tres, TelemetryDef).
##
## A RunTelemetry follows each run from Events.run_started (in memory only); at Events.run_ended
## its events are queued, if the player consented and the run is not a debug run, then sent in
## batches through the leaderboards' server (Leaderboards: same device id, same player). The
## queue waits in its own file, user://telemetry.json, bounded (TelemetryDef.max_queue), while
## there is no network, and goes when the network is back, at a run's end, or when the app goes
## to the background. Refusing or withdrawing drops what waited. The game never depends on it:
## it only listens. The tests give it no file (and Leaderboards an offline or fake server).

const PATH := "user://telemetry.json"
const DEFS := "res://data/online/telemetry.tres"
const VERSION := 1

## Empty = nothing is read or written (tests).
var path := PATH
var config: TelemetryDef
## Events waiting to be sent, oldest first: {name, props, timestamp}.
var queue: Array[Dictionary] = []
## The run being followed (null between runs).
var tracker: RunTelemetry
## The last run's end event as queued (props after sanitize()), for the tests.
var last_summary := {}

var _flushing := false
var _retry: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = load(DEFS) as TelemetryDef
	load_state()
	Events.run_started.connect(_on_run_started)
	Events.run_ended.connect(record)
	_retry = Timer.new()
	_retry.one_shot = true
	_retry.timeout.connect(flush)
	add_child(_retry)


## The tests: no file, nothing waiting, no run followed.
func use_for_tests() -> void:
	path = ""
	reset()


func reset() -> void:
	queue.clear()
	last_summary = {}
	if tracker:
		tracker.unbind()
	tracker = null


## Unix time in milliseconds (Talo's events' timestamp; Privacy's test clock when set).
func now_ms() -> int:
	return Privacy.now() * 1000 if Privacy.fake_now >= 0 else int(Time.get_unix_time_from_system() * 1000.0)


## The statistics may be collected and sent now (consent, a server).
func is_active() -> bool:
	return Privacy.analytics_allowed() and Leaderboards.is_available()


func _on_run_started(run: RunState, player: Player) -> void:
	if tracker:
		tracker.unbind()
	tracker = RunTelemetry.new()
	tracker.bind(run, player)


## A run ended (Events.run_ended): its events queued, if allowed, then sent. Returns how many were
## queued. A debug run, or a run without consent, queues nothing; a run that goes on (a win, then
## the endless floors) is told again at its real end, with more.
func record(summary: RunSummary) -> int:
	if tracker == null or summary.debug or DebugCheats.debug_run or not is_active():
		if tracker:
			tracker.pending.clear()
		return 0
	var before := queue.size()
	var events := tracker.pending.duplicate()
	tracker.pending.clear()
	var props := tracker.summary(summary)
	events.append_array(tracker.pending)
	tracker.pending.clear()
	events.append({ "name": &"run_end", "props": props, "timestamp": now_ms() })
	for event: Dictionary in events:
		_enqueue(event)
	save_state()
	flush()
	return queue.size() - before


## Puts `event` in the queue as it will be sent (its event on, its props sanitized, the game's
## version added). False if its event is off.
func _enqueue(event: Dictionary) -> bool:
	var def := config.event(StringName(event.name))
	if def == null or not def.enabled:
		return false
	var props: Dictionary = (event.props as Dictionary).duplicate()
	props["v"] = str(ProjectSettings.get_setting("application/config/version", ""))
	var clean := config.sanitize(def, props)
	var item := { "name": String(def.name), "props": clean, "timestamp": int(event.timestamp) }
	if def.name == &"run_end":
		last_summary = clean
	queue.append(item)
	while queue.size() > config.max_queue:
		queue.pop_front()
	return true


## Everything waiting dropped (consent refused or withdrawn, "delete my online data").
func drop_queue() -> void:
	queue.clear()
	if tracker:
		tracker.pending.clear()
	save_state()


## Sends what waits, a batch at a time; without network, tries again in config.retry_seconds.
## Only with consent. A batch the server refuses for good is dropped.
func flush() -> void:
	if _flushing or queue.is_empty() or not is_active():
		return
	_flushing = true
	var status := await Leaderboards.identity()
	while status == BoardBackend.Status.OK and not queue.is_empty() and is_active():
		var batch: Array[Dictionary] = []
		batch.assign(queue.slice(0, config.batch_size))
		status = await Leaderboards.backend.send_events(batch)
		if status == BoardBackend.Status.OFFLINE or status == BoardBackend.Status.UNAVAILABLE:
			break
		# OK or refused for good: these are done (the queue may have changed meanwhile).
		for item in batch:
			queue.erase(item)
		if status != BoardBackend.Status.OK:
			status = BoardBackend.Status.OK  # (a refused batch doesn't stop the next one)
	save_state()
	_flushing = false
	if status == BoardBackend.Status.OFFLINE and not queue.is_empty() and _retry:
		_retry.start(config.retry_seconds)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			# To the background (or closing): what waits is kept, and sent if it can be.
			save_state()
			flush()
		NOTIFICATION_APPLICATION_RESUMED:
			flush()


# --- The file ------------------------------------------------------------------

func save_state() -> void:
	if path.is_empty():
		return
	SafeFile.write_json(path, { "version": VERSION, "queue": queue })


func load_state() -> void:
	queue.clear()
	if path.is_empty():
		return
	var data: Variant = SafeFile.read_json(path)
	if not data is Dictionary:
		return
	var saved: Variant = (data as Dictionary).get("queue", [])
	if saved is Array:
		for item: Variant in saved:
			if item is Dictionary and (item as Dictionary).has_all(["name", "props", "timestamp"]):
				queue.append(item)
	while queue.size() > config.max_queue:
		queue.pop_front()
