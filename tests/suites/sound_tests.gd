class_name SoundTests
extends TestSuite
## Sound, no game running (run by the unit suite): every sound on the bus of its slider, and the
## mix that keeps busy fights under the ceiling.


func run() -> void:
	_test_sound_buses()
	_test_sound_mix()


## Every sound on the bus of its slider: the bus layout, the Sfx players, the scenes' players,
## and which bank sounds each kind of call may play (no interface sound in combat, no combat
## sound in the interface).
func _test_sound_buses() -> void:
	var sends := { &"SFX": &"Master", &"Combat": &"SFX", &"World": &"SFX", &"UI": &"Master", &"Music": &"Master", &"Ambience": &"Master" }
	for bus: StringName in sends:
		var index := AudioServer.get_bus_index(bus)
		check(index > 0 and AudioServer.get_bus_send(index) == sends[bus], "sound: the %s bus sends to %s" % [bus, sends[bus]])
	for bus in Sfx.BUSES:
		check(AudioServer.get_bus_index(bus) > 0, "sound: Sfx's bus %s exists" % bus)
	for key: StringName in Settings.VOLUME_BUSES:
		for bus: StringName in Settings.VOLUME_BUSES[key]:
			check(AudioServer.get_bus_index(bus) >= 0, "sound: %s sets the %s bus" % [key, bus])

	# The Sfx players: a fight sound on Combat, a sound of the place on World, a menu sound on UI.
	var bank := CONTENT.sounds
	Sfx.stop_all()
	Sfx.enabled = true
	Sfx.play_at(bank.monster_hurt, Vector2.ZERO)
	Sfx.play_world(bank.coin, Vector2.ZERO)
	Sfx.play_ui(bank.ui_click)
	check(Sfx.buses_playing(bank.monster_hurt) == [&"Combat"], "sound: play_at plays on the Combat bus (%s)" % [Sfx.buses_playing(bank.monster_hurt)])
	check(Sfx.buses_playing(bank.coin) == [&"World"], "sound: play_world plays on the World bus (%s)" % [Sfx.buses_playing(bank.coin)])
	check(Sfx.buses_playing(bank.ui_click) == [&"UI"], "sound: play_ui plays on the UI bus (%s)" % [Sfx.buses_playing(bank.ui_click)])
	Sfx.stop_all()
	Sfx.enabled = false

	# Every audio player in a scene names one of the sliders' buses (none left on Master).
	var scenes: Array[String] = []
	_collect_files("res://src", ".tscn", scenes)
	_collect_files("res://data", ".tscn", scenes)
	var players := 0
	var node_line := RegEx.create_from_string('^\\[node name="([^"]+)" type="AudioStreamPlayer(2D|3D)?"')
	for path in scenes:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var found := node_line.search(lines[i])
			if found == null:
				continue
			players += 1
			var bus := ""
			for j in range(i + 1, lines.size()):
				if lines[j].begins_with("["):
					break
				if lines[j].begins_with("bus = "):
					bus = lines[j].trim_prefix("bus = ").trim_prefix("&").replace("\"", "")
			check(StringName(bus) in Sfx.BUSES, "sound: %s in %s plays on a slider's bus (%s)" % [found.get_string(1), path.get_file(), bus])
	check(players >= 2, "sound: the scenes' audio players were found (%d)" % players)
	var ambience := FileAccess.get_file_as_string("res://src/world/ambience.tscn")
	check(ambience.count("bus = &\"Ambience\"") == 2, "sound: the floor's loop and the heartbeat play on the Ambience bus")

	# Which kind of call may play each bank sound: play_ui (UI bus), play_at (Combat),
	# play_world (World).
	var allowed := {
		"ui_click": ["play_ui"], "ui_open": ["play_ui"], "ui_close": ["play_ui"], "level_up": ["play_ui"],
		"perk_chosen": ["play_ui"], "stairs": ["play_ui"], "game_over": ["play_ui"], "boss_defeated": ["play_ui"],
		"equip": ["play_ui"],
		"player_hurt": ["play_at"], "player_death": ["play_at"], "monster_hurt": ["play_at"], "monster_death": ["play_at"],
		"monster_alert": ["play_at"], "projectile_impact": ["play_at"], "explosion": ["play_at"],
		"footstep": ["play_world"], "pickup": ["play_world"], "gate": ["play_world"], "fall": ["play_world"],
		# A soul reaching the lantern, or sealed in a curse's card.
		"soul": ["play_world", "play_ui"],
		# Coins: picked up in the world, or counted at the merchant's counter.
		"coin": ["play_world", "play_ui"],
		# A boss waking in the fight, or the Well's roar over a card.
		"boss_roar": ["play_at", "play_ui"],
		# The exits of an ambush room slam (the place), a camp or an arena wakes (the fight).
		"ambush": ["play_at", "play_world"],
	}
	var scripts: Array[String] = []
	_collect_files("res://src", ".gd", scripts)
	var call := RegEx.create_from_string("Sfx\\.(play_at|play_world|play_ui)\\(Sfx\\.bank\\.(\\w+)")
	var calls := 0
	var wrong := PackedStringArray()
	for path in scripts:
		for found in call.search_all(FileAccess.get_file_as_string(path)):
			calls += 1
			var kinds: Array = allowed.get(found.get_string(2), [])
			if not found.get_string(1) in kinds:
				wrong.append("%s: %s(%s)" % [path.get_file(), found.get_string(1), found.get_string(2)])
	check(calls > 50, "sound: the calls were found (%d)" % calls)
	check(wrong.is_empty(), "sound: every bank sound plays on its bus (%s)" % ", ".join(wrong))
	# The place's things never play as fight sounds.
	for path in ["res://src/world/ambience.gd", "res://src/world/room_gates.gd", "res://src/game/hidden_passage.gd",
			"res://src/entities/prop/prop.gd", "res://src/entities/gold/gold_pickup.gd", "res://src/entities/forge/forge.gd",
			"res://src/entities/hazards/crumbling_floor.gd", "res://src/entities/hazards/quicksand.gd",
			"res://src/entities/hazards/heat_source.gd"]:
		var source := FileAccess.get_file_as_string(path)
		check(source.contains("Sfx.play_world(") and not source.contains("Sfx.play_at("), "sound: %s plays on the World bus" % path.get_file())


## The mix keeps busy fights under the ceiling: limiter, voice caps, quieter repeats, no
## shrill pitch, and the old single sound volume carried over to the new sliders.
func _test_sound_mix() -> void:
	var mix := Sfx.mix
	var limiter := _bus_effect(&"Master", "AudioEffectHardLimiter") as AudioEffectHardLimiter
	check(limiter != null and is_equal_approx(limiter.ceiling_db, mix.limiter_ceiling_db) and limiter.ceiling_db < 0.0, "sound: a limiter on Master keeps the output under 0 dB")
	check(_bus_effect(&"Combat", "AudioEffectCompressor") != null, "sound: a compressor on the combat bus")
	for bus: StringName in [&"Combat", &"UI"]:
		var shelf := _bus_effect(bus, "AudioEffectHighShelfFilter") as AudioEffectHighShelfFilter
		check(shelf != null and shelf.gain < 1.0, "sound: the %s bus softens the highs" % bus)
	check(mix.gain_db(&"Combat") < 0.0, "sound: the combat bus leaves headroom")
	check(mix.trim_db(CONTENT.sounds.monster_hurt) < 0.0 and mix.trim_db(CONTENT.sounds.ui_click) == 0.0, "sound: the hot hit sound is trimmed, the others untouched")

	# One swing on a pack: the same hit sound a couple of times, not ten.
	var hit := CONTENT.sounds.monster_hurt
	Sfx.stop_all()
	Sfx.enabled = true
	for i in 10:
		Sfx.play_at(hit, Vector2(i * 10, 0))
	var played := Sfx.buses_playing(hit).size()
	check(played == mix.max_same_in_window, "sound: the same sound started together plays %d times, not 10 (%d)" % [mix.max_same_in_window, played])
	Sfx.stop_all()
	Sfx.enabled = false
	# Random pitch goes down freely, up only a little.
	var soul := CONTENT.sounds.soul as AudioStreamRandomizer
	var highest := 0.0
	var lowest := 9.0
	for i in 300:
		var pitch: float = Sfx._pick_variation(soul)[1]
		highest = maxf(highest, pitch)
		lowest = minf(lowest, pitch)
	check(soul.random_pitch > mix.max_random_pitch_up and highest <= mix.max_random_pitch_up + 0.0001, "sound: random pitch never goes shrill (up to %.3f)" % highest)
	check(lowest < 1.0 / mix.max_random_pitch_up, "sound: ...but still goes down (%.3f)" % lowest)
	for file in DirAccess.get_files_at("res://data/materials"):
		var material := load("res://data/materials/" + file.trim_suffix(".remap")) as ImpactMaterialDef
		if material:
			check(material.volume_db <= -3.0, "sound: %s's hit sits under the cry (%.1f dB)" % [file, material.volume_db])

	# Old settings files: the single sound volume goes to interface, combat and ambience.
	var path := "user://test_settings_sound_%d.cfg" % OS.get_process_id()
	var old := ConfigFile.new()
	old.set_value("options", "music_volume", 0.5)
	old.set_value("options", "sound_volume", 0.4)
	old.save(path)
	Settings.path = path
	Settings.load_settings()
	check(is_equal_approx(Settings.ui_volume, 0.4) and is_equal_approx(Settings.combat_volume, 0.4) and is_equal_approx(Settings.ambience_volume, 0.4), "settings: the old sound volume carries over to each sound slider")
	check(is_equal_approx(Settings.music_volume, 0.5) and is_equal_approx(Settings.master_volume, 1.0), "settings: the music keeps its own, general starts full")
	Settings.apply()
	var combat_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Combat"))
	check(absf(combat_db - (linear_to_db(0.4) + mix.gain_db(&"Combat"))) < 0.01, "settings: the combat slider sets the combat bus, under its headroom (%.1f dB)" % combat_db)
	var world_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"World"))
	check(absf(world_db - (linear_to_db(0.4) + mix.gain_db(&"World"))) < 0.01, "settings: the ambience slider sets the world sounds too (%.1f dB)" % world_db)
	Settings.set_option(&"combat_volume", 0.7)
	Settings.combat_volume = 1.0
	Settings.load_settings()
	check(is_equal_approx(Settings.combat_volume, 0.7) and is_equal_approx(Settings.ui_volume, 0.4), "settings: once saved, the new volumes are read back")
	var saved := ConfigFile.new()
	saved.load(path)
	check(not saved.has_section_key("options", "sound_volume"), "settings: the old key is not written again")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings.path = ""
	for key: StringName in Settings.VOLUME_BUSES:
		Settings.set(key, 0.8 if key == &"music_volume" else 1.0)
	Settings.apply()


func _bus_effect(bus_name: StringName, type: String) -> AudioEffect:
	var bus := AudioServer.get_bus_index(bus_name)
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i).is_class(type):
			return AudioServer.get_bus_effect(bus, i)
	return null


func _collect_files(dir: String, suffix: String, into: Array[String]) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(suffix):
			into.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		_collect_files(dir.path_join(sub), suffix, into)
