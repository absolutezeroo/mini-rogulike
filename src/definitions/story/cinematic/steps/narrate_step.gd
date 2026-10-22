class_name NarrateStep
extends CinematicStep
## Lines written in the bottom bar, one after the other, typed or faded in (CinematicDef's
## text tuning), each left to be read. What it tells comes from the director's story
## (StoryBeat): the chapter being told, the subject's own words (quoted), or the one line the
## short version remembers.

enum Source {
	## The chapter told this time, under its title (with "New" when it is not the first one),
	## after the subject's own words if it says some: one block, written out at once by a tap.
	CHAPTER,
	## Only what the subject says as it wakes, in quotes (nothing if it says nothing).
	SPEECH,
	## One line: its words if it has some, else a line of a chapter already told.
	ECHO,
}

@export var source: Source = Source.CHAPTER
## Typed letter by letter (CinematicDef.chars_per_second) or faded in whole.
@export var typed: bool = true
@export var speech_color: Color = Color(0.78, 0.9, 1.0)
@export var text_color: Color = Color(1.0, 0.95, 0.85)


func play(director: CinematicDirector) -> void:
	var beat := director.story
	if beat == null:
		return
	var speech := tr("\"%s\"") % tr(beat.speech.line) if beat.speech else ""
	match source:
		Source.CHAPTER:
			var lines := PackedStringArray()
			if beat.chapter:
				for line in beat.chapter.lines:
					lines.append(tr(line))
			var heading := tr(beat.chapter.title) if beat.chapter else ""
			await director.narrate(heading, beat.chapter_is_new, lines, text_color, typed, speech, speech_color)
		Source.SPEECH:
			await director.narrate("", false, PackedStringArray(), text_color, typed, speech, speech_color)
		Source.ECHO:
			if not speech.is_empty():
				await director.narrate("", false, PackedStringArray(), text_color, typed, speech, speech_color)
			elif not beat.echo.is_empty():
				await director.narrate("", false, PackedStringArray([tr(beat.echo)]), text_color, typed)
