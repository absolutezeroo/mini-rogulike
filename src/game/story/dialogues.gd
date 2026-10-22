class_name Dialogues
## What a speaker says now (a service over the data, like Narrative): among a DialogueDef's lines,
## those whose conditions are met (the story's, and the run's facts: RunFacts) and that may be
## said again (a `once` line never twice, a `cooldown_runs` one not before its runs went by); of
## those, the highest `priority`; among equals, one never said before, else the one said longest
## ago, else any. Saying it keeps it (Narrative.tell_line: Profile.lines_told). No speaker is
## special here: the Vigil-Keeper's advice and the merchant's greeting are picked the same way.


## A line being said: its dialogue (the speaker), the line, its pages translated and filled.
class Spoken:
	extends RefCounted
	var dialogue: DialogueDef
	var line: DialogueLineDef
	var pages := PackedStringArray()
	## Shown apart (the advice after the tale): DialogueBox writes it in its accent color.
	var accent := false

	func speaker() -> SpeakerDef:
		return dialogue.speaker if dialogue else null

	func text() -> String:
		return " ".join(pages)


## `line` may be said now (its conditions met, not said too lately).
static func is_available(dialogue: DialogueDef, line: DialogueLineDef, facts: Resource = null) -> bool:
	if dialogue == null or line == null or not line.is_open(facts):
		return false
	var told_run := Narrative.line_told_run(dialogue, line)
	if told_run < 0:
		return true
	if line.once:
		return false
	return Profile.runs - told_run >= line.cooldown_runs


## The lines that may be said now, in the data's order.
static func available(dialogue: DialogueDef, facts: Resource = null) -> Array[DialogueLineDef]:
	var result: Array[DialogueLineDef] = []
	if dialogue:
		for line in dialogue.lines:
			if is_available(dialogue, line, facts):
				result.append(line)
	return result


## What would be said now (null: nothing). `rng` breaks the last ties (null: the global one).
static func pick(dialogue: DialogueDef, facts: Resource = null, rng: RandomNumberGenerator = null) -> DialogueLineDef:
	var best: Array[DialogueLineDef] = []
	var best_rank := []
	for line in available(dialogue, facts):
		# Higher priority first, then never said, then said longest ago.
		var told := Narrative.line_told_order(dialogue, line)
		var rank := [line.priority, 1 if told < 0 else 0, -told]
		if best.is_empty() or _beats(rank, best_rank):
			best = [line]
			best_rank = rank
		elif rank == best_rank:
			best.append(line)
	if best.is_empty():
		return null
	var index := rng.randi_range(0, best.size() - 1) if rng else randi() % best.size()
	return best[index]


## Something new to say: a line that may be said and never was (the shrine's mark over the
## Vigil-Keeper).
static func has_new(dialogue: DialogueDef, facts: Resource = null) -> bool:
	return available(dialogue, facts).any(func(line: DialogueLineDef) -> bool:
		return not Narrative.is_line_told(dialogue, line))


## Picks a line, keeps it as said and gives it out ready to show; null when nothing is open.
static func say(dialogue: DialogueDef, facts: Resource = null, rng: RandomNumberGenerator = null) -> Spoken:
	if dialogue:
		Narrative.count_talk(dialogue)
	var line := pick(dialogue, facts, rng)
	if line == null:
		return null
	Narrative.tell_line(dialogue, line)
	var spoken := Spoken.new()
	spoken.dialogue = dialogue
	spoken.line = line
	spoken.pages = pages(line, facts)
	return spoken


## Says one line of each dialogue in turn (the tale, then the advice): those with nothing to
## say are skipped. The second and later ones are accents (the advice stands apart).
static func say_all(dialogues: Array[DialogueDef], facts: Resource = null, rng: RandomNumberGenerator = null) -> Array[Spoken]:
	var result: Array[Spoken] = []
	for dialogue in dialogues:
		var spoken := say(dialogue, facts, rng)
		if spoken:
			spoken.accent = not result.is_empty()
			result.append(spoken)
	return result


## Its pages in the player's language, the run's facts filled in ({killer}, {floor}...).
static func pages(line: DialogueLineDef, facts: Resource = null) -> PackedStringArray:
	var result := PackedStringArray()
	var codes: Dictionary = (facts as RunFacts).codes() if facts is RunFacts else {}
	for page in line.lines:
		var text := TranslationServer.tr(page)
		result.append(text.format(codes) if not codes.is_empty() else text)
	return result


## Every dialogue whose lines the codex keeps, grouped by speaker in the order first met in
## `dialogues`: [{speaker, dialogues: Array[DialogueDef]}].
static func by_speaker(dialogues: Array[DialogueDef]) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for dialogue in dialogues:
		if dialogue == null or dialogue.speaker == null:
			continue
		var group: Dictionary = {}
		for existing in groups:
			if existing.speaker == dialogue.speaker:
				group = existing
		if group.is_empty():
			group = {"speaker": dialogue.speaker, "dialogues": [] as Array[DialogueDef]}
			groups.append(group)
		(group.dialogues as Array[DialogueDef]).append(dialogue)
	return groups


static func _beats(rank: Array, other: Array) -> bool:
	for i in rank.size():
		if rank[i] != other[i]:
			return rank[i] > other[i]
	return false
