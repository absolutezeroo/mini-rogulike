class_name DailyDialog
extends RpgDialog
## "The Dawn Knell", the daily run (DailyRun) explained before it starts: a line of lore, the
## day's weapon and relic, the rules (same floors for everyone, first try counts, how the score
## is made), your scores, and Toll the knell / Back.

signal accepted

const WIDTH := 640.0


func _init() -> void:
	super._init(TranslationServer.tr("The Dawn Knell"), WIDTH, 0.8)


## Fills it for `day` and shows it.
func open(content: ContentDB, day: int) -> void:
	UiParts.clear(body)
	var played := Profile.daily_played(day)
	var lore := UiSkin.label(tr("Each dawn the shrine's bell tolls a knell for the living. All who hear it go down the same Well."), Fonts.BODY, UiSkin.DIM, true)
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(lore)
	# Today's start: the weapon and the relic, with their pictures.
	var start := HBoxContainer.new()
	start.alignment = BoxContainer.ALIGNMENT_CENTER
	start.add_theme_constant_override("separation", 10)
	body.add_child(start)
	var weapon := DailyRun.weapon(content, day)
	var relic := DailyRun.relic(content, day)
	if weapon:
		var slot := ItemSlot.new(56.0)
		slot.item = weapon
		slot.show_level = false
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		start.add_child(slot)
		start.add_child(UiSkin.label(tr(weapon.display_name), Fonts.BODY, UiSkin.TEXT))
	if relic:
		start.add_child(UiSkin.label("+", Fonts.BODY, UiSkin.GOLD))
		var icon := TextureRect.new()
		icon.texture = relic.icon
		icon.custom_minimum_size = Vector2(44, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		start.add_child(icon)
		start.add_child(UiSkin.label(tr(relic.display_name), Fonts.BODY, relic.color.lerp(Color.WHITE, 0.3)))
	for rule in [
		tr("The same floors and bosses for everyone today, on Keeper, with this weapon and relic."),
		tr("Only the first toll counts; the next ones today are practice."),
		tr("Score: 1 per kill, 30 per floor, 150 per boss, 1000 for a win, 1 per 5 gold."),
	]:
		body.add_child(UiSkin.label("- " + rule, Fonts.BODY, UiSkin.TEXT, true))
	var scores := PackedStringArray()
	scores.append(tr("Today: %d points") % Profile.daily_score if played else tr("Today's knell awaits you"))
	if Profile.daily_best > 0:
		scores.append(tr("Best %d") % Profile.daily_best)
	if Profile.daily_streak > 1:
		scores.append(tr("%d dawns in a row") % Profile.daily_streak)
	var line := UiSkin.label("  -  ".join(scores), Fonts.BODY, UiSkin.GOLD)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(line)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	body.add_child(buttons)
	var go := UiParts.button(tr("Toll again") if played else tr("Toll the knell"), func() -> void:
		hide()
		accepted.emit(), Vector2(0, 56), Fonts.BODY)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.name = "AnswerButton"
	buttons.add_child(go)
	var back := UiParts.button(tr("Back"), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		hide(), Vector2(160, 56), Fonts.BODY)
	buttons.add_child(back)
	show()
