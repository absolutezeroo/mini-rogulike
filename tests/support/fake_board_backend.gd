class_name FakeBoardBackend
extends BoardBackend
## A leaderboard server in memory for the tests and the page's screenshots: no network. It acts
## like the Talo boards the game uses (one entry per player and period, kept only if better,
## ranks counted in the period asked for) and can be switched off (`online`) to test the queue.

## Answers at all (false: every call is OFFLINE, like a phone without network).
var online := true
## Has an access key (false: like a build without one).
var configured := true
## Every score sent: {board, score, period, props}.
var sent: Array[Dictionary] = []
## Board talo_name -> period -> [{alias, name, score, props}].
var boards := {}
## alias id -> name (set_pseudonym()).
var names := {}
## Seconds each answer takes (the page's loading state in a screenshot).
var delay := 0.0

var _alias := 0


func is_configured() -> bool:
	return configured


func alias_id() -> int:
	return _alias


func identify(device_id: String) -> Status:
	if not await _answers():
		return Status.OFFLINE
	_alias = absi(hash(device_id)) % 100000 + 1
	return Status.OK


func set_pseudonym(pseudonym: String) -> Status:
	if not await _answers():
		return Status.OFFLINE
	names[_alias] = pseudonym
	return Status.OK


func submit(board: LeaderboardDef, score: float, period_key: String, props: Dictionary) -> BoardBackend.Sent:
	var result := BoardBackend.Sent.new()
	if not await _answers():
		result.status = Status.OFFLINE
		return result
	sent.append({ "board": board.talo_name, "score": score, "period": period_key, "props": props })
	var list := _list(board, period_key)
	var found := false
	for line: Dictionary in list:
		if line.alias == _alias:
			found = true
			if (score > line.score) if board.higher_first else (score < line.score):
				line.score = score
				line.props = props
	if not found:
		list.append({ "alias": _alias, "name": str(props.get("name", "")), "score": score, "props": props })
	result.status = Status.OK
	for entry in _ranked(board, period_key):
		if entry.alias_id == _alias:
			result.rank = entry.rank
	return result


func fetch(board: LeaderboardDef, period_key: String, _past: bool, page: int) -> BoardBackend.Page:
	var result := BoardBackend.Page.new()
	if not await _answers():
		result.status = Status.OFFLINE
		return result
	var ranked := _ranked(board, period_key)
	result.status = Status.OK
	result.total = ranked.size()
	result.entries.assign(ranked.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE))
	result.last_page = (page + 1) * PAGE_SIZE >= ranked.size()
	return result


func fetch_mine(board: LeaderboardDef, period_key: String, _past: bool) -> BoardBackend.Page:
	var result := BoardBackend.Page.new()
	if not await _answers():
		result.status = Status.OFFLINE
		return result
	result.status = Status.OK
	for entry in _ranked(board, period_key):
		if entry.alias_id == _alias:
			result.entries.append(entry)
	return result


## `count` other players on `board` for `period_key`, scores falling from `best` (screenshots,
## tests). `names_from`: their names, in turn.
func fill(board: LeaderboardDef, period_key: String, count: int, best: float, step: float, names_from: PackedStringArray) -> void:
	var list := _list(board, period_key)
	for i in count:
		var name := names_from[i % names_from.size()]
		if i >= names_from.size():
			name += " %d" % (i / names_from.size() + 1)
		list.append({ "alias": 900000 + i, "name": name, "score": best - i * step, "props": {} })


func _answers() -> bool:
	if delay > 0.0:
		await get_tree().create_timer(delay, true, false, true).timeout
	return online


func _list(board: LeaderboardDef, period_key: String) -> Array:
	if not boards.has(board.talo_name):
		boards[board.talo_name] = {}
	var periods: Dictionary = boards[board.talo_name]
	if not periods.has(period_key):
		periods[period_key] = []
	return periods[period_key]


func _ranked(board: LeaderboardDef, period_key: String) -> Array[BoardBackend.Entry]:
	var list := _list(board, period_key).duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.score > b.score if board.higher_first else a.score < b.score)
	var result: Array[BoardBackend.Entry] = []
	for i in list.size():
		var line: Dictionary = list[i]
		var entry := BoardBackend.Entry.new()
		entry.rank = i + 1
		entry.alias_id = line.alias
		entry.name = names.get(line.alias, line.name)
		entry.score = line.score
		entry.props = line.props
		result.append(entry)
	return result
