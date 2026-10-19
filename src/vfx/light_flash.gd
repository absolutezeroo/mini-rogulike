class_name LightFlash
extends PointLight2D
## A burst of light that fades out (explosions, big impacts).

const DURATION := 0.35


func setup(flash_color: Color, size: float) -> void:
	color = flash_color
	energy = 1.1 * FlickerLight.floor_strength
	texture_scale = size / 128.0


func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(self, "energy", 0.0, DURATION).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)
