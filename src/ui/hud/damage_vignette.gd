class_name DamageVignette
extends ColorRect
## Red flash on the screen edges when the player gets hurt, and a slow pulse when HP is low.

const LOW_HP_RATIO := 0.3
const FLASH_INTENSITY := 0.75
const FLASH_FADE := 2.5  # intensity lost per second

var _flash := 0.0
var _low_hp := false
var _time := 0.0
var _last_hp := -1


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://assets/shaders/vignette.gdshader")
	material = shader_material


## Connect to Player.health_changed.
func on_health_changed(current: int, maximum: int) -> void:
	if _last_hp >= 0 and current < _last_hp:
		_flash = FLASH_INTENSITY
	_last_hp = current
	_low_hp = current > 0 and float(current) / maximum <= LOW_HP_RATIO


func reset() -> void:
	_flash = 0.0
	_last_hp = -1
	_low_hp = false


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - FLASH_FADE * delta, 0.0)
	var pulse := (0.25 + 0.15 * sin(_time * 5.0)) if _low_hp else 0.0
	(material as ShaderMaterial).set_shader_parameter("intensity", maxf(_flash, pulse))
