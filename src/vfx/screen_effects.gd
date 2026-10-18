class_name ScreenEffects
extends ColorRect
## Full-screen post-process over the world (see assets/shaders/screen.gdshader).
## kick() shakes the colors apart for a moment on big impacts.

const KICK_FADE := 6.0  # pixels lost per second

var _aberration := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)


func kick(strength: float = 1.0) -> void:
	_aberration = maxf(_aberration, 4.0 * strength)


func _process(delta: float) -> void:
	if _aberration > 0.0:
		_aberration = maxf(_aberration - KICK_FADE * delta, 0.0)
		(material as ShaderMaterial).set_shader_parameter("aberration", _aberration)
