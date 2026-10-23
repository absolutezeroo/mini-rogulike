class_name TaloBackend
extends BoardBackend
## The online leaderboards on Talo (https://trytalo.com), through its REST API with HTTPRequest
## (docs/online.md says why not its Godot plugin). Four endpoints: identify a player, set its
## name (a player prop, the game's "display name prop key"), add an entry, list entries.
##
## The access key is never in git: it is read from the environment (TALO_ACCESS_KEY) or from
## res://online/talo.cfg, a file git ignores, packed into the builds by the presets'
## include_filter (online/talo.cfg.example shows its form). Without one the game is offline.

const KEY_FILE := "res://online/talo.cfg"
const KEY_ENV := "TALO_ACCESS_KEY"
const DEFAULT_URL := "https://api.trytalo.com"
## Players are identified by a random id made on the device, under this service name.
const SERVICE := "device"
## The player prop holding the pseudonym (set it as the game's display name prop key).
const NAME_PROP := "name"
## Seconds a request may take.
const TIMEOUT := 15.0

var _key := ""
var _url := DEFAULT_URL
var _alias_id := 0
var _player_id := ""


## Reads the key (read_key()) unless one is given (a smoke test with its own).
func _init(key: String = "", url: String = "") -> void:
	name = "Talo"
	if key.is_empty():
		var found := read_key()
		key = found.key
		url = found.url if url.is_empty() else url
	_key = key.strip_edges()
	_url = (url if not url.is_empty() else DEFAULT_URL).trim_suffix("/")


## {key, url} from the environment or KEY_FILE (empty key: none). Never printed anywhere.
static func read_key(path: String = KEY_FILE) -> Dictionary:
	var key := OS.get_environment(KEY_ENV).strip_edges()
	var url := ""
	if key.is_empty() and FileAccess.file_exists(path):
		var file := ConfigFile.new()
		if file.load(path) == OK:
			key = str(file.get_value("talo", "access_key", "")).strip_edges()
			url = str(file.get_value("talo", "api_url", ""))
	return { "key": key, "url": url }


func is_configured() -> bool:
	return not _key.is_empty()


func alias_id() -> int:
	return _alias_id


func identify(device_id: String) -> Status:
	var answer := await _request(HTTPClient.METHOD_GET, "/v1/players/identify?service=%s&identifier=%s" % [SERVICE, device_id.uri_encode()])
	if answer.status != Status.OK:
		return answer.status
	var alias: Variant = (answer.body as Dictionary).get("alias") if answer.body is Dictionary else null
	if not alias is Dictionary or not (alias as Dictionary).get("player") is Dictionary:
		return Status.REJECTED
	_alias_id = int((alias as Dictionary).get("id", 0))
	_player_id = str(((alias as Dictionary).player as Dictionary).get("id", ""))
	return Status.OK if _alias_id > 0 and not _player_id.is_empty() else Status.REJECTED


func set_pseudonym(pseudonym: String) -> Status:
	if _player_id.is_empty():
		return Status.OFFLINE
	var answer := await _request(HTTPClient.METHOD_PATCH, "/v1/players/%s" % _player_id.uri_encode(), {
		"props": [{ "key": NAME_PROP, "value": pseudonym }],
	})
	return answer.status


func submit(board: LeaderboardDef, score: float, period_key: String, props: Dictionary) -> BoardBackend.Sent:
	var sent := BoardBackend.Sent.new()
	if _alias_id == 0:
		sent.status = Status.OFFLINE
		return sent
	var list: Array = []
	for key: String in props:
		list.append({ "key": key, "value": str(props[key]) })
	var answer := await _request(HTTPClient.METHOD_POST, "/v1/leaderboards/%s/entries" % board.talo_name.uri_encode(), {
		"score": score,
		"props": list,
	})
	sent.status = answer.status
	if answer.status == Status.OK and answer.body is Dictionary and (answer.body as Dictionary).get("entry") is Dictionary:
		sent.rank = int(((answer.body as Dictionary).entry as Dictionary).get("position", -1)) + 1
	return sent


func fetch(board: LeaderboardDef, period_key: String, past: bool, page: int) -> BoardBackend.Page:
	return await _list(board, period_key, past, "page=%d" % page)


func fetch_mine(board: LeaderboardDef, period_key: String, past: bool) -> BoardBackend.Page:
	if _alias_id == 0:
		var none := BoardBackend.Page.new()
		none.status = Status.OFFLINE
		return none
	var mine := await _list(board, period_key, past, "page=0&aliasId=%d" % _alias_id)
	# The server ranks the player among every entry it keeps: archived ones are every past day's.
	mine.ranks_reliable = not past
	return mine


func _list(board: LeaderboardDef, period_key: String, past: bool, query: String) -> BoardBackend.Page:
	var path := "/v1/leaderboards/%s/entries?%s" % [board.talo_name.uri_encode(), query]
	if past:
		path += "&withDeleted=1"
	if not period_key.is_empty():
		path += "&propKey=%s&propValue=%s" % [Leaderboards.period_prop(board), period_key.uri_encode()]
	var answer := await _request(HTTPClient.METHOD_GET, path)
	var page := BoardBackend.Page.new()
	page.status = answer.status
	if answer.status != Status.OK or not answer.body is Dictionary:
		if answer.status == Status.OK:
			page.status = Status.REJECTED
		return page
	var body := answer.body as Dictionary
	page.total = int(body.get("count", 0))
	page.last_page = bool(body.get("isLastPage", true))
	var entries: Variant = body.get("entries", [])
	if entries is Array:
		for data: Variant in entries:
			if data is Dictionary:
				page.entries.append(_entry(data))
	return page


## A line of a board from the server's entry.
static func _entry(data: Dictionary) -> BoardBackend.Entry:
	var entry := BoardBackend.Entry.new()
	entry.rank = int(data.get("position", 0)) + 1
	entry.score = float(data.get("score", 0.0))
	var props_list: Variant = data.get("props", [])
	if props_list is Array:
		for prop: Variant in props_list:
			if prop is Dictionary:
				entry.props[str((prop as Dictionary).get("key", ""))] = str((prop as Dictionary).get("value", ""))
	var alias: Variant = data.get("playerAlias", {})
	if alias is Dictionary:
		entry.alias_id = int((alias as Dictionary).get("id", 0))
		var shown := str((alias as Dictionary).get("displayName", ""))
		# No display name prop key in the dashboard: Talo shows the device id; the entry's own
		# copy of the name then.
		if shown.is_empty() or shown == str((alias as Dictionary).get("identifier", "")):
			shown = str(entry.props.get(NAME_PROP, ""))
		entry.name = shown
	return entry


## One request: {status, code, body (parsed JSON or null)}.
func _request(method: HTTPClient.Method, path: String, body: Variant = null) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	http.accept_gzip = true
	add_child(http)
	var headers := PackedStringArray([
		"Authorization: Bearer %s" % _key,
		"Content-Type: application/json",
		"Accept: application/json",
		# A build from the editor (debug) is development data: kept apart in the dashboard, and
		# it sees its own entries.
		"X-Talo-Dev-Build: %s" % ("1" if OS.is_debug_build() else "0"),
		"X-Talo-Include-Dev-Data: %s" % ("1" if OS.is_debug_build() else "0"),
	])
	if _alias_id > 0:
		headers.append("X-Talo-Alias: %d" % _alias_id)
		headers.append("X-Talo-Player: %s" % _player_id)
	var error := http.request(_url + path, headers, method, JSON.stringify(body) if body != null else "")
	if error != OK:
		http.queue_free()
		return { "status": Status.OFFLINE, "code": 0, "body": null }
	var result: Array = await http.request_completed
	http.queue_free()
	var code: int = result[1]
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8()) if (result[3] as PackedByteArray).size() > 0 else null
	var status := Status.OK
	if result[0] != HTTPRequest.RESULT_SUCCESS or code == 0 or code == 429 or code >= 500:
		status = Status.OFFLINE
	elif code >= 400:
		status = Status.REJECTED
	return { "status": status, "code": code, "body": parsed }
