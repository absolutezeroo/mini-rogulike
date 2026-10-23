class_name Soundtrack
extends RefCounted
## Which music plays where. The tracks live in the data of each place (a floor's DungeonTheme, a
## warden's BossDef or its act's ActDef.boss_music, the Deeps' AbyssDef, the Threshold's
## ThresholdDef, a true ending's EndingDef, a boss story's CinematicDef, the screens' SoundBank);
## this reads them in one place: the fallbacks (a warden without its own music fights to its
## act's), and the whole map of the game's places, so the tests can check that none is silent by
## mistake and the docs' table can be checked against it (docs/design/presentation.md, "Music").


## A warden's fight music: its own, else its act's (`act`: the act it guards, null for the
## hidden floor's and the bottom's), else the bank's.
static func boss_music(def: BossDef, act: ActDef, bank: SoundBank) -> AudioStream:
	if def and def.music:
		return def.music
	if act and act.boss_music:
		return act.boss_music
	return bank.boss_music if bank else null


## A floor's music (its biome's look).
static func floor_music(theme: DungeonTheme) -> AudioStream:
	return theme.music if theme else null


## Every place of the game and the track it plays, in the order of a run: "place" -> AudioStream
## (null: silent, a mistake). The names are for people (tests, the debug panel), in English.
static func places(content: ContentDB) -> Dictionary:
	var map := {}
	var bank := content.sounds
	map["Title screen and shrine"] = bank.title_music if bank else null
	var config := content.dungeon
	for act in config.acts:
		var act_name := "%s (%s)" % [act.subtitle, act.title]
		for biome in act.biomes:
			map["%s: %s floors" % [act_name, biome.display_name if biome else "?"]] = floor_music(biome.theme) if biome else null
		if act.boss_biome and not act.biomes.has(act.boss_biome):
			map["%s: %s floors" % [act_name, act.boss_biome.display_name]] = floor_music(act.boss_biome.theme)
		for boss in act.all_bosses():
			map["%s: %s" % [act_name, boss.display_name]] = boss_music(boss, act, bank)
	var hidden := config.hidden_floor
	if hidden:
		map["%s floor" % hidden.title] = floor_music(hidden.biome.theme) if hidden.biome else null
		if hidden.boss:
			map["%s: %s" % [hidden.title, hidden.boss.display_name]] = boss_music(hidden.boss, null, bank)
	var finale := config.finale
	if finale:
		map["%s floor" % finale.title] = floor_music(finale.biome.theme) if finale.biome else null
		if finale.boss:
			for form in finale.boss.forms():
				map["%s: %s" % [finale.title, form.display_name]] = boss_music(form, null, bank)
		for ending in finale.endings:
			map["Ending: %s" % ending.choice] = ending.music if ending.music else (bank.victory_music if bank else null)
	if config.abyss:
		map["The Deeps"] = config.abyss.music
	for trial in thresholds(content):
		map["The Threshold"] = trial.music
	var narrative := content.narrative
	if narrative and narrative.full_cinematic:
		map["A warden's story (full)"] = narrative.full_cinematic.music
	map["Run won"] = bank.victory_music if bank else null
	map["Run lost"] = bank.defeat_music if bank else null
	return map


## The trials of the Threshold the relics can open (CheatDeathPassive).
static func thresholds(content: ContentDB) -> Array[ThresholdDef]:
	var found: Array[ThresholdDef] = []
	for perk in content.perks:
		if perk == null:
			continue
		for passive in perk.passives:
			var cheat := passive as CheatDeathPassive
			if cheat and cheat.trial and not found.has(cheat.trial):
				found.append(cheat.trial)
	return found
