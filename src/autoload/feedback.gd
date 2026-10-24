extends Node
## "Send feedback" (autoload "Feedback"; docs/online.md "Player feedback", design/interface.md):
## a bug, an idea or anything else the player writes in the form (FeedbackDialog, from the pause
## menu and the title's credits), sent to Talo's game feedback, where it shows in the dashboard
## under its category. The categories, the length limits, the delay between two messages and the
## queue's size are data (data/online/feedback.tres, FeedbackDef).
##
## What goes: the category, the words, and only what the player left ticked: the game's details
## (FeedbackInfo: version, system, device, screen, controls, language, the run, the end of the
## log) and the pseudonym. Sending is the player's own explicit act, for that message only (no
## consent question: docs/privacy-ops.md says why); the form says what is sent. The message is tied
## on Talo to the device's random id (Leaderboards.identity(): the same player as the leaderboards,
## made if there was none), so a deletion request removes it with the rest.
##
## Without network the message waits in its own file, user://feedback.json (at most max_queue,
## the oldest dropped), and goes at the next try (every retry_seconds, when the app comes back, at
## the next launch). One message per min_seconds_between (kept in the file: a restart doesn't
## reset it). A debug build's messages are Talo dev data (TaloBackend's X-Talo-Dev-Build). The tests
## give it no file and the Leaderboards an offline or fake server: never the network.

## The queue or the delay changed (the form follows).
signal changed

const PATH := "user://feedback.json"
const DEFS := "res://data/online/feedback.tres"
const VERSION := 1
## Seconds after the game starts before what waits is sent (the start isn't slowed).
const START_DELAY := 5.0

## What submit() made of a message. QUEUED: kept and on its way. EMPTY, TOO_SHORT, TOO_LONG: the
## words (FeedbackDef's limits). TOO_SOON: wait seconds_to_wait(). UNAVAILABLE: no online
## service in this build. UNKNOWN_CATEGORY: not in the data.
enum Result { QUEUED, EMPTY, TOO_SHORT, TOO_LONG, TOO_SOON, UNAVAILABLE, UNKNOWN_CATEGORY }

## Empty = nothing is read or written (tests).
var path := PATH
var config: FeedbackDef
## Messages waiting to be sent, oldest first: {category (Talo's internal name), comment, props, at}.
var queue: Array[Dictionary] = []
## When the last message was taken (Unix seconds, Privacy.now(); 0: never).
var last_at := 0

var _flushing := false
var _retry: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = load(DEFS) as FeedbackDef
	load_state()
	_retry = Timer.new()
	_retry.one_shot = true
	_retry.timeout.connect(flush)
	add_child(_retry)
	if not queue.is_empty():
		_retry.start(START_DELAY)


## The tests: no file, nothing waiting, no delay.
func use_for_tests() -> void:
	path = ""
	reset()


func reset() -> void:
	queue.clear()
	last_at = 0
	if _retry:
		_retry.stop()


## The game has an online service to send to (an access key in this build).
func is_available() -> bool:
	return Leaderboards.is_available()


## Seconds before another message may be sent (0: now).
func seconds_to_wait() -> int:
	if last_at <= 0:
		return 0
	return maxi(last_at + config.min_seconds_between - Privacy.now(), 0)


## What is wrong with `text` as a message (QUEUED: nothing), before the delay and the service.
func check_text(text: String) -> Result:
	var words := text.strip_edges()
	if words.is_empty():
		return Result.EMPTY
	if words.length() < config.min_length:
		return Result.TOO_SHORT
	if words.length() > config.max_length:
		return Result.TOO_LONG
	return Result.QUEUED


## The player sends `text` to `category` (FeedbackCategoryDef.id). `details`: the game's details
## (FeedbackInfo) if "Include game info" is ticked, else empty; `signed`: the pseudonym goes too
## (only if the player has one). Queued, then sent at once if the network allows.
func submit(category: StringName, text: String, details: Dictionary, signed: bool) -> Result:
	var def := config.category(category)
	if def == null:
		return Result.UNKNOWN_CATEGORY
	var problem := check_text(text)
	if problem != Result.QUEUED:
		return problem
	if not is_available():
		return Result.UNAVAILABLE
	if seconds_to_wait() > 0:
		return Result.TOO_SOON
	var props := FeedbackInfo.clean(details)
	props.erase(TaloBackend.NAME_PROP)
	if signed and not Leaderboards.pseudonym.is_empty():
		props[TaloBackend.NAME_PROP] = Leaderboards.pseudonym
	queue.append({ "category": def.internal_name, "comment": text.strip_edges(), "props": props, "at": Privacy.now() })
	while queue.size() > config.max_queue:
		queue.pop_front()
	last_at = Privacy.now()
	save_state()
	changed.emit()
	flush()
	return Result.QUEUED


## Sends what waits, in order, as the device's player (Leaderboards.identity()). A message the
## server refuses for good (a prop too long) is dropped; without network (or, on Talo, its category
## not made yet in the dashboard: TaloBackend.send_feedback()), tried
## again in retry_seconds. One flush at a time.
func flush() -> void:
	if _flushing or queue.is_empty() or not is_available():
		return
	_flushing = true
	var status := await Leaderboards.identity()
	while status == BoardBackend.Status.OK and not queue.is_empty():
		var item: Dictionary = queue[0]
		@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
		status = await Leaderboards.backend.send_feedback(str(item.category), str(item.comment), item.props)
		if status == BoardBackend.Status.OFFLINE or status == BoardBackend.Status.UNAVAILABLE:
			break
		if not queue.is_empty() and queue[0] == item:
			queue.pop_front()
		status = BoardBackend.Status.OK  # (a refused one is gone: on to the next)
	save_state()
	_flushing = false
	changed.emit()
	if status == BoardBackend.Status.OFFLINE and not queue.is_empty():
		_retry.start(config.retry_seconds)


## "Delete my online data" (Privacy.forget_online()): what waits is dropped.
func forget() -> void:
	queue.clear()
	save_state()
	changed.emit()


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
		"last_at": last_at,
		"queue": queue,
	})


func load_state() -> void:
	reset()
	if path.is_empty():
		return
	var data: Variant = SafeFile.read_json(path)
	if not data is Dictionary:
		return
	last_at = int(data.get("last_at", 0))
	var saved: Variant = data.get("queue", [])
	if saved is Array:
		for item: Variant in saved:
			if item is Dictionary and (item as Dictionary).has_all(["category", "comment", "props"]) and (item as Dictionary).props is Dictionary:
				queue.append(item)
