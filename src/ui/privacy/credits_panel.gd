class_name CreditsPanel
extends InfoPanel
## The credits (title screen, Options): every entry of data/credits/credits.tres (CreditsDef) by
## section, each with its makers, what it is in the game, its licence, what was changed, and a
## button showing its licence file as shipped with the game. Godot's entry shows the engine's
## own licence and third-party notices (Engine.get_license_text(), get_copyright_info(),
## get_license_info()). Works with touch, the mouse, the keys and a gamepad (MenuNav: the
## buttons, and the page scrolls between them). Reachable as %Content, %CloseButton,
## %LicensePage (the licence shown over the credits), %License_<n> (each licence button).

const DEFS := "res://data/credits/credits.tres"

var credits: CreditsDef
## The licence being read, over the credits.
var license_page: InfoPanel
## The licence button pressed last (the focus goes back to it).
var _last_license: Button


func _init() -> void:
	super._init(TranslationServer.tr("Credits"))


func _ready() -> void:
	credits = load(DEFS) as CreditsDef
	_build()
	license_page = InfoPanel.new(tr("License"))
	add_child(license_page)
	MenuWindow.expose(license_page, "LicensePage", self)
	license_page.closed.connect(func() -> void:
		var button := _last_license
		if button and is_instance_valid(button) and InputDevice.uses_buttons():
			button.grab_focus())


## Back: the licence first, then the credits.
func back() -> bool:
	if license_page and license_page.visible:
		license_page.close()
		return true
	return super.back()


func _build() -> void:
	var index := 0
	for section in credits.sections:
		var box: Dictionary = RpgWindow.section(tr(section.title))
		(box.box as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(box.box)
		var column: VBoxContainer = box.column
		for entry in section.entries:
			_entry(column, entry, index)
			index += 1


## One entry: its name and makers, what it is, its licence and source, what was changed, and
## its licence's button.
func _entry(column: VBoxContainer, entry: CreditEntryDef, index: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var title_line := UiSkin.label(tr("%s, by %s") % [entry.work, entry.makers] if not entry.makers.is_empty() else entry.work, Fonts.BODY, UiSkin.GOLD, true)
	title_line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	words.add_child(title_line)
	if not entry.description.is_empty():
		words.add_child(UiSkin.label(tr(entry.description), Fonts.BODY, UiSkin.TEXT, true))
	if not entry.license.is_empty():
		var source := tr("License: %s") % entry.license
		if not entry.url.is_empty():
			source += " - " + entry.url
		var line := UiSkin.label(source, Fonts.BODY, UiSkin.DIM, true)
		line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		words.add_child(line)
	elif not entry.url.is_empty():
		var site := UiSkin.label(entry.url, Fonts.BODY, UiSkin.DIM, true)
		site.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		words.add_child(site)
	if not entry.changes.is_empty():
		words.add_child(UiSkin.label(tr("Changed for the game: %s") % tr(entry.changes), Fonts.BODY, UiSkin.DIM, true))
	if entry.engine_notice or not entry.license_file.is_empty():
		var button := MenuWindow.button(tr("License"), Fonts.BODY, 44)
		button.custom_minimum_size.x = 150
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_show_license.bind(entry, button))
		row.add_child(button)
		MenuWindow.expose(button, "License_%d" % index, self)


func _show_license(entry: CreditEntryDef, button: Button) -> void:
	Sfx.play_ui(Sfx.bank.ui_open)
	_last_license = button
	UiParts.clear(license_page.content)
	license_page.window.set_title(entry.work)
	var text := engine_notice() if entry.engine_notice else license_text(entry)
	var label := license_page.paragraph(text, UiSkin.TEXT)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # (licences stay in their language)
	license_page.open()


## The licence file of `entry` as shipped (empty if it is missing).
static func license_text(entry: CreditEntryDef) -> String:
	if entry.license_file.is_empty() or not FileAccess.file_exists(entry.license_file):
		return ""
	return FileAccess.get_file_as_string(entry.license_file).strip_edges()


## Godot's licence, then each third-party component it holds and its licence, then those
## licences' texts: what its MIT licence and its notices ask to be shown.
static func engine_notice() -> String:
	var parts := PackedStringArray([Engine.get_license_text().strip_edges(), "", "Third-party components:"])
	var used := {}
	for component: Dictionary in Engine.get_copyright_info():
		for part: Dictionary in component.get("parts", []):
			var licence := str(part.get("license", ""))
			parts.append("- %s: %s (%s)" % [component.get("name", ""), "; ".join(PackedStringArray(part.get("copyright", []))), licence])
			for licence_name in licence.replace("(", " ").replace(")", " ").split(" ", false):
				if licence_name != "or" and licence_name != "and":
					used[licence_name] = true
	var texts := Engine.get_license_info()
	for licence_name: String in texts:
		if used.has(licence_name):
			parts.append("")
			parts.append("%s:" % licence_name)
			parts.append(str(texts[licence_name]).strip_edges())
	return "\n".join(parts)
