class_name GoldBurst
extends Control
## Coins bursting out of a spot of a menu and flying to the gold counter, with "+12 gold" rising
## where they started (gear dismantled in the bag). Runs while the game is paused; frees itself.

const TEXTURE: Texture2D = preload("res://assets/items/gold_coin.png")
const DURATION := 0.9
const MAX_COINS := 14

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _text := ""
var _time := 0.0
## Each coin: { "out": Vector2 (where it bursts to), "delay": float }.
var _coins: Array[Dictionary] = []


## Plays it over `parent` (a full-screen menu): from `from` to `to`, both global positions.
static func play(parent: Control, from: Vector2, to: Vector2, gold: int) -> GoldBurst:
	var burst := GoldBurst.new()
	burst._text = TranslationServer.tr("+%d gold") % gold
	burst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(burst)
	burst._from = from - burst.global_position
	burst._to = to - burst.global_position
	for i in clampi(5 + int(gold / 4.0), 5, MAX_COINS):
		burst._coins.append({
			"out": Vector2.from_angle(randf() * TAU) * randf_range(30.0, 80.0),
			"delay": randf() * 0.15,
		})
	return burst


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION + 0.3:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var coin_size := TEXTURE.get_size() * 3.0
	for coin in _coins:
		var t := clampf((_time - float(coin.delay)) / DURATION, 0.0, 1.0)
		if t <= 0.0 or t >= 1.0:
			continue
		# Out in a ring first, then pulled to the counter.
		var out: Vector2 = _from + coin.out
		var at := _from.lerp(out, ease(minf(t * 3.0, 1.0), 0.4)) if t < 0.33 else out.lerp(_to, ease((t - 0.33) / 0.67, 2.2))
		draw_texture_rect(TEXTURE, Rect2(at - coin_size * 0.5, coin_size), false)
	var rise := clampf(_time / (DURATION + 0.3), 0.0, 1.0)
	var alpha := 1.0 - maxf(rise - 0.6, 0.0) / 0.4
	Fonts.draw(self, _from + Vector2(0, -20.0 - 40.0 * rise), _text, Fonts.TITLE, Color(UiSkin.GOLD, alpha), 0.5, Color(Fonts.OUTLINE, alpha))
