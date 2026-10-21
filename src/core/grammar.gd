class_name Grammar
## Agreement, for languages whose adjectives follow the noun's gender (French: "Hache Affûtée",
## "Katana Affûté"). In the translations (locale/strings.csv), a name's gender is the
## translation of "grammar:gender:<English name>" ("f" for feminine, "m" otherwise) and an
## adjective's feminine form the translation of "grammar:feminine:<English adjective>".
## English has neither: the plain words are used. tools/i18n/extract.py adds these keys for the
## equipment and monsters (nouns) and the item and elite affixes (adjectives).

const GENDER := "grammar:gender:"
const FEMININE := "grammar:feminine:"


## The adjective (its English source text, "Sharp") in the player's language, agreeing with the
## noun (its English source text, "Axe").
static func adjective(adjective_source: String, noun_source: String) -> String:
	if is_feminine(noun_source):
		var feminine := TranslationServer.tr(FEMININE + adjective_source)
		if not feminine.begins_with(FEMININE):
			return feminine
	return TranslationServer.tr(adjective_source)


static func is_feminine(noun_source: String) -> bool:
	return TranslationServer.tr(GENDER + noun_source) == "f"
