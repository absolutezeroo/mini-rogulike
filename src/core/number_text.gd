class_name NumberText
## Big whole numbers as each language writes them: "1,284,302" in English, "1 284 302" in French
## (a narrow no-break space between the groups: the game's font has it, drawn on its grid; a line
## never breaks inside a number).

## The narrow no-break space (U+202F), French's thousands separator.
const NARROW_SPACE := " "


## `value` with its thousands grouped for `locale` (empty: the game's language now).
static func of(value: int, locale: String = "") -> String:
	if locale.is_empty():
		locale = TranslationServer.get_locale()
	var separator := NARROW_SPACE if locale.begins_with("fr") else ","
	var digits := str(absi(value))
	var groups: PackedStringArray = []
	while digits.length() > 3:
		groups.insert(0, digits.right(3))
		digits = digits.left(digits.length() - 3)
	groups.insert(0, digits)
	return ("-" if value < 0 else "") + separator.join(groups)
