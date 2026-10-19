class_name ScreenEffects
extends ColorRect
## Full-screen post-process over the world (see assets/shaders/screen.gdshader).
## Works in the game's pixel grid: one art pixel = 2 world pixels x the camera zoom.
## kick() shakes the colors apart for a moment on big impacts.

const ART_PIXEL := 2.0
const KICK_FADE := 6.0  # art pixels lost per second

var _aberration := 0.0


func _ready() -> void:
	add_to_group(&"screen_effects")
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)


## The floor's look: grading, saturation, contrast, bloom, heat haze (null: neutral).
func set_mood(def: AmbienceDef) -> void:
	var shader := material as ShaderMaterial
	var neutral := AmbienceDef.new() if def == null else def
	shader.set_shader_parameter("shadow_tint", neutral.grade_shadows)
	shader.set_shader_parameter("highlight_tint", neutral.grade_highlights)
	shader.set_shader_parameter("grade", neutral.grade_strength)
	shader.set_shader_parameter("saturation", neutral.saturation)
	shader.set_shader_parameter("contrast", neutral.contrast)
	shader.set_shader_parameter("bloom", neutral.bloom)
	shader.set_shader_parameter("haze", neutral.heat_haze)
	shader.set_shader_parameter("vignette_color", neutral.vignette_color)
	shader.set_shader_parameter("vignette_pulse", neutral.vignette_pulse)
	shader.set_shader_parameter("moon_color", neutral.moon_color)


func kick(strength: float = 1.0) -> void:
	_aberration = maxf(_aberration, 2.0 * strength)


func _process(delta: float) -> void:
	var shader := material as ShaderMaterial
	var camera := get_viewport().get_camera_2d()
	var zoom := camera.zoom.x if camera else 1.0
	shader.set_shader_parameter("art_pixel", Vector2.ONE * ART_PIXEL * zoom / get_viewport_rect().size)
	if _aberration > 0.0:
		_aberration = maxf(_aberration - KICK_FADE * delta, 0.0)
		shader.set_shader_parameter("aberration", _aberration)
