class_name StoryTests
extends TestSuite
## The wardens' stories (Narrative, docs/design/presentation.md "Boss stories"). Unit part (run
## by the unit suite): every chronicle's data, the reveal rule, the conditions and the deeds,
## what a meeting tells, the fragments to lay, the profile, the codex's Chronicle and the option.
## Game part (run by the game suite): the cinematic in a real arena, skipping it, never twice on
## a floor (a run picked up again), the short version and none, the deeds in a fight, the
## fragments on the floors and their reading panel.

## A line of the story at most this long (a phone's box at Fonts.BODY: two rows of the bar).
const MAX_LINE := 150
## Sentence ends (an ellipsis trails off, it doesn't end one).
var _ends := RegEx.create_from_string("(?<!\\.)[.?!](?!\\.)(?=\\s|$|\"|\u202f|»)")


# --- Unit ---------------------------------------------------------------------------------

func run_unit() -> void:
	var saved := _snapshot()
	_reset_story()
	_test_chronicle_data()
	_test_reveal_rule()
	_test_conditions()
	_test_deeds()
	_test_chapters_unlock()
	_test_meeting_plan()
	_test_fragments_to_place()
	_test_profile_story()
	await _test_codex_chronicle()
	await _test_options_stories()
	_restore(saved)


## The wardens that must have a story: every act's, the hidden floor's, and the bottom of the
## Well's forms (Tôma, the Maw).
func _wardens() -> Array[BossDef]:
	var result: Array[BossDef] = []
	for act in CONTENT.dungeon.acts:
		for boss in act.all_bosses():
			if boss and not result.has(boss):
				result.append(boss)
	var hidden := CONTENT.dungeon.hidden_floor
	if hidden and hidden.boss and not result.has(hidden.boss):
		result.append(hidden.boss)
	var finale := CONTENT.dungeon.finale
	if finale and finale.boss:
		for form in finale.boss.forms():
			if not result.has(form):
				result.append(form)
	return result


func _test_chronicle_data() -> void:
	var wardens := _wardens()
	check(wardens.size() >= 13, "every warden is listed, the bottom's two forms too (%d)" % wardens.size())
	var fr := TranslationServer.get_translation_object("fr")
	check(fr != null, "the French translation is loaded")
	var fragment_ids := {}
	for boss in wardens:
		var name := String(boss.id)
		var chronicle := boss.chronicle
		check(chronicle != null, "%s has a chronicle" % name)
		if chronicle == null:
			continue
		check(chronicle.chapters.size() >= 4, "%s: at least 4 chapters (%d)" % [name, chronicle.chapters.size()])
		var first := chronicle.chapters[0]
		check(first.slain == 0 and first.conditions.is_empty(), "%s: the first chapter is told at the first meeting" % name)
		var ids := {}
		var deed_gated := 0
		for chapter in chronicle.chapters:
			check(not ids.has(chapter.id) and chapter.id != &"", "%s: chapter ids are unique (%s)" % [name, chapter.id])
			ids[chapter.id] = true
			check(not chapter.title.is_empty() and _translated(fr, chapter.title), "%s/%s: a title, translated" % [name, chapter.id])
			check(chapter.lines.size() >= 2 and chapter.lines.size() <= 4, "%s/%s: 2 to 4 lines (%d)" % [name, chapter.id, chapter.lines.size()])
			for line in chapter.lines:
				_check_line(fr, line, "%s/%s" % [name, chapter.id])
			if not chapter.deeds().is_empty():
				deed_gated += 1
		for line in chronicle.waking_lines:
			check(not ids.has(line.id), "%s: waking line ids are unique (%s)" % [name, line.id])
			ids[line.id] = true
			_check_line(fr, line.line, "%s/%s" % [name, line.id])
			check(not line.conditions.is_empty(), "%s/%s: a waking line waits for something" % [name, line.id])
			if not line.deeds().is_empty():
				deed_gated += 1
		for line in chronicle.last_words:
			check(not ids.has(line.id), "%s: last words ids are unique (%s)" % [name, line.id])
			ids[line.id] = true
			_check_line(fr, line.line, "%s/%s" % [name, line.id])
			check(not line.conditions.is_empty(), "%s/%s: last words wait for something" % [name, line.id])
			if not line.deeds().is_empty():
				deed_gated += 1
		var deeds := chronicle.deeds()
		check(deeds.size() >= 1 and deed_gated >= 1 and deed_gated <= 2, "%s: one or two chapters or lines are earned by a deed (%d)" % [name, deed_gated])
		for deed in deeds:
			check(deed.id != &"" and not deed.hint.is_empty() and not deed.rule.is_empty(), "%s: its deed has an id, a riddle and a rule" % name)
			check(_translated(fr, deed.hint) and _translated(fr, deed.rule), "%s: its deed's riddle and rule are translated" % name)
			check(deed.hint != deed.rule, "%s: the riddle is not the rule" % name)
			check(deed.revealed_by == null or chronicle.fragments.has(deed.revealed_by), "%s: the fragment giving its deed away is one of its own" % name)
		check(chronicle.fragments.size() >= 2, "%s: fragments to find (%d)" % [name, chronicle.fragments.size()])
		for fragment in chronicle.fragments:
			check(not fragment_ids.has(fragment.id), "fragment ids are unique (%s)" % fragment.id)
			fragment_ids[fragment.id] = true
			check(fragment.lines.size() >= 2 and fragment.lines.size() <= 5, "%s: 2 to 5 lines" % fragment.id)
			for text in [fragment.title, fragment.author, fragment.place]:
				check(not text.is_empty() and _translated(fr, text), "%s: its title, author and place are set and translated" % fragment.id)
			for line in fragment.lines:
				_check_line(fr, line, String(fragment.id))
			check(fragment.look != null and fragment.look.icon != null and fragment.look.element != null, "%s: a look (picture, element)" % fragment.id)


## A story line: translated, at most two sentences and MAX_LINE letters in both languages.
func _check_line(fr: Translation, line: String, where: String) -> void:
	check(_translated(fr, line), "%s: translated: %s" % [where, line.left(40)])
	var french := String(fr.get_message(line)) if fr else line
	for text: String in [line, french]:
		check(text.length() <= MAX_LINE, "%s: at most %d letters (%d): %s" % [where, MAX_LINE, text.length(), text.left(40)])
		check(_ends.search_all(text).size() <= 2, "%s: at most two sentences: %s" % [where, text.left(40)])
		check(not text.contains("!"), "%s: no exclamation mark in lore: %s" % [where, text.left(40)])


func _translated(fr: Translation, key: String) -> bool:
	return fr != null and not String(fr.get_message(key)).is_empty()


## No text naming the keeper opens before the reveal (docs/lore.md section 7): checked in the
## data (every text holding a reveal word asks for the reveal), then in play.
func _test_reveal_rule() -> void:
	var narrative := CONTENT.narrative
	check(narrative != null and narrative.keeper_reveal != null and not narrative.reveal_words.is_empty(), "the narrative has its reveal gate and words")
	if narrative == null:
		return
	var fr := TranslationServer.get_translation_object("fr")
	var gated := 0
	for boss in _wardens():
		if boss.chronicle == null:
			continue
		for chapter in boss.chronicle.chapters:
			gated += _check_gated(narrative, fr, chapter.lines + PackedStringArray([chapter.title]), chapter.conditions, "%s/%s" % [boss.id, chapter.id])
		for line in boss.chronicle.waking_lines + boss.chronicle.last_words:
			gated += _check_gated(narrative, fr, PackedStringArray([line.line]), line.conditions, "%s/%s" % [boss.id, line.id])
		for fragment in boss.chronicle.fragments:
			gated += _check_gated(narrative, fr, fragment.lines + PackedStringArray([fragment.title, fragment.author, fragment.place]), fragment.conditions, String(fragment.id))
		for deed in boss.chronicle.deeds():
			for text in [deed.hint, deed.rule]:
				check(not _names_keeper(narrative, fr, text), "%s: a deed never names the keeper" % boss.id)
	check(gated >= 13, "the keeper is named, after the reveal, by every warden (%d texts)" % gated)
	# In play: everything else done (many kills, every fragment, every deed), but not the reveal
	# (the Effigy slain, or Tôma met at the bottom of the Well).
	_reset_story()
	for boss in _wardens():
		if boss.id == &"nameless_effigy" or boss.id == &"master_toma":
			continue
		for i in 10:
			Profile.record_kill(boss.id)
		for fragment in Narrative.fragments(boss):
			Profile.fragments_found[String(fragment.id)] = 1
		for deed in Narrative.deeds(boss):
			Profile.deeds_done["%s/%s" % [boss.id, deed.id]] = 1
	Profile.reach_depth(12)
	var leaks := PackedStringArray()
	for boss in _wardens():
		for chapter in Narrative.open_chapters(boss):
			for line in chapter.lines:
				if _names_keeper(narrative, fr, line):
					leaks.append(String(chapter.id))
		for words: WakingLine in [Narrative.speech(boss), Narrative.last_words(boss)]:
			if words and _names_keeper(narrative, fr, words.line):
				leaks.append(String(words.id))
		for fragment in Narrative.fragments_to_place(boss):
			if _names_keeper(narrative, fr, " ".join(fragment.lines)):
				leaks.append(String(fragment.id))
	check(leaks.is_empty(), "nothing names the keeper before the reveal: %s" % ", ".join(leaks))
	check(not narrative.keeper_reveal.is_met(), "the reveal waits for the Nameless Effigy and a victory")
	Profile.boss_meetings["master_toma"] = 1
	check(narrative.keeper_reveal.is_met(), "or for meeting him at the bottom of the Well: there he is named")
	var toma := _boss("master_toma")
	check(Narrative.open_chapters(toma).any(func(c: ChronicleChapter) -> bool: return _names_keeper(narrative, fr, " ".join(c.lines))), "met, Tôma's own story names him")
	Profile.boss_meetings.erase("master_toma")
	Profile.record_kill(&"nameless_effigy")
	check(not narrative.keeper_reveal.is_met(), "the Effigy slain is not enough: a victory too")
	Profile.wins["easy"] = 1
	check(narrative.keeper_reveal.is_met(), "the Effigy slain and a run won (any difficulty): the keeper may be named")
	var slime := _boss("king_slime")
	check(Narrative.speech(slime) != null and _names_keeper(narrative, fr, Narrative.speech(slime).line), "after the reveal, a warden names him as it wakes")
	# The empty niche beside the Keeper's Statue: an inscription no one explains, read after the
	# reveal (then it names him).
	var niche := (load("res://data/encounters/warden_statue.tres") as EncounterDef).niche
	check(niche != null and niche.reveal == narrative.keeper_reveal, "the Keeper's Statue has its empty niche, read at the reveal")
	if niche:
		check(not _names_keeper(narrative, fr, niche.text) and _names_keeper(narrative, fr, niche.revealed_text), "the niche's inscription names no one before the reveal, the keeper after it")
		check(niche.shown_text() == niche.revealed_text, "after the reveal, the niche is read")
		_reset_story()
		check(niche.shown_text() == niche.text, "before it, only an empty niche and a line")
		check(_translated(fr, niche.text) and _translated(fr, niche.revealed_text), "the niche reads in French too")
	_reset_story()


## A text naming the keeper (in English or French) must be gated by the reveal. Returns 1 if it
## names him.
func _check_gated(narrative: NarrativeDef, fr: Translation, texts: PackedStringArray, conditions: Array[ProgressCondition], where: String) -> int:
	var names := false
	for text in texts:
		names = names or _names_keeper(narrative, fr, text)
	if not names:
		return 0
	var gated := conditions.any(func(c: ProgressCondition) -> bool:
		return c == narrative.keeper_reveal or (c is AllCondition and (c as AllCondition).contains(narrative.keeper_reveal)))
	check(gated, "%s names the keeper: it waits for the reveal" % where)
	return 1


func _names_keeper(narrative: NarrativeDef, fr: Translation, text: String) -> bool:
	var french := String(fr.get_message(text)) if fr else ""
	for word in narrative.reveal_words:
		if text.contains(word) or french.contains(word):
			return true
	return false


func _test_conditions() -> void:
	_reset_story()
	var slime := _boss("king_slime")
	var slain := SlainCondition.new()
	slain.count = 2
	check(not slain.is_met(slime) and slain.describe(slime) == "Slay it 2 times", "slain: about the subject, in plain words")
	Profile.record_kill(&"king_slime")
	Profile.record_kill(&"king_slime")
	check(slain.is_met(slime), "slain: met with the kills")
	var by_id := SlainCondition.new()
	by_id.monster_id = &"nameless_effigy"
	by_id.text = "Find the one who does not rest, and slay him"
	check(not by_id.is_met(slime) and by_id.describe(slime) == "Find the one who does not rest, and slay him", "slain by id: another monster, its own words (no name given away)")
	var depth := StatCondition.new()
	depth.stat = "deepest"
	depth.at_least = 7
	depth.text = "Reach floor %d"
	check(not depth.is_met() and depth.describe() == "Reach floor 7", "a counter: in plain words with its number")
	Profile.reach_depth(7)
	check(depth.is_met(), "the deepest floor counts on any difficulty")
	var wins := StatCondition.new()
	wins.stat = "all_wins"
	check(not wins.is_met(), "no run won yet")
	Profile.wins["easy"] = 1
	check(wins.is_met(), "a Pilgrim win counts for the story")
	var both := AllCondition.new()
	var parts: Array[ProgressCondition] = [slain, depth]
	both.conditions = parts
	check(both.is_met(slime) and both.contains(depth), "all of them: met together")
	var frags := FragmentsCondition.new()
	frags.count = 2
	check(not frags.is_met(slime) and frags.describe(slime) == "Find 2 fragments about it", "fragments: of the subject")
	Narrative.find(slime.chronicle.fragments[0])
	Narrative.find(slime.chronicle.fragments[1])
	check(frags.is_met(slime), "fragments: met once found")
	var one := FragmentsCondition.new()
	one.fragment = slime.chronicle.fragments[2]
	check(not one.is_met(slime) and one.describe(slime).contains(slime.chronicle.fragments[2].title), "a given fragment, named by its title")
	var met := MetCondition.new()
	check(not met.is_met(_boss("nameless_effigy")), "met: not before the hero found it")
	Profile.mark_seen(&"nameless_effigy")
	check(met.is_met(_boss("nameless_effigy")), "met: once seen")
	var met_by_id := MetCondition.new()
	met_by_id.monster_id = &"master_toma"
	met_by_id.text = "Find the one who waits at the bottom"
	check(not met_by_id.is_met(slime) and met_by_id.describe(slime) == "Find the one who waits at the bottom", "met by id: another monster, its own words")
	Profile.boss_meetings["master_toma"] = 1
	check(met_by_id.is_met(slime), "met by id: once its arena was walked into")
	var either := AnyCondition.new()
	var ways: Array[ProgressCondition] = [depth, met_by_id]
	either.conditions = ways
	check(either.is_met(slime) and either.contains(met_by_id), "any of them: one way is enough")
	Profile.boss_meetings.erase("master_toma")
	Profile.deepest = 0
	Profile.best_depth = 0
	check(not either.is_met(slime) and either.describe(slime) == "Reach floor 7", "none met: its lock says the first way still open")
	_reset_story()


## Each kind of deed against the death it describes (HuntTracker.kill_context()).
func _test_deeds() -> void:
	_reset_story()
	var kill := { "fight_time": 30.0, "potions_in_fight": 0, "hp_lost_in_fight": 0.1, "healed_in_fight": 0,
		"weapon": null, "weapon_base": null, "untouched": true, "killing_element": null, "gold": 0,
		"marks": {}, "difficulty": &"normal", "ascension": 0, "elite": false, "pushed_in": false, "crit": false,
		"kill_times": [], "now": 0.0 }
	var fast := HuntChallenge.new()
	fast.goal = HuntChallenge.Goal.FAST
	fast.seconds = 60.0
	var quick := ChallengeDeed.new()
	quick.challenge = fast
	check(quick.achieved(kill), "a challenge deed: the fight won in time")
	check(not quick.achieved(_with(kill, "fight_time", 90.0)), "a challenge deed: too slow")
	var katana: WeaponDef = load("res://data/items/weapons/katana.tres")
	var blade := HuntChallenge.new()
	blade.goal = HuntChallenge.Goal.WEAPON
	blade.weapon = katana
	blade.id = &"weapon_katana"
	var school := ChallengeDeed.new()
	school.id = &"weapon_katana"
	school.challenge = blade
	check(school.achieved(_with(kill, "weapon_base", katana)) and not school.achieved(kill), "a weapon deed: with that weapon only")
	var ronin := _boss("red_samurai")
	check(not school.is_met(ronin), "not done yet")
	Profile.challenges_done[Profile.challenge_key(&"red_samurai", &"weapon_katana")] = 1
	check(school.is_met(ronin), "a bestiary challenge already done counts as the same deed (older saves)")
	var fire := ElementDeed.new()
	fire.element = load("res://data/vfx/elements/fire.tres")
	check(fire.achieved(_with(kill, "killing_element", fire.element)), "an element deed: the killing blow in fire")
	check(not fire.achieved(_with(kill, "killing_element", load("res://data/vfx/elements/frost.tres"))) and not fire.achieved(kill), "an element deed: not in frost, not a plain blow")
	var spring := MarkDeed.new()
	spring.mark = &"encounter:spirit_spring"
	check(spring.achieved(_with(kill, "marks", { "encounter:spirit_spring": true })) and not spring.achieved(kill), "a mark deed: the run drank at the spring")
	var frugal := MarkDeed.new()
	frugal.mark = &"bought"
	frugal.present = false
	check(frugal.achieved(kill) and not frugal.achieved(_with(kill, "marks", { "bought": true })), "a mark deed: nothing bought this run")
	var purse := PurseDeed.new()
	purse.max_gold = 10
	check(purse.achieved(_with(kill, "gold", 10)) and not purse.achieved(_with(kill, "gold", 11)), "a purse deed: little gold carried")
	var martyr := HardshipDeed.new()
	var hard: Array[StringName] = [&"hard", &"nightmare"]
	martyr.difficulties = hard
	check(martyr.achieved(_with(kill, "difficulty", &"hard")) and not martyr.achieved(kill), "a hardship deed: on Martyr, not on Keeper")
	var ascended := HardshipDeed.new()
	ascended.min_ascension = 3
	check(ascended.achieved(_with(kill, "ascension", 3)) and not ascended.achieved(_with(kill, "ascension", 2)), "a hardship deed: from an ascension")
	var standing := StandingDeed.new()
	check(standing.achieved(_with(kill, "rolls_in_fight", 0)) and not standing.achieved(_with(kill, "rolls_in_fight", 1)), "a standing deed: not a single roll in the fight")
	check(not standing.achieved(kill) and not standing.achieved(_with(_with(kill, "rolls_in_fight", 0), "fight_time", -1.0)), "a standing deed: only a fought warden, its rolls counted")
	var unbitten := MarkDeed.new()
	unbitten.mark = &"bitten"
	unbitten.present = false
	check(unbitten.achieved(kill) and not unbitten.achieved(_with(kill, "marks", { "bitten": true })), "a mark deed: never bitten this run")
	var unhealed := UnhealedDeed.new()
	check(unhealed.achieved(kill) and not unhealed.achieved(_with(kill, "healed_in_fight", 5)), "an unhealed deed: no heal in the fight")
	check(not unhealed.achieved(_with(kill, "fight_time", -1.0)), "an unhealed deed: only a fought warden")
	# Recorded for good, through the warden's chronicle.
	var slime := _boss("king_slime")
	var deed: DeedCondition = Narrative.deeds(slime)[0]
	check(Narrative.record_deeds(slime, _with(kill, "fight_time", 99.0)).is_empty(), "too slow: no deed")
	check(Narrative.record_deeds(slime, kill).has(deed) and deed.is_met(slime), "the Bloated King burst in time: its deed is done for good")
	check(Narrative.record_deeds(slime, kill).is_empty(), "a deed is done once")
	# The codex shows its riddle until its fragment gives the rule away.
	check(deed.describe(slime) == deed.hint, "a deed reads as its riddle")
	Narrative.find(deed.revealed_by)
	check(deed.describe(slime) == deed.rule, "its fragment found, the rule is plain")
	_reset_story()


func _with(base: Dictionary, key: String, value: Variant) -> Dictionary:
	var copy := base.duplicate()
	copy[key] = value
	return copy


## Chapters open with the warden's deaths, its fragments, its deed; told one per meeting, in order.
func _test_chapters_unlock() -> void:
	_reset_story()
	for boss in _wardens():
		check(Narrative.next_chapter(boss) == boss.chronicle.chapters[0], "%s: the first meeting tells the first chapter" % boss.id)
	var slime := _boss("king_slime")
	var chapters := slime.chronicle.chapters
	check(Narrative.open_chapters(slime).size() == 1, "one chapter open before any death")
	Narrative.tell(_told(slime, chapters[0]))
	check(Narrative.next_chapter(slime) == null, "nothing new after it was told")
	Profile.record_kill(&"king_slime")
	check(Narrative.next_chapter(slime) == slime.chronicle.chapter_by_id(&"the_nushi"), "slain once: the next chapter")
	var thresholds := PackedInt32Array()
	for chapter in chapters:
		thresholds.append(chapter.slain)
	check(thresholds[0] == 0 and thresholds[thresholds.size() - 1] >= 4, "the chapters spread over many deaths (%s)" % str(thresholds))
	var by_fragments := slime.chronicle.chapter_by_id(&"the_coins")
	check(not by_fragments.is_open(slime), "a chapter waits for its fragments")
	check(by_fragments.requirements(slime).has("Find 2 fragments about it"), "its lock says what it waits for")
	Narrative.find(slime.chronicle.fragments[0])
	Narrative.find(slime.chronicle.fragments[1])
	check(by_fragments.is_open(slime), "its fragments found: open")
	var last := chapters[chapters.size() - 1]
	for i in last.slain:
		Profile.record_kill(&"king_slime")
	check(not last.is_open(slime), "the deepest chapter waits for its deed, however many deaths")
	var deed: DeedCondition = last.deeds()[0]
	check(last.requirements(slime).has(deed.rule), "its lock says its rule (its fragment was found)")
	Profile.deeds_done["king_slime/%s" % deed.id] = 1
	check(last.is_open(slime), "the deed done: the last chapter opens")
	# Told one per meeting, in order.
	var told := 1
	while Narrative.next_chapter(slime) != null and told < 20:
		Narrative.tell(_told(slime, Narrative.next_chapter(slime)))
		told += 1
	check(told == chapters.size() and Narrative.told_count(slime) == chapters.size(), "every chapter is told once, one per meeting (%d)" % told)
	_reset_story()


func _told(boss: BossDef, chapter: ChronicleChapter) -> StoryBeat:
	var beat := StoryBeat.new()
	beat.boss = boss
	beat.chapter = chapter
	beat.is_full = true
	return beat


## What a meeting tells with each Boss stories option.
func _test_meeting_plan() -> void:
	_reset_story()
	var slime := _boss("king_slime")
	var first := Narrative.plan(slime, Settings.STORIES_FULL)
	check(first.is_full and first.chapter == slime.chronicle.chapters[0] and not first.chapter_is_new, "the first meeting: the first chapter, no \"new\" mark")
	check(first.speech == null and first.name == slime.display_name and first.title == slime.title, "its name and title; no words of its own yet")
	Narrative.tell(first)
	var again := Narrative.plan(slime, Settings.STORIES_FULL)
	check(not again.is_full and again.chapter == null and slime.chronicle.chapters[0].lines.has(again.echo), "nothing new: the short version, a line it remembers")
	Profile.record_kill(&"king_slime")
	var next := Narrative.plan(slime, Settings.STORIES_FULL)
	check(next.is_full and next.chapter == slime.chronicle.chapter_by_id(&"the_nushi") and next.chapter_is_new, "a new chapter: told, marked \"new\"")
	var short := Narrative.plan(slime, Settings.STORIES_SHORT)
	check(not short.is_full and short.chapter == null and short.has_words(), "Short: never a chapter, only a line")
	check(not Narrative.plan(slime, Settings.STORIES_OFF).has_words(), "Off: nothing")
	Narrative.find(slime.chronicle.fragments[0])
	var memory := Narrative.plan(slime, Settings.STORIES_FULL)
	check(memory.speech != null and memory.speech_is_new and memory.speech == slime.chronicle.waking_lines[0], "a fragment found: it wakes with its own words, new")
	check(Narrative.plan(slime, Settings.STORIES_SHORT).speech == memory.speech, "the short version says them too")
	Narrative.tell(memory)
	check(not Narrative.plan(slime, Settings.STORIES_FULL).speech_is_new, "once told, they are no longer new")
	_reset_story()


## Fragments: never one already found while the warden has others to find; Tôma's journal
## only after the reveal; all of them again once all were found.
func _test_fragments_to_place() -> void:
	_reset_story()
	var slime := _boss("king_slime")
	var all := Narrative.fragments(slime)
	var open := Narrative.fragments_to_place(slime)
	check(open.size() == all.size() - 1 and not open.has(all[2]), "the keeper's journal page waits for the reveal")
	Narrative.find(open[0])
	var left := Narrative.fragments_to_place(slime)
	check(left.size() == 1 and not left.has(open[0]), "a fragment found doesn't lie on a floor again while others remain")
	Narrative.find(left[0])
	check(Narrative.fragments_to_place(slime).is_empty(), "the others wait for the reveal: none")
	Profile.record_kill(&"nameless_effigy")
	Profile.wins["normal"] = 1
	var journal: Array[FragmentDef] = [all[2]]
	check(Narrative.fragments_to_place(slime) == journal, "after the reveal, the journal page")
	Narrative.find(all[2])
	check(Narrative.fragments_to_place(slime).size() == all.size(), "every one found: any may be found again")
	check(not Narrative.find(all[0]), "found twice: not new")
	# The hidden warden's fragments stay hidden until it was met.
	var effigy := _boss("nameless_effigy")
	_reset_story()
	check(Narrative.fragments_to_place(effigy).is_empty(), "the hidden warden's past waits until it was met")
	Profile.mark_seen(&"nameless_effigy")
	check(not Narrative.fragments_to_place(effigy).is_empty(), "met: its fragments may lie on the floors")
	_reset_story()


## The story's part of the profile is saved, and an older save loads without it.
func _test_profile_story() -> void:
	_reset_story()
	var path := "user://test_story_profile_%d.json" % OS.get_process_id()
	Profile.save_path = path
	Profile.chronicle_told["king_slime/what_floats"] = 1
	Profile.fragments_found["king_slime_wish"] = 1
	Profile.deeds_done["king_slime/before_it_swells"] = 1
	Profile.boss_meetings["king_slime"] = 3
	Profile.reach_depth(9)
	Profile.save_profile()
	_reset_story()
	Profile.load_profile()
	check(Profile.chronicle_told.has("king_slime/what_floats") and Profile.fragments_found.has("king_slime_wish") and Profile.deeds_done.has("king_slime/before_it_swells"), "chapters told, fragments found and deeds done are saved")
	check(int(Profile.boss_meetings.get("king_slime", 0)) == 3 and Profile.deepest == 9, "meetings and the deepest floor are saved")
	SafeFile.write_json(path, { "souls": 5, "best_depth": 6 })
	Profile.load_profile()
	check(Profile.chronicle_told.is_empty() and Profile.fragments_found.is_empty() and Profile.deeds_done.is_empty() and Profile.boss_meetings.is_empty(), "an older save: the story starts empty")
	check(Profile.stat_value("deepest") == 6, "an older save: the deepest floor is its record")
	Profile.save_path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_reset_story()


## The codex's Chronicle: open chapters in order, locked ones as ??? with what opens them, its
## fragments (found ones to read again).
func _test_codex_chronicle() -> void:
	_reset_story()
	var slime := _boss("king_slime")
	Profile.record_kill(&"king_slime")
	Profile.mark_seen(&"king_slime")
	Narrative.find(slime.chronicle.fragments[0])
	var codex := CodexPanel.new()
	add_child(codex)
	await _frames(2)
	codex.open(CONTENT, CodexPanel.Tab.BESTIARY)
	codex.open_monster(slime)
	await _frames(2)
	var page := codex.get_node("%MonsterPage") as MonsterPage
	var tab := page.find_child("ChronicleTab", true, false) as Button
	check(tab != null, "a warden's page has a Chronicle tab")
	if tab == null:
		codex.queue_free()
		return
	tab.pressed.emit()
	await _frames(2)
	var texts := _all_texts(page)
	check(texts.has(slime.chronicle.chapters[0].title) and texts.has(slime.chronicle.chapters[1].title), "the open chapters are listed with their titles")
	check(texts.has(slime.chronicle.chapters[0].lines[0]), "and their lines")
	check(texts.has("???") and texts.has("-  Slay it 2 times"), "a locked chapter: ??? and how to open it")
	check(texts.has("-  " + slime.chronicle.deeds()[0].hint), "a deed's chapter: its riddle, not the rule")
	check(not texts.has(slime.chronicle.chapters[3].lines[0]), "a locked chapter's lines stay hidden")
	check(texts.has(slime.chronicle.fragments[0].title) and texts.has("-  Found on the floors of Act I"), "fragments: the found one by its title, the others ??? with where they lie")
	var read: Button = null
	for button: Button in page.find_children("*", "Button", true, false):
		if button.text == slime.chronicle.fragments[0].title:
			read = button
	check(read != null, "a found fragment is a button")
	if read:
		read.pressed.emit()
		await _frames(2)
		var panel := codex.get_node("%FragmentPanel") as FragmentPanel
		check(panel.visible and panel.lines_text() == slime.chronicle.fragments[0].lines, "it opens its reading panel")
		codex.back()
		check(not panel.visible and codex.is_page_open(), "Back closes the fragment first")
	check(_off_grid_texts(codex).is_empty(), "the Chronicle's texts are on the font's grid")
	var scrolls := page.find_children("*", "ScrollContainer", true, false)
	check(not scrolls.is_empty(), "the Chronicle scrolls (its column is a scroll with the pixel-art bar)")
	codex.queue_free()
	await _frames(1)
	_reset_story()


func _test_options_stories() -> void:
	var options := OptionsPanel.new()
	add_child(options)
	await _frames(1)
	options.open()
	var before := Settings.boss_stories
	(options.get_node("%StoriesShort") as Button).pressed.emit()
	check(Settings.boss_stories == Settings.STORIES_SHORT, "the options set Boss stories to Short")
	(options.get_node("%StoriesOff") as Button).pressed.emit()
	check(Settings.boss_stories == Settings.STORIES_OFF and (options.get_node("%StoriesOff") as Button).button_pressed, "and Off, the picked button pressed")
	(options.get_node("%StoriesFull") as Button).pressed.emit()
	check(Settings.boss_stories == Settings.STORIES_FULL, "and Full")
	var path := "user://test_story_settings_%d.cfg" % OS.get_process_id()
	Settings.path = path
	Settings.boss_stories = Settings.STORIES_SHORT
	Settings.save_settings()
	Settings.boss_stories = Settings.STORIES_FULL
	Settings.load_settings()
	check(Settings.boss_stories == Settings.STORIES_SHORT, "Boss stories is saved in the settings")
	Settings.path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings.boss_stories = before
	options.queue_free()
	await _frames(1)


# --- Game ---------------------------------------------------------------------------------

## On the real game: the cinematic in an arena, skipped, not replayed, short, off; a deed done in
## a fight; fragments on the floors.
func run_game(game: Game) -> void:
	var saved := _snapshot()
	var stories := Settings.boss_stories
	game.start_run()
	await _frames(5)
	game.player.invincible = true
	_reset_story()
	await _test_cinematic(game)
	await _test_fragments_in_game(game)
	Settings.boss_stories = stories
	_restore(saved)


## Builds the boss floor of `depth` with `boss` as its warden.
func _boss_floor(game: Game, boss: BossDef, depth: int) -> BossArena:
	var bosses: Array[BossDef] = []
	var act := CONTENT.dungeon.act_index(depth)
	for i in CONTENT.dungeon.acts.size():
		bosses.append(boss if i == act else null)
	game.world.run_bosses = bosses
	game.run.bosses = bosses
	game.depth = depth
	game._enter_floor()
	await _frames(5)
	return game.world.arena


func _walk_in(game: Game) -> void:
	var world := game.world
	game.player.global_position = world.map.cell_to_world(world.map.boss_room.get_center() + Vector2i(0, 4))


func _tap() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_SPACE
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventKey.new()
	release.keycode = KEY_SPACE
	release.pressed = false
	Input.parse_input_event(release)


func _test_cinematic(game: Game) -> void:
	var slime := _boss("king_slime")
	var meeting := game.meeting
	var view := meeting.view
	Settings.boss_stories = Settings.STORIES_FULL
	var started := [0]
	var count_start := func(_boss: Monster) -> void: started[0] += 1
	Events.boss_started.connect(count_start)
	var arena := await _boss_floor(game, slime, 3)
	check(arena != null and arena.boss.def == slime, "the Bloated King's arena")
	if arena == null:
		return
	var hp := game.player.hp
	_walk_in(game)
	await _frames(3)
	check(arena.is_started and arena.is_closed(), "walking in closes the exits")
	check(meeting.is_playing() and game.get_tree().paused and arena.boss.dormant, "the story plays over the frozen world, the warden still asleep")
	check(view.visible and not game.hud.visible, "the bars come in, the HUD steps aside")
	check(game.is_menu_open() and not game.interactor.is_blocked.is_null() and game.interactor.is_blocked.call(), "no menu nor Interact meanwhile")
	var heading_seen := false
	for i in 400:
		if view.heading_text() == slime.chronicle.chapters[0].title:
			heading_seen = true
			break
		await _frames(1)
	check(heading_seen and not view.is_new_shown(), "the first chapter is told, without the \"new\" mark")
	check(view.name_text() == slime.display_name, "its name in the top bar")
	check(game.player.hp == hp and arena.boss.dormant and started[0] == 0, "nothing hurts and nothing fights meanwhile")
	_tap()
	await _frames(4)
	check(meeting.director.hurried and view.written_lines() == slime.chronicle.chapters[0].lines, "the first tap writes every line out")
	check(meeting.is_playing(), "and the scene waits")
	var rect := view.text_rect()
	check(view.bottom_bar_rect().encloses(rect) and view.get_viewport_rect().encloses(rect), "the text fits in the bottom bar, on screen")
	check(_off_grid_texts(view).is_empty(), "the cinematic's texts are on the font's grid")
	_tap()
	for i in 120:
		if not meeting.is_playing():
			break
		await _frames(1)
	check(not meeting.is_playing() and not game.get_tree().paused and not view.visible, "the second tap ends it")
	check(not arena.boss.dormant and started[0] == 1 and game.hud.visible, "then the warden wakes and the fight begins")
	check(Narrative.is_told(slime, slime.chronicle.chapters[0]) and Narrative.meetings(slime) == 1, "the chapter is told, the meeting counted")
	check(game.run.has_met_here(), "the run remembers this floor's warden was met")
	# A run picked up again on this floor: the story is not told twice.
	game._save_run()
	var saved := RunSave.read()
	check((saved.get("met_floors", []) as Array).has("3"), "the save keeps the floors whose warden was met")
	game.resume_run(saved)
	await _frames(5)
	var again := game.world.arena
	_walk_in(game)
	await _frames(3)
	check(again != null and again.is_started and not again.boss.dormant and not meeting.is_playing(), "picked up again mid-fight: no story, the fight at once")
	check(Narrative.meetings(slime) == 1, "and no second meeting counted")
	# Slain: a deed, if done (in time), and the next meeting tells the next chapter, marked new.
	var deed: DeedCondition = Narrative.deeds(slime)[0]
	var deeds := [0]
	var count_deed := func(_b: BossDef, _d: DeedCondition) -> void: deeds[0] += 1
	Events.deed_done.connect(count_deed)
	var blow := HitInfo.new()
	blow.amount = 999999
	blow.source = game.player
	blow.unavoidable = true
	again.boss.take_hit(blow)
	await _frames(5)
	check(again.boss.is_dead and deed.is_met(slime) and deeds[0] == 1, "slain within its time by the hero: the Bloated King's deed is done")
	Events.deed_done.disconnect(count_deed)
	await _frames(int(Game.RELIC_DELAY * 60.0) + 10)
	if game.perk_panel.visible:
		game.perk_panel.choose(0)  # its relic
		await _frames(3)
	game.run.met_floors.clear()  # (another run)
	arena = await _boss_floor(game, slime, 3)
	_walk_in(game)
	var new_seen := false
	for i in 400:
		if view.heading_text() == slime.chronicle.chapter_by_id(&"the_nushi").title:
			new_seen = view.is_new_shown()
			break
		await _frames(1)
	check(new_seen, "slain once, the next meeting tells the next chapter, marked \"new\"")
	_tap()
	await _frames(3)
	_tap()
	for i in 120:
		if not meeting.is_playing():
			break
		await _frames(1)
	check(not meeting.is_playing() and not arena.boss.dormant, "skipped, the fight begins")
	# Short: its name and one line, over in about two seconds, no tap.
	Settings.boss_stories = Settings.STORIES_SHORT
	game.run.met_floors.clear()
	arena = await _boss_floor(game, slime, 3)
	_walk_in(game)
	await _frames(3)
	check(meeting.is_playing(), "Short: a scene too")
	var frames := 0
	var lines := 0
	while meeting.is_playing() and frames < 400:
		await _frames(1)
		frames += 1
		lines = maxi(lines, view.written_lines().size())
	check(frames <= 240 and lines == 1 and not arena.boss.dormant, "Short: one line, over by itself in a few seconds (%d frames)" % frames)
	# Off: no scene, the fight at once, its name in a banner.
	Settings.boss_stories = Settings.STORIES_OFF
	game.run.met_floors.clear()
	arena = await _boss_floor(game, slime, 3)
	_walk_in(game)
	await _frames(3)
	check(not meeting.is_playing() and arena.is_started and not arena.boss.dormant, "Off: no scene, the fight at once")
	check(game.hud.is_banner_showing(), "Off: its name in a banner, as before")
	Events.boss_started.disconnect(count_start)


func _test_fragments_in_game(game: Game) -> void:
	var narrative := CONTENT.narrative
	var chance := narrative.fragment_chance
	narrative.fragment_chance = 1.0
	Profile.runs = 1
	game.run.met_floors.clear()
	game.world.run_bosses.clear()
	game.depth = 1
	game._enter_floor()
	await _frames(3)
	check(game.world.fragment == null, "no fragment during the first run (the tutorial)")
	Profile.runs = 5
	var act_boss := CONTENT.dungeon.acts[0].boss
	var found_any := false
	for depth in [1, 2, 3, 4]:
		game.depth = depth
		game._enter_floor()
		await _frames(2)
		var piece := game.world.fragment
		if CONTENT.dungeon.boss_for_depth(depth) != null:
			check(piece == null, "no fragment in a warden's arena (floor %d)" % depth)
			continue
		check(piece != null, "a fragment on floor %d (chance 1)" % depth)
		if piece == null:
			continue
		var boss := CONTENT.dungeon.acts[CONTENT.dungeon.act_index(depth)].boss
		check(piece.boss == boss and Narrative.fragments(boss).has(piece.def), "floor %d: a fragment of the warden waiting at the act's end" % depth)
		var cell := game.world.map.world_to_cell(piece.global_position)
		check(game.world.is_free_cell(cell) and cell != game.world.map.start_cell, "floor %d: on free ground, not where the hero starts" % depth)
		check(not game.world.find_path(game.player.global_position, piece.global_position).is_empty(), "floor %d: it can be reached" % depth)
		if not found_any:
			# It reads on every floor: a rim of its element's light round its picture (on dark
			# stone), a ring on the floor under every actor outlined by the element's dark edge
			# (on light grass and sand).
			var ring := piece.get_node_or_null(^"Ring") as Node2D
			var element := piece.glow_element()
			check(not piece.rim().is_empty() and element.shade(0.3).get_luminance() > 0.55, "a fragment: a rim of its element's light round its picture")
			check(ring != null and VfxLayer.of(ring) == VfxLayer.Layer.GROUND and ring.z_index < 0 and element.edge().get_luminance() < 0.3, "a fragment: a ring on the floor under the actors, outlined dark for light floors")
		found_any = true
	check(found_any, "fragments were laid")
	# Read it: the panel, kept for good, gone from the floor.
	game.depth = 1
	game._enter_floor()
	await _frames(2)
	var piece := game.world.fragment
	if piece:
		var def := piece.def
		game.player.global_position = piece.global_position + Vector2(0, 8)
		var used := await _tap_interact(game)
		check(used, "Interact reads a fragment")
		var panel := game.menus.fragment
		check(panel.visible and game.get_tree().paused and panel.lines_text().size() == def.lines.size(), "its panel opens over the paused game")
		check(Narrative.is_found(def) and game.world.fragment_taken and (not is_instance_valid(piece) or piece.taken), "found for good, gone from the floor")
		check(_off_grid_texts(panel).is_empty(), "the reading panel's texts are on the font's grid")
		var board := panel.board_rect()
		check(game.get_viewport().get_visible_rect().encloses(board), "the reading panel fits the screen")
		await _frames(20)
		_tap()
		await _frames(3)
		check(not panel.visible and not game.get_tree().paused, "a tap closes it, the game goes on")
		# Never again while the warden has others to find.
		for i in 6:
			game._enter_floor()
			await _frames(1)
			if game.world.fragment:
				check(game.world.fragment.def != def, "a fragment found doesn't lie on a floor again while others remain")
		# A save keeps it read: the floor picked up again doesn't lay another.
		game._enter_floor()
		await _frames(1)
		if game.world.fragment:
			game.world.fragment_taken = true
			var spent := game.world.spent_data()
			game.world.restore_spent(spent)
			game._enter_floor(true)
			await _frames(1)
			check(game.world.fragment_taken, "a floor picked up again keeps its fragment read")
	narrative.fragment_chance = chance
	game.world.run_bosses.clear()


# --- Helpers ------------------------------------------------------------------------------

func _boss(id: String) -> BossDef:
	return load("res://data/monsters/bosses/%s.tres" % id) as BossDef


## Every text shown under `root` (labels and buttons).
func _all_texts(root: Node) -> Array[String]:
	var result: Array[String] = []
	for node in root.find_children("*", "", true, false):
		if node is Label:
			result.append((node as Label).text)
		elif node is Button:
			result.append((node as Button).text)
	return result


## The profile's fields the story reads, to put back after.
func _snapshot() -> Dictionary:
	return {
		"kills": Profile.kills_by_monster.duplicate(true), "told": Profile.chronicle_told.duplicate(true),
		"fragments": Profile.fragments_found.duplicate(true), "deeds": Profile.deeds_done.duplicate(true),
		"meetings": Profile.boss_meetings.duplicate(true), "deepest": Profile.deepest, "wins": Profile.wins.duplicate(true),
		"victories": Profile.victories, "runs": Profile.runs, "challenges": Profile.challenges_done.duplicate(true),
		"seen": Profile.seen_monsters.duplicate(true), "best_depth": Profile.best_depth,
	}


func _restore(saved: Dictionary) -> void:
	Profile.kills_by_monster = saved.kills
	Profile.chronicle_told = saved.told
	Profile.fragments_found = saved.fragments
	Profile.deeds_done = saved.deeds
	Profile.boss_meetings = saved.meetings
	Profile.deepest = saved.deepest
	Profile.wins = saved.wins
	Profile.victories = saved.victories
	Profile.runs = saved.runs
	Profile.challenges_done = saved.challenges
	Profile.seen_monsters = saved.seen
	Profile.best_depth = saved.best_depth


## A profile that never heard a story (the rest as it is).
func _reset_story() -> void:
	Profile.kills_by_monster = {}
	Profile.chronicle_told = {}
	Profile.fragments_found = {}
	Profile.deeds_done = {}
	Profile.boss_meetings = {}
	Profile.deepest = 0
	Profile.best_depth = 0
	Profile.wins = {}
	Profile.victories = 0
	Profile.challenges_done = {}
	Profile.seen_monsters = {}
