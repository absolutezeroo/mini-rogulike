class_name Narrative
## The story's progress and its answers (a service over the Profile, like Bestiary): which
## chapters of a warden's chronicle are open and which were told, the fragments found, the
## deeds done, the meetings, and what to tell at the next meeting (plan()). Only this writes the
## story's part of the Profile; the cinematic, the codex and the fragment panel ask it and
## never decide. Texts stay English keys, translated where they are shown.


# --- Chapters -------------------------------------------------------------------

static func chapters(boss: BossDef) -> Array[ChronicleChapter]:
	var result: Array[ChronicleChapter] = []
	if boss and boss.chronicle:
		for chapter in boss.chronicle.chapters:
			if chapter:
				result.append(chapter)
	return result


static func is_open(boss: BossDef, chapter: ChronicleChapter) -> bool:
	return chapter != null and chapter.is_open(boss)


## The open chapters, in order (the codex reads them all, told or not).
static func open_chapters(boss: BossDef) -> Array[ChronicleChapter]:
	var result: Array[ChronicleChapter] = []
	for chapter in chapters(boss):
		if chapter.is_open(boss):
			result.append(chapter)
	return result


static func is_told(boss: BossDef, chapter: ChronicleChapter) -> bool:
	return chapter != null and Profile.chronicle_told.has(_key(boss, chapter.id))


static func told_count(boss: BossDef) -> int:
	return chapters(boss).filter(func(chapter: ChronicleChapter) -> bool: return is_told(boss, chapter)).size()


## The next chapter to tell: the first open one never told (one per meeting, in order).
static func next_chapter(boss: BossDef) -> ChronicleChapter:
	for chapter in chapters(boss):
		if chapter.is_open(boss) and not is_told(boss, chapter):
			return chapter
	return null


# --- Waking words ---------------------------------------------------------------

## What it says as it wakes: the last open line of its chronicle (null: nothing yet).
static func speech(boss: BossDef) -> WakingLine:
	if boss == null or boss.chronicle == null:
		return null
	var result: WakingLine = null
	for line in boss.chronicle.waking_lines:
		if line and line.is_open(boss):
			result = line
	return result


## What it says as it falls: the last open one of its last words (null: nothing).
static func last_words(boss: BossDef) -> WakingLine:
	if boss == null or boss.chronicle == null:
		return null
	var result: WakingLine = null
	for line in boss.chronicle.last_words:
		if line and line.is_open(boss):
			result = line
	return result


static func is_speech_told(boss: BossDef, line: WakingLine) -> bool:
	return line != null and Profile.chronicle_told.has(_key(boss, line.id))


# --- Fragments ------------------------------------------------------------------

static func fragments(boss: BossDef) -> Array[FragmentDef]:
	var result: Array[FragmentDef] = []
	if boss and boss.chronicle:
		for fragment in boss.chronicle.fragments:
			if fragment:
				result.append(fragment)
	return result


static func is_found(fragment: FragmentDef) -> bool:
	return fragment != null and Profile.fragments_found.has(String(fragment.id))


static func found_count(boss: BossDef) -> int:
	return fragments(boss).filter(func(fragment: FragmentDef) -> bool: return is_found(fragment)).size()


## Picked up: kept for good. True the first time.
static func find(fragment: FragmentDef) -> bool:
	if fragment == null or is_found(fragment):
		return false
	Profile.fragments_found[String(fragment.id)] = 1
	Profile.save_profile()
	return true


## The fragments that may lie on a floor before this warden now: those not found yet (all of
## them once every one was found), and only those whose conditions are met.
static func fragments_to_place(boss: BossDef) -> Array[FragmentDef]:
	var allowed := fragments(boss).filter(func(fragment: FragmentDef) -> bool: return fragment.can_appear(boss))
	var missing := allowed.filter(func(fragment: FragmentDef) -> bool: return not is_found(fragment))
	var result: Array[FragmentDef] = []
	result.assign(missing if not missing.is_empty() or found_count(boss) < fragments(boss).size() else allowed)
	return result


# --- Deeds ----------------------------------------------------------------------

static func deeds(boss: BossDef) -> Array[DeedCondition]:
	if boss == null or boss.chronicle == null:
		return []
	return boss.chronicle.deeds()


static func is_deed_done(boss: MonsterDef, deed: DeedCondition) -> bool:
	return boss != null and deed != null and Profile.deeds_done.has("%s/%s" % [boss.id, deed.id])


## The deeds of `boss` its death described by `kill` (HuntTracker.kill_context()) fulfils, now
## kept for good. Returns the new ones.
static func record_deeds(boss: BossDef, kill: Dictionary) -> Array[DeedCondition]:
	var done: Array[DeedCondition] = []
	for deed in deeds(boss):
		if not deed.is_met(boss) and deed.achieved(kill):
			Profile.deeds_done["%s/%s" % [boss.id, deed.id]] = 1
			done.append(deed)
	return done


# --- Meetings -------------------------------------------------------------------

static func meetings(boss: BossDef) -> int:
	return int(Profile.boss_meetings.get(String(boss.id), 0))


## What to tell when the hero meets `boss` with the Boss stories option `mode` (Settings.STORIES_FULL,
## STORIES_SHORT; STORIES_OFF: nothing). Nothing is marked told here: tell() does it when the scene plays.
static func plan(boss: BossDef, mode: int) -> StoryBeat:
	var beat := StoryBeat.new()
	beat.boss = boss
	if boss == null or mode == Settings.STORIES_OFF:
		return beat
	beat.name = boss.display_name
	beat.title = boss.title
	beat.speech = speech(boss)
	beat.speech_is_new = beat.speech != null and not is_speech_told(boss, beat.speech)
	beat.echo = echo_line(boss)
	if mode == Settings.STORIES_FULL:
		beat.chapter = next_chapter(boss)
		beat.chapter_is_new = beat.chapter != null and told_count(boss) > 0
		beat.is_full = beat.chapter != null or beat.speech_is_new
	return beat


## The beat is shown: its chapter and words are told, and the meeting counted.
static func tell(beat: StoryBeat) -> void:
	if beat == null or beat.boss == null:
		return
	if beat.chapter:
		Profile.chronicle_told[_key(beat.boss, beat.chapter.id)] = 1
	if beat.speech and beat.is_full:
		Profile.chronicle_told[_key(beat.boss, beat.speech.id)] = 1
	Profile.save_profile()


## The hero walked into its arena (once a floor): counted.
static func count_meeting(boss: BossDef) -> void:
	if boss:
		Profile.boss_meetings[String(boss.id)] = meetings(boss) + 1


## A line the short version recalls: a chapter already told (a different one each meeting),
## else the first line of its first chapter.
static func echo_line(boss: BossDef) -> String:
	var told: Array[String] = []
	for chapter in chapters(boss):
		if is_told(boss, chapter):
			for line in chapter.lines:
				told.append(line)
	if not told.is_empty():
		return told[meetings(boss) % told.size()]
	var all := chapters(boss)
	return all[0].lines[0] if not all.is_empty() and not all[0].lines.is_empty() else ""


# --- Dialogue -----------------------------------------------------------------

## `line` of `dialogue` was said at least once.
static func is_line_told(dialogue: DialogueDef, line: DialogueLineDef) -> bool:
	return dialogue != null and line != null and Profile.lines_told.has(_line_key(dialogue, line))


## The run it was last said in (-1: never).
static func line_told_run(dialogue: DialogueDef, line: DialogueLineDef) -> int:
	return int(Profile.lines_told.get(_line_key(dialogue, line), -1)) if dialogue and line else -1


## When it was last said among all the lines (bigger: later; -1: never).
static func line_told_order(dialogue: DialogueDef, line: DialogueLineDef) -> int:
	return int(Profile.lines_order.get(_line_key(dialogue, line), -1)) if dialogue and line else -1


## `line` of `dialogue` is being said now: kept (this run, after every line said before).
static func tell_line(dialogue: DialogueDef, line: DialogueLineDef) -> void:
	if dialogue == null or line == null:
		return
	var latest := -1
	for order: int in Profile.lines_order.values():
		latest = maxi(latest, order)
	var key := _line_key(dialogue, line)
	Profile.lines_told[key] = Profile.runs
	Profile.lines_order[key] = latest + 1
	Profile.save_profile()


## `dialogue` was opened once more (the merchant's shop, the forge...): a StatCondition on
## "talk:<its id>" waits for so many meetings (Profile.stat_value).
static func count_talk(dialogue: DialogueDef) -> void:
	if dialogue:
		var key := "talk:%s" % dialogue.id
		Profile.stats[key] = int(Profile.stats.get(key, 0)) + 1


static func talks(dialogue: DialogueDef) -> int:
	return int(Profile.stats.get("talk:%s" % dialogue.id, 0)) if dialogue else 0


## The lines of `dialogue` said and kept for the codex (remembered), in the data's order.
static func told_lines(dialogue: DialogueDef) -> Array[DialogueLineDef]:
	var result: Array[DialogueLineDef] = []
	if dialogue:
		for line in dialogue.lines:
			if line and line.remembered and is_line_told(dialogue, line):
				result.append(line)
	return result


static func _line_key(dialogue: DialogueDef, line: DialogueLineDef) -> String:
	return "%s/%s" % [dialogue.id, line.id]


static func _key(boss: BossDef, id: StringName) -> String:
	return "%s/%s" % [boss.id, id]
