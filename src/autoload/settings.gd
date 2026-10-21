extends Node
## Player options (autoload "Settings"): volumes, screen shake, vibrations, size of the touch
## controls, fixed or floating joystick, battery saver (30 FPS), fewer effects, tutorial hints, run timer,
## language (English or French: TranslationServer's locale, see locale/strings.csv).
## Saved in user://settings.cfg and applied as soon as they change.

signal changed

const PATH := "user://settings.cfg"
## Each volume and the buses it sets (see Sfx: which sound plays on which bus).
const VOLUME_BUSES := {
	&"master_volume": [&"Master"],
	&"music_volume": [&"Music"],
	&"ui_volume": [&"UI"],
	&"combat_volume": [&"Combat"],
	&"ambience_volume": [&"World", &"Ambience"],
}
## Older settings files have one "sound_volume" for interface, combat and ambience together:
## it is given to each of them.
const OLD_SOUND_KEY := "sound_volume"
const SPLIT_SOUND_KEYS: Array[String] = ["ui_volume", "combat_volume", "ambience_volume"]
const MIN_VIBRATION_GAP_MS := 50
const KEYS: Array[String] = ["master_volume", "music_volume", "ui_volume", "combat_volume", "ambience_volume", "screen_shake", "vibrations", "controls_scale", "fixed_joystick", "battery_saver", "fewer_effects", "tutorial_hints", "run_timer", "language"]
## Frames per second: normal (0 = no cap), and with the battery saver.
const FPS := 0
const SAVER_FPS := 30
## The game's languages (locale codes, see locale/strings.csv) and their names, each in itself.
const LANGUAGES: Array[String] = ["en", "fr"]
const LANGUAGE_NAMES := { "en": "English", "fr": "Français" }

## Empty = nothing is read or written (tests).
var path := PATH
## 0..1 each (see VOLUME_BUSES).
var master_volume := 1.0
var music_volume := 0.8
var ui_volume := 1.0
var combat_volume := 1.0
var ambience_volume := 1.0
## Multiplies every camera shake (0 = none).
var screen_shake := 1.0
var vibrations := true
## Size of the on-screen joystick and buttons.
var controls_scale := 1.0
## The joystick stays in its corner (touch it there) instead of appearing under the thumb.
var fixed_joystick := false
## 30 frames per second instead of 60: the phone lasts longer and stays cooler.
var battery_saver := false
## Half the particles (sparks, chunks, dust): for older phones.
var fewer_effects := false
## Tutorial hints (see Tutorial): on until turned off.
var tutorial_hints := true
## The run's time on the HUD, with the splits of each floor (for speedrunners).
var run_timer := true
## "en" or "fr". On first launch, the phone's language (French if it is French, else English).
var language := device_language()

var _last_vibration := 0


func _ready() -> void:
	load_settings()
	apply()


## Changes one option (by name), applies and saves it.
func set_option(key: StringName, value: Variant) -> void:
	set(key, value)
	apply()
	save_settings()
	changed.emit()


func apply() -> void:
	for key: StringName in VOLUME_BUSES:
		for bus: StringName in VOLUME_BUSES[key]:
			_set_bus_volume(bus, get(key))
	Engine.max_fps = SAVER_FPS if battery_saver else FPS
	if TranslationServer.get_locale() != language:
		TranslationServer.set_locale(language)


## The device's language if the game speaks it, else English.
static func device_language() -> String:
	return "fr" if OS.get_locale_language() == "fr" else "en"


## A short buzz on phones (0..1). Does nothing on computers or when vibrations are off.
func vibrate(strength: float) -> void:
	if not vibrations or not OS.has_feature("mobile"):
		return
	# Many hits in a row make one buzz, not a drone.
	var now := Time.get_ticks_msec()
	if now - _last_vibration < MIN_VIBRATION_GAP_MS:
		return
	_last_vibration = now
	strength = clampf(strength, 0.0, 1.0)
	Input.vibrate_handheld(roundi(lerpf(12.0, 70.0, strength)), lerpf(0.25, 1.0, strength))


func save_settings() -> void:
	if path.is_empty():
		return
	var file := ConfigFile.new()
	for key in KEYS:
		file.set_value("options", key, get(key))
	file.save(path)


func load_settings() -> void:
	if path.is_empty():
		return
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for key: StringName in VOLUME_BUSES:
		set(key, clampf(float(file.get_value("options", key, get(key))), 0.0, 1.0))
	if file.has_section_key("options", OLD_SOUND_KEY) and not file.has_section_key("options", "combat_volume"):
		var old := clampf(float(file.get_value("options", OLD_SOUND_KEY)), 0.0, 1.0)
		for key in SPLIT_SOUND_KEYS:
			set(key, old)
	screen_shake = float(file.get_value("options", "screen_shake", screen_shake))
	vibrations = bool(file.get_value("options", "vibrations", vibrations))
	controls_scale = clampf(float(file.get_value("options", "controls_scale", controls_scale)), 0.7, 1.3)  # bigger would cover the minimap
	fixed_joystick = bool(file.get_value("options", "fixed_joystick", fixed_joystick))
	battery_saver = bool(file.get_value("options", "battery_saver", battery_saver))
	fewer_effects = bool(file.get_value("options", "fewer_effects", fewer_effects))
	tutorial_hints = bool(file.get_value("options", "tutorial_hints", tutorial_hints))
	run_timer = bool(file.get_value("options", "run_timer", run_timer))
	language = str(file.get_value("options", "language", language))
	if not language in LANGUAGES:
		language = device_language()


## The slider's volume on top of the bus's own gain in the mix (headroom, see SoundMixDef).
func _set_bus_volume(bus_name: StringName, volume: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)) + Sfx.mix.gain_db(bus_name))
