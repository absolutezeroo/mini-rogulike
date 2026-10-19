class_name OptionsPanel
extends Control
## Options window (title screen and pause menu): volumes, screen shake, vibrations, size of
## the touch controls, fixed joystick, battery saver, fewer effects. Every change goes straight
## to Settings (applied and saved).

signal closed

@onready var _music: HSlider = %MusicSlider
@onready var _sounds: HSlider = %SoundSlider
@onready var _shake: HSlider = %ShakeSlider
@onready var _controls: HSlider = %ControlsSlider
@onready var _vibrations: CheckButton = %VibrationsCheck
## Plain on/off options: check -> Settings key.
@onready var _checks := {
	%FixedStickCheck: &"fixed_joystick",
	%BatteryCheck: &"battery_saver",
	%FewerEffectsCheck: &"fewer_effects",
}


func _ready() -> void:
	hide()
	_bind_slider(_music, &"music_volume")
	_bind_slider(_sounds, &"sound_volume")
	_bind_slider(_shake, &"screen_shake")
	_bind_slider(_controls, &"controls_scale")
	_vibrations.toggled.connect(func(on: bool) -> void:
		Settings.set_option(&"vibrations", on)
		if on:
			Settings.vibrate(0.6))
	for check: CheckButton in _checks:
		var key: StringName = _checks[check]
		check.toggled.connect(func(on: bool) -> void:
			Settings.set_option(key, on)
			Sfx.play_ui(Sfx.bank.ui_click))
	%CloseButton.pressed.connect(close)


func open() -> void:
	_music.set_value_no_signal(Settings.music_volume)
	_sounds.set_value_no_signal(Settings.sound_volume)
	_shake.set_value_no_signal(Settings.screen_shake)
	_controls.set_value_no_signal(Settings.controls_scale)
	_vibrations.set_pressed_no_signal(Settings.vibrations)
	for check: CheckButton in _checks:
		check.set_pressed_no_signal(Settings.get(_checks[check]))
	show()


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()


func _bind_slider(slider: HSlider, option: StringName) -> void:
	slider.value_changed.connect(func(value: float) -> void: Settings.set_option(option, value))
	# A click when letting go, to hear the new sound volume.
	slider.drag_ended.connect(func(_changed: bool) -> void: Sfx.play_ui(Sfx.bank.ui_click))
