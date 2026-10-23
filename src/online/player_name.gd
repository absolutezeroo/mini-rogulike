class_name PlayerName
## The pseudonym shown on the online leaderboards: a simple filter (length, the letters the
## game's font draws, a list of words refused, LeaderboardsConfig), and making any name read from
## the server safe to draw. Not a moderator: Talo's own profanity filter and the dashboard (hide
## or delete an entry, docs/online.md) do the rest.

enum Problem { NONE, TOO_SHORT, TOO_LONG, BAD_CHARACTERS, NO_LETTER, REFUSED }

## The letters the font draws besides ASCII ones (tools/i18n/add_glyphs.py): French and its
## neighbours'.
const ACCENTED := "ÀÁÂÃÄÅÆÇÈÉÊËÎÏÑÒÓÔÕÖØÙÚÛÜàáâãäåæçèéêëìíîïòóôõöùúûüŒœ"
## Signs allowed between the letters.
const SIGNS := " -_.'"
## Accented letters and digits read as the letters they stand for, before looking for a refused
## word (so "Mérde" and "sh1t" are found too).
const PLAIN := {
	"à": "a", "á": "a", "â": "a", "ã": "a", "ä": "a", "å": "a", "æ": "ae", "ç": "c",
	"è": "e", "é": "e", "ê": "e", "ë": "e", "ì": "i", "í": "i", "î": "i", "ï": "i",
	"ñ": "n", "ò": "o", "ó": "o", "ô": "o", "õ": "o", "ö": "o", "ø": "o", "œ": "oe",
	"ù": "u", "ú": "u", "û": "u", "ü": "u",
	"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b", "@": "a", "$": "s",
}


## `text` tidied: no spaces at the ends, never two in a row.
static func tidy(text: String) -> String:
	var result := text.strip_edges()
	while result.contains("  "):
		result = result.replace("  ", " ")
	return result


## What is wrong with `text` as a pseudonym (Problem.NONE: it can be used; tidy() it first).
static func problem(text: String, config: LeaderboardsConfig) -> Problem:
	var name := tidy(text)
	if name.length() < config.name_min:
		return Problem.TOO_SHORT
	if name.length() > config.name_max:
		return Problem.TOO_LONG
	var has_letter := false
	for i in name.length():
		var c := name[i]
		if _is_letter(c):
			has_letter = true
		elif not (_is_digit(c) or SIGNS.contains(c)):
			return Problem.BAD_CHARACTERS
	if not has_letter:
		return Problem.NO_LETTER
	if is_refused(name, config):
		return Problem.REFUSED
	return Problem.NONE


## What the player is told about `problem`, a plain sentence.
static func explain(problem: Problem, config: LeaderboardsConfig) -> String:
	match problem:
		Problem.TOO_SHORT:
			return TranslationServer.tr("At least %d characters.") % config.name_min
		Problem.TOO_LONG:
			return TranslationServer.tr("At most %d characters.") % config.name_max
		Problem.BAD_CHARACTERS:
			return TranslationServer.tr("Only letters, digits, spaces and - _ . '")
		Problem.NO_LETTER:
			return TranslationServer.tr("At least one letter.")
		Problem.REFUSED:
			return TranslationServer.tr("This name is not allowed. Choose another.")
	return ""


## Whether `text` holds a refused word (config.banned_words), read without case, accents, signs
## or digits standing for letters. Short words count only as a whole word.
static func is_refused(text: String, config: LeaderboardsConfig) -> bool:
	var words := PackedStringArray()
	var word := ""
	for c in text.to_lower():
		var plain: String = PLAIN.get(c, c)
		if plain.length() >= 1 and plain[0] >= "a" and plain[0] <= "z":
			word += plain
		elif not word.is_empty():
			words.append(word)
			word = ""
	if not word.is_empty():
		words.append(word)
	var joined := "".join(words)
	for banned in config.banned_words:
		var target := banned.to_lower()
		if target.is_empty():
			continue
		if target.length() <= config.short_word:
			if words.has(target):
				return true
		elif joined.contains(target):
			return true
	return false


## A name read from the server, safe to draw: unknown letters as "?", cut to the longest a name
## may be (another client, or the dashboard, may have sent anything).
static func readable(text: String, config: LeaderboardsConfig) -> String:
	var result := ""
	for c in tidy(text):
		result += c if _is_letter(c) or _is_digit(c) or SIGNS.contains(c) else "?"
	if result.length() > config.name_max:
		result = result.substr(0, config.name_max)
	return result if not result.is_empty() else "?"


## The name a device has before its player picks one: "Soul 4821".
static func default_for(device_id: String, config: LeaderboardsConfig) -> String:
	var digits := str(absi(hash(device_id)) % 10000).pad_zeros(4)
	return "%s %s" % [config.default_name, digits]


static func _is_letter(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or ACCENTED.contains(c)


static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"
