class_name ShaderWarmup
extends CanvasLayer
## Draws every effect shader once, the moment the game starts, under the world where nobody sees
## it, so the GPU compiles them then rather than in the middle of the first fight (a hitch the
## first time a Frost Nova or a campfire shows on a phone). Gone after a few frames.

## Frames it stays (a shader may compile over a frame or two).
const FRAMES := 3

var _left := FRAMES


## Starts the warm-up under `host`'s tree (ScreenEffects at load).
static func run(host: Node) -> ShaderWarmup:
	var warmup := ShaderWarmup.new()
	warmup.layer = -100  # under the world: drawn first, covered by the floor
	host.add_child.call_deferred(warmup)
	return warmup


func _ready() -> void:
	for shader in FxLook.ALL:
		var look := ShaderMaterial.new()
		look.shader = shader
		var dot := ColorRect.new()
		dot.size = Vector2.ONE
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.material = look
		add_child(dot)


func _process(_delta: float) -> void:
	_left -= 1
	if _left <= 0:
		queue_free()


## The shaders it draws (tests).
static func shaders() -> Array[Shader]:
	return FxLook.ALL
