extends Node
## The gameplay statistics (autoload "Telemetry"; docs/online.md "Gameplay statistics"): with the
## player's consent only (Privacy.analytics_allowed()), the summary of each run that ends and the
## events of its boss fights, perk choices, purchases and pacts go to Talo's events, to balance
## the game and find its bugs. The list of events and of their fields is data
## (data/online/telemetry.tres, TelemetryDef).
##
## A RunTelemetry follows each run from Events.run_started; its counts are kept in the run's save
## (Events.run_saving: RunState.telemetry) and taken back when the run is resumed, so the run's
## end covers the whole run. At Events.run_ended its events are queued, if the player consented
## and the run is not a debug run, then sent in batches through the leaderboards' server
## (Leaderboards: same device id, same player). A run left without ending (Events.run_left: quit
## to the title, the app closed) sends its run_end too, result "abandoned" and quit 1, under the
## same run id as its later end if it is resumed: the dashboard keeps each run id's latest
## run_end. The app put in the background (maybe killed there) leaves that end as a draft in the
## file, dropped when the app comes back, queued at the next launch otherwise.
## The queue waits in its own file, user://telemetry.json, bounded (TelemetryDef.max_queue), while
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
## What would go if the app, put in the background, never came back: the run's events so far and
## its "abandoned" end, sanitized (queued at the next launch; dropped when the app comes back).
var draft: Array[Dictionary] = []

var _flushing := false
var _retry: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = load(DEFS) as TelemetryDef
	load_state()
	Events.run_started.connect(_on_run_started)
	Events.run_ended.connect(record)
	Events.run_saving.connect(_on_run_saving)
	Events.run_left.connect(_on_run_left)
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
	draft.clear()
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


## The run is being saved: the counts so far go with it.
func _on_run_saving(run: RunState) -> void:
	if tracker and tracker.run == run:
		run.telemetry = tracker.to_data()


## A run ended (Events.run_ended), or was left (`left`: quit to the title, the app closed): its
## events queued, if allowed, then sent. Returns how many were queued. A debug run, or a run
## without consent, queues nothing; a run that goes on (a win, then the endless floors; a run left
## then resumed) is told again at its real end, with more, under the same run id.
func record(summary: RunSummary, left := false) -> int:
	draft.clear()
	if tracker == null or not _allowed(summary):
		if tracker:
			tracker.pending.clear()
		return 0
	var before := queue.size()
	var events := tracker.pending.duplicate()
	tracker.pending.clear()
	var props := tracker.summary(summary, left)
	events.append_array(tracker.pending)
	tracker.pending.clear()
	events.append({ "name": &"run_end", "props": props, "timestamp": now_ms() })
	for event: Dictionary in events:
		_enqueue(event)
	save_state()
	flush()
	return queue.size() - before


## The events may be kept: consent, a server, not a debug run.
func _allowed(summary: RunSummary) -> bool:
	return not summary.debug and not DebugCheats.debug_run and is_active()


## The player left the run without it ending (Events.run_left). For good (the title, the app
## closed): its "abandoned" end queued now, and the run no longer followed (resumed, it is
## followed again from its save). Put in the background: the same end as a draft only (the app
## may come back to the run).
func _on_run_left(summary: RunSummary, for_good: bool) -> void:
	if tracker == null:
		return
	if for_good:
		record(summary, true)
		tracker.unbind()
		tracker = null
		return
	draft.clear()
	if _allowed(summary):
		var events := tracker.pending.duplicate()
		events.append({ "name": &"run_end", "props": tracker.summary(summary, true, false), "timestamp": now_ms() })
		for event: Dictionary in events:
			var item := _prepared(event)
			if not item.is_empty():
				draft.append(item)
	save_state()


## The app came back to the run: the draft is not needed.
func _drop_draft() -> void:
	if draft.is_empty():
		return
	draft.clear()
	save_state()


## Puts `event` in the queue as it will be sent (_prepared()). False if its event is off.
func _enqueue(event: Dictionary) -> bool:
	var item := _prepared(event)
	if item.is_empty():
		return false
	if item.name == "run_end":
		last_summary = item.props
	_push(item)
	return true


## `event` as it will be sent: its event on, its props sanitized, the game's version added.
## Empty if its event is off.
func _prepared(event: Dictionary) -> Dictionary:
	var def := config.event(StringName(event.name))
	if def == null or not def.enabled:
		return {}
	var props: Dictionary = (event.props as Dictionary).duplicate()
	props["v"] = str(ProjectSettings.get_setting("application/config/version", ""))
	return { "name": String(def.name), "props": config.sanitize(def, props), "timestamp": int(event.timestamp) }


## Into the queue, the oldest dropped past max_queue.
func _push(item: Dictionary) -> void:
	queue.append(item)
	while queue.size() > config.max_queue:
		queue.pop_front()


## Everything waiting dropped (consent refused or withdrawn, "delete my online data").
func drop_queue() -> void:
	queue.clear()
	draft.clear()
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
		@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
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
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_drop_draft()
			flush()


# --- The file ------------------------------------------------------------------

func save_state() -> void:
	if path.is_empty():
		return
	SafeFile.write_json(path, { "version": VERSION, "queue": queue, "draft": draft })


## Reads the file; a draft left there (the app killed in the background mid-run) joins the queue.
func load_state() -> void:
	queue.clear()
	draft.clear()
	if path.is_empty():
		return
	var data: Variant = SafeFile.read_json(path)
	if not data is Dictionary:
		return
	var left_over := false
	for key in ["queue", "draft"]:
		var saved: Variant = (data as Dictionary).get(key, [])
		if saved is Array:
			for item: Variant in saved:
				if item is Dictionary and (item as Dictionary).has_all(["name", "props", "timestamp"]):
					_push(item)
					left_over = left_over or key == "draft"
	if left_over:
		save_state()
