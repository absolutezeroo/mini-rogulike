class_name NarrateStep
extends CinematicStep
## Lines written in the bottom bar, one after the other, typed or faded in (CinematicDef's
## text tuning), each left to be read. What it tells comes from the director's story
## (StoryBeat): the chapter being told, the subject's own words (quoted), or the one line the
## short version remembers.

enum Source {
	## The chapter told this time, under its title (with "New" when it is not the first one).
	CHAPTER,
	## What the subject says as it wakes, in quotes (nothing if it says nothing).
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
	var heading := ""
	var is_new := false
	var lines := PackedStringArray()
	var speech := false
	match source:
		Source.CHAPTER:
			if beat.chapter == null:
				return
			heading = tr(beat.chapter.title)
			is_new = beat.chapter_is_new
			for line in beat.chapter.lines:
				lines.append(tr(line))
		Source.SPEECH:
			if beat.speech == null:
				return
			lines.append(tr("\"%s\"") % tr(beat.speech.line))
			speech = true
		Source.ECHO:
			if beat.speech:
				lines.append(tr("\"%s\"") % tr(beat.speech.line))
				speech = true
			elif not beat.echo.is_empty():
				lines.append(tr(beat.echo))
			else:
				return
	await director.narrate(heading, is_new, lines, speech_color if speech else text_color, typed)
