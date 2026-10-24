class_name FeedbackInfo
extends RefCounted
## The game's details a feedback message carries when the player leaves "Include game info"
## ticked (Feedback, FeedbackDialog; docs/online.md "Player feedback"): what makes a bug report
## readable without asking back. Plain props (String -> String, each inside Talo's 512
## characters), never the pseudonym (that one is its own tick), never an id of the device.
##
## game(): the version and build, the system, the device's model, the screen and window, the
## controls in use, the language. run(): where the run is (floor, act, biome, place), its
## difficulty, ascension, oath, time and level, and the build (RunTelemetry.build_of()).
## log_tail(): the last lines of the game's log file, with the folders that could name the player
## (their home, the game's data folder) replaced by "~".

## Talo refuses a prop value past 512 characters; a log line is cut well before.
const MAX_VALUE := 500
const MAX_LOG_LINE := 300


## The game, the device, the controls, the language.
static func game() -> Dictionary:
	var props := {
		"v": str(ProjectSettings.get_setting("application/config/version", "")),
		"build": "debug" if OS.is_debug_build() else "release",
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"device": OS.get_model_name(),
		"input": String(InputDevice.Kind.keys()[InputDevice.kind]).to_lower(),
		"lang": TranslationServer.get_locale(),
	}
	if DisplayServer.get_name() != "headless":
		var screen := DisplayServer.screen_get_size()
		var window := DisplayServer.window_get_size()
		props["screen"] = "%dx%d" % [screen.x, screen.y]
		props["window"] = "%dx%d" % [window.x, window.y]
	if InputDevice.uses_gamepad() and InputDevice.family != &"":
		props["pad"] = String(InputDevice.family)
	return props


## The run going on (empty without one): where, how hard, how long, and the build.
static func run(state: RunState, hero: Player, content: ContentDB, biome: BiomeDef = null) -> Dictionary:
	var props := {}
	if state == null:
		return props
	props["depth"] = str(state.depth)
	if content and content.dungeon:
		props["act"] = str(content.dungeon.act_index(state.depth) + 1)
		props["place"] = state.place_name_key(content)
	if biome:
		props["biome"] = String(biome.id)
	props["diff"] = String(state.difficulty.id) if state.difficulty else ""
	props["asc"] = str(state.difficulty.ascension if state.difficulty else 0)
	props["daily"] = "1" if state.is_daily() else "0"
	if state.oath:
		props["oath"] = String(state.oath.id)
	props["time"] = "%.0f" % state.run_time()
	if hero and is_instance_valid(hero):
		props["level"] = str(hero.level)
		var build := RunTelemetry.build_of(hero)
		for key: String in build:
			props[key] = str(build[key])
	return props


## The last `lines` lines of the game's log (Godot's file log, when the platform keeps one:
## desktop builds do, Android doesn't by default), as "log.01", "log.02"... (empty: no log).
static func log_tail(lines: int) -> Dictionary:
	var props := {}
	if lines <= 0:
		return props
	var path := str(ProjectSettings.get_setting("debug/file_logging/log_path", "user://logs/godot.log"))
	if not FileAccess.file_exists(path):
		return props
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return props
	var text := file.get_as_text()
	file.close()
	var kept := PackedStringArray()
	for line in text.split("\n", false):
		var trimmed := line.strip_edges()
		if not trimmed.is_empty():
			kept.append(trimmed)
	var start := maxi(kept.size() - lines, 0)
	for i in range(start, kept.size()):
		props["log.%02d" % (i - start + 1)] = scrub(kept[i]).left(MAX_LOG_LINE)
	return props


## `line` without the folders that could name the player: their home and the game's data folder
## become "~".
static func scrub(line: String) -> String:
	var result := line
	var folders: Array[String] = [OS.get_user_data_dir(), OS.get_environment("USERPROFILE"), OS.get_environment("HOME")]
	for folder in folders:
		if folder.length() < 3:
			continue
		result = result.replace(folder, "~").replace(folder.replace("\\", "/"), "~").replace(folder.replace("/", "\\"), "~")
	return result


## Every value a string inside Talo's limit.
static func clean(props: Dictionary) -> Dictionary:
	var result := {}
	for key: Variant in props:
		var value := str(props[key])
		if not value.is_empty():
			result[str(key).left(128)] = value.left(MAX_VALUE)
	return result
