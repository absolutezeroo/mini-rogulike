class_name InfoPanel
extends Control
## A page of text to read over whatever is open (the privacy policy, the credits, a licence): a
## MenuWindow with its title, a column that scrolls (by touch, the mouse wheel, or the keys and
## gamepad: MenuNav scrolls a box with nothing to focus) and Close. Whoever opens it closes it on
## Back (its back()), like the other panels. Reachable as %Content, %Scroll, %CloseButton.

signal closed

## The text's width at most (lines longer than this are hard to read on a computer).
const READING_WIDTH := 980.0

var window: MenuWindow
## Where the page's contents go.
var content: VBoxContainer
var scroll: ScrollContainer


func _init(title_text: String = "") -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	window = MenuWindow.new(title_text)
	window.close_requested.connect(close)
	add_child(window)
	MenuWindow.expose(window.close_button, "CloseButton", self)
	scroll = UiParts.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window.body.add_child(scroll)
	MenuWindow.expose(scroll, "Scroll", self)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.use_top_left = false
	scroll.add_child(center)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	center.add_child(content)
	MenuWindow.expose(content, "Content", self)
	resized.connect(_fit_width)


## Shows it at its top.
func open() -> void:
	show()
	_fit_width()
	scroll.scroll_vertical = 0


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()


## Back: closes it. False if it wasn't open.
func back() -> bool:
	if not visible:
		return false
	close()
	return true


## A paragraph that wraps at the page's width.
func paragraph(text: String, color: Color = UiSkin.TEXT) -> Label:
	var label := UiSkin.label(text, Fonts.BODY, color, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(label)
	return label


## A gold heading.
func heading(text: String) -> Label:
	var label := UiSkin.label(text, Fonts.BODY, UiSkin.GOLD, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(label)
	return label


func _fit_width() -> void:
	# The column as wide as the window allows, but never wider than a comfortable line.
	var room := size.x - RpgWindow.MARGIN.x * 2.0 - 80.0
	content.custom_minimum_size.x = clampf(room, 200.0, READING_WIDTH)
