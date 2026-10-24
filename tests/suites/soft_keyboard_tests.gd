class_name SoftKeyboardTests
extends TestSuite
## Typing on a phone (SoftKeyboard, PixelGrid): the phone's keyboard shrinks the window to the
## strip above it (Android's adjustResize). run_title(), in French on a 2340x1080 phone with a fake
## keyboard (SoftKeyboard.fake_height): the UI keeps its x1.5 scale, the field shows in a bar inside
## the strip, its words at BODY size or more, for the feedback form (several lines) and the
## pseudonym (one line); taps on the backdrop leave the focus in the field; OK and the keyboard
## going give the dialog back as it was. A keyboard drawn over the game (no resize) keeps the bar
## above it. Without a virtual keyboard (a computer), a short window scales as it always did.

const PixelGridScript := preload("res://src/autoload/pixel_grid.gd")  # its static helpers are called on the script, not the autoload

const PHONE := Vector2i(2340, 1080)
## The strip a phone's keyboard leaves, held sideways.
const STRIP := Vector2i(2340, 480)
## A keyboard drawn over the game, in screen pixels.
const OVER := 600


func run_title() -> void:
	var before := get_tree().root.size
	Settings.language = "fr"
	Settings.apply()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var feedback := FeedbackDialog.new()
	layer.add_child(feedback)
	var pseudonym := PseudonymDialog.new()
	layer.add_child(pseudonym)
	await _test_desktop(feedback)
	await _test_feedback(feedback)
	await _test_pseudonym(pseudonym)
	await _test_drawn_over(pseudonym)
	SoftKeyboard.fake_height = -1
	get_viewport().gui_release_focus()
	layer.queue_free()
	Settings.language = "en"
	Settings.apply()
	get_tree().root.size = before
	await _frames(3)


func _window(size: Vector2i) -> void:
	get_tree().root.size = size
	await _frames(3)


## The visible canvas (UI units).
func _canvas() -> Rect2:
	return Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(1.0)


func _board_rect() -> Rect2:
	var board := SoftKeyboard.board()
	return board.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, board.size)


## The words' letters on the screen, in screen pixels (font size x the canvas's scale).
func _letter_pixels() -> float:
	return SoftKeyboard.words_label().get_theme_font_size(&"font_size") * PixelGrid.ui_scale()


func _test_desktop(feedback: FeedbackDialog) -> void:
	SoftKeyboard.fake_height = -1
	await _window(PHONE)
	feedback.open()
	await _frames(2)
	(feedback.get_node("%Text") as TextEdit).grab_focus()
	await _window(STRIP)
	check(not SoftKeyboard.is_up(), "keyboard: no virtual keyboard (a computer), no typing bar")
	check(is_equal_approx(PixelGrid.ui_scale(), PixelGridScript.canvas_scale(480.0 / 720.0, Settings.ui_size)), "keyboard: without a virtual keyboard a short window scales as always (x%s)" % PixelGrid.ui_scale())
	get_viewport().gui_release_focus()
	feedback.hide()
	await _window(PHONE)


func _test_feedback(feedback: FeedbackDialog) -> void:
	SoftKeyboard.fake_height = 0
	await _window(PHONE)
	var scale := PixelGrid.ui_scale()
	check(is_equal_approx(scale, 1.5), "keyboard: the phone at x1.5 before typing (x%s)" % scale)
	feedback.open()
	await _frames(2)
	var text := feedback.get_node("%Text") as TextEdit
	text.grab_focus()
	feedback.set_text("Le boss du troisième étage reste coincé dans le mur.")
	await _frames(2)
	check(not SoftKeyboard.is_up(), "keyboard: the field focused, no bar before the keyboard opens")
	SoftKeyboard.fake_height = 560
	await _window(STRIP)
	check(is_equal_approx(PixelGrid.ui_scale(), scale), "keyboard: the UI keeps its scale while the keyboard shrinks the window (x%s)" % PixelGrid.ui_scale())
	check(PixelGrid.settled_size() == PHONE, "keyboard: the window without the keyboard is remembered")
	check(SoftKeyboard.is_up(), "keyboard: the typing bar shows over the feedback form")
	check(_canvas().encloses(_board_rect()), "keyboard: the bar is inside the strip above the keyboard (%s in %s)" % [_board_rect(), _canvas()])
	check(_letter_pixels() >= Fonts.BODY * 1.5, "keyboard: the words typed are at least BODY size at x1.5 (%s screen pixels)" % _letter_pixels())
	var words := SoftKeyboard.words_label()
	check(words.text.contains("coincé dans le mur") and words.text.contains(SoftKeyboard.CARET), "keyboard: the bar shows the words as typed, with the caret")
	check(words.is_visible_in_tree() and words.get_global_rect().size.y >= words.get_line_height(), "keyboard: at least one line of words in sight")
	check(not (SoftKeyboard.get_node("TextEntry/Board") as Control).find_children("*", "Label", true, false).is_empty() and _off_grid_texts(SoftKeyboard.board()).is_empty(), "keyboard: the bar's texts are on the font's grid")
	# Many lines: the last ones (the caret's) stay in sight.
	var long := ""
	for i in 30:
		long += "Ligne %d du message.\n" % i
	feedback.set_text(long + "La fin")
	text.set_caret_line(text.get_line_count() - 1)
	text.set_caret_column(text.get_line(text.get_line_count() - 1).length())
	await _frames(3)
	check(words.lines_skipped > 0, "keyboard: a long message shows its last lines (%d skipped)" % words.lines_skipped)
	# A Settings change under the keyboard keeps the scale too.
	Settings.changed.emit()
	await _frames(1)
	check(is_equal_approx(PixelGrid.ui_scale(), scale), "keyboard: an option changed while typing keeps the scale")
	# A tap on the backdrop leaves the field focused (the keyboard stays).
	await _tap(Vector2(4, 4))
	check(get_viewport().gui_get_focus_owner() == text, "keyboard: a tap beside the bar keeps the field's focus")
	# OK: the keyboard goes, the form is back as it was.
	(SoftKeyboard.get_node("TextEntry/Board").find_child("OkButton", true, false) as Button).pressed.emit()
	await _frames(1)
	check(get_viewport().gui_get_focus_owner() == null and not SoftKeyboard.is_up(), "keyboard: OK puts the keyboard away and the bar goes")
	SoftKeyboard.fake_height = 0
	await _window(PHONE)
	check(is_equal_approx(PixelGrid.ui_scale(), scale), "keyboard: the keyboard gone, the scale is unchanged")
	check(_canvas().encloses(feedback.board_rect()), "keyboard: the feedback form fits the screen again (%s)" % feedback.board_rect())
	# The keyboard closed by the phone (its back button): the field keeps the focus, the bar goes.
	text.grab_focus()
	SoftKeyboard.fake_height = 560
	await _window(STRIP)
	check(SoftKeyboard.is_up(), "keyboard: back in the field, the bar is back")
	SoftKeyboard.fake_height = 0
	await _window(PHONE)
	check(not SoftKeyboard.is_up() and is_equal_approx(PixelGrid.ui_scale(), scale), "keyboard: closed by the phone, the bar goes and the scale stays")
	get_viewport().gui_release_focus()
	feedback.hide()
	await _frames(1)


func _test_pseudonym(pseudonym: PseudonymDialog) -> void:
	SoftKeyboard.fake_height = 0
	await _window(PHONE)
	pseudonym.open()
	await _frames(2)
	var edit := pseudonym.get_node("%NameEdit") as LineEdit
	edit.grab_focus()
	edit.text = "Âme errante"
	edit.caret_column = edit.text.length()
	SoftKeyboard.fake_height = 560
	await _window(STRIP)
	check(SoftKeyboard.is_up() and is_equal_approx(PixelGrid.ui_scale(), 1.5), "keyboard: the pseudonym's bar shows, at x1.5")
	check(_canvas().encloses(_board_rect()), "keyboard: the pseudonym's bar is inside the strip")
	check(SoftKeyboard.words_label().text == "Âme errante" + SoftKeyboard.CARET, "keyboard: the pseudonym as typed (%s)" % SoftKeyboard.words_label().text)
	check(_letter_pixels() >= Fonts.BODY * 1.5, "keyboard: the pseudonym at least BODY size")
	var labels := SoftKeyboard.board().find_children("*", "Label", true, false)
	var texts: Array[String] = []
	for label: Label in labels:
		if label.visible:
			texts.append(label.text)
	check(texts.has(pseudonym.title_label.text), "keyboard: the bar is named after the dialog (%s)" % [texts])
	check(texts.has("%d / %d" % [edit.text.length(), edit.max_length]), "keyboard: the pseudonym's length and limit (%s)" % [texts])
	check(texts.any(func(t: String) -> bool: return t.contains("%d" % Leaderboards.config.name_max)), "keyboard: the pseudonym's rules as the hint")
	SoftKeyboard.finish()
	SoftKeyboard.fake_height = 0
	await _window(PHONE)
	check(not SoftKeyboard.is_up() and is_equal_approx(PixelGrid.ui_scale(), 1.5), "keyboard: the pseudonym typed, the dialog is back at x1.5")
	pseudonym.hide()


## A keyboard drawn over the game, the window not resized: the bar sits above it.
func _test_drawn_over(pseudonym: PseudonymDialog) -> void:
	SoftKeyboard.fake_height = 0
	await _window(PHONE)
	pseudonym.open()
	await _frames(2)
	(pseudonym.get_node("%NameEdit") as LineEdit).grab_focus()
	SoftKeyboard.fake_height = OVER
	await _frames(3)
	var free_height := get_viewport().get_visible_rect().size.y * (1.0 - float(OVER) / PHONE.y)
	check(SoftKeyboard.is_up(), "keyboard: drawn over the game, the bar shows")
	check(_board_rect().end.y <= free_height + 1.0 and _board_rect().position.y >= 0.0, "keyboard: the bar is above a keyboard drawn over the game (%s, free %s)" % [_board_rect(), free_height])
	SoftKeyboard.fake_height = 0
	await _frames(2)
	check(not SoftKeyboard.is_up(), "keyboard: that keyboard gone, the bar goes")
	get_viewport().gui_release_focus()
	pseudonym.hide()


func _tap(at: Vector2) -> void:
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at
		event.global_position = at
		get_viewport().push_input(event)
		await _frames(1)
