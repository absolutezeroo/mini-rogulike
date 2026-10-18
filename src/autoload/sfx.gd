extends Node
## Sound effects player (autoload "Sfx").
## World sounds go through a pool of AudioStreamPlayer2D (panned and attenuated
## around the camera); interface sounds through plain AudioStreamPlayers.

const POOL_2D_SIZE := 24
const POOL_UI_SIZE := 6
## The same sound can play at most MAX_SAME times within SPAM_WINDOW seconds
## (a whirlwind hitting 8 monsters should not play 8 identical hits at once).
const SPAM_WINDOW := 0.06
const MAX_SAME := 2

## Generic sounds, set by the Game from the ContentDB.
var bank := SoundBank.new()
## Master switch (the headless tests turn sound off).
var enabled := true

var _music: AudioStreamPlayer
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _pool_ui: Array[AudioStreamPlayer] = []
var _next_2d := 0
var _next_ui := 0
var _recent := {}  # AudioStream -> PackedFloat64Array of play times


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_2D_SIZE:
		var player := AudioStreamPlayer2D.new()
		player.bus = &"SFX"
		player.max_distance = 1100.0
		player.attenuation = 1.5
		add_child(player)
		_pool_2d.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	_music.volume_db = -8.0
	add_child(_music)
	for i in POOL_UI_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"UI"
		add_child(player)
		_pool_ui.append(player)


## Plays a sound in the world at `position`.
func play_at(stream: AudioStream, position: Vector2, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null or not _allowed(stream):
		return
	var player := _pool_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _pool_2d.size()
	var variation := _pick_variation(stream)
	player.stream = variation[0]
	player.global_position = position
	player.volume_db = volume_db + variation[2]
	player.pitch_scale = pitch * variation[1]
	player.play()


## Plays a non-positional sound (menus, jingles).
func play_ui(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null or not _allowed(stream):
		return
	var player := _pool_ui[_next_ui]
	_next_ui = (_next_ui + 1) % _pool_ui.size()
	var variation := _pick_variation(stream)
	player.stream = variation[0]
	player.volume_db = volume_db + variation[2]
	player.pitch_scale = variation[1]
	player.play()


## AudioStreamRandomizer is used as data (variations + pitch/volume ranges), but we pick
## the variation ourselves: playing the randomizer directly leaks its playbacks in Godot 4.
## Returns [stream, pitch multiplier, volume offset in dB].
func _pick_variation(stream: AudioStream) -> Array:
	var randomizer := stream as AudioStreamRandomizer
	if randomizer == null or randomizer.streams_count == 0:
		return [stream, 1.0, 0.0]
	var picked := randomizer.get_stream(randi() % randomizer.streams_count)
	var pitch_range := maxf(randomizer.random_pitch, 1.0)
	var pitch := exp(randf_range(-log(pitch_range), log(pitch_range)))
	var volume := randf_range(-randomizer.random_volume_offset_db, randomizer.random_volume_offset_db)
	return [picked, pitch, volume]


func _allowed(stream: AudioStream) -> bool:
	if not enabled:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	var times: PackedFloat64Array = _recent.get(stream, PackedFloat64Array())
	var kept := PackedFloat64Array()
	for t in times:
		if now - t < SPAM_WINDOW:
			kept.append(t)
	if kept.size() >= MAX_SAME:
		_recent[stream] = kept
		return false
	kept.append(now)
	_recent[stream] = kept
	return true


## Starts a looping music track, fading from the current one. Same track = keeps playing.
func play_music(stream: AudioStream, volume_db: float = -8.0) -> void:
	if not enabled or stream == null or (_music.stream == stream and _music.playing):
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var tween := create_tween()
	if _music.playing:
		tween.tween_property(_music, "volume_db", -40.0, 0.6)
	tween.tween_callback(func() -> void:
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play())
	tween.tween_property(_music, "volume_db", volume_db, 1.0)


func stop_music() -> void:
	_music.stop()


## Stops everything (used before quitting or when restarting).
func stop_all() -> void:
	_music.stop()
	_music.stream = null
	for player in _pool_2d:
		player.stop()
		player.stream = null
	for player in _pool_ui:
		player.stop()
		player.stream = null
	_recent.clear()
