class_name StoryScreen
extends Control
## The story, page by page, typed out letter by letter. Tap: show the whole page, then the next one.
## Skip jumps to the end. Then goes to `next_scene` (the game on the first run, or the title).

const LETTERS_PER_SECOND := 45.0
const TITLE_SCENE := "res://src/ui/title/title_screen.tscn"

## Where to go once the story is told (set before switching to this scene).
static var next_scene := ""

@export var content: ContentDB

var page := -1
var _typing: Tween

@onready var _text: Label = %Text
@onready var _hint: Label = %Hint
@onready var _hero: AnimatedSprite2D = %Hero


func _ready() -> void:
	get_tree().paused = false
	if content.sounds:
		Sfx.bank = content.sounds
	_hero.sprite_frames = content.player.frames
	_hero.play(&"idle_up")
	var spot: Control = %HeroSpot
	spot.resized.connect(func() -> void: _hero.position.x = spot.size.x * 0.5)
	%SkipButton.pressed.connect(finish)
	next_page()


func pages() -> PackedStringArray:
	return content.story.intro_pages if content.story else PackedStringArray()


func is_typing() -> bool:
	return _typing != null and _typing.is_running()


## Shows the rest of the page, or the next page, or ends the story.
func advance() -> void:
	if is_typing():
		_typing.kill()
		_text.visible_ratio = 1.0
		_hint.show()
	else:
		next_page()


func next_page() -> void:
	page += 1
	if page >= pages().size():
		finish()
		return
	Sfx.play_ui(Sfx.bank.ui_click)
	_text.text = tr(pages()[page])
	_text.visible_ratio = 0.0
	_hint.hide()
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, _text.text.length() / LETTERS_PER_SECOND)
	_typing.tween_callback(_hint.show)


func finish() -> void:
	Profile.mark_intro_seen()
	get_tree().change_scene_to_file(next_scene if not next_scene.is_empty() else TITLE_SCENE)


## Taps arrive as mouse clicks (touch emulates the mouse).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()


## The phone's back button leaves the story (like Skip).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		finish()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		advance()
