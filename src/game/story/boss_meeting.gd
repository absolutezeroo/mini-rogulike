class_name BossMeeting
extends Storyteller
## The moment the hero walks into a warden's arena, before it wakes (the World's storyteller,
## called by BossArena.start()): the meeting is counted, and its story told by a cinematic
## (Narrative.plan(): a new chapter, its waking words, or its name and a line it remembers),
## the game paused around it so nothing moves and nothing hurts. Owned by the Game.
## Never twice on the same floor of a run (RunState.met_floors: a run picked up again mid-fight
## doesn't replay it), never with Boss stories off (Settings), never for a boss without a
## chronicle. A form rising from a fallen one (BossDef.next_boss: the Maw out of the tar) is met
## too, once its rise is over, under its own key. When a warden falls it may say its last words
## (Narrative.last_words(), on its banner).

var game: Game
var narrative: NarrativeDef
var director := CinematicDirector.new()
var view := CinematicView.new()
## The last warden whose story was shown (its instance id: its name needs no banner after it).
var last_told := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	director.name = "Director"
	director.view = view
	add_child(director)
	var layer := CanvasLayer.new()
	layer.name = "Cinematic"
	layer.layer = 7  # above the HUD (5) and the hints (6), under the menus (10)
	add_child(layer)
	view.name = "CinematicView"
	layer.add_child(view)


func is_playing() -> bool:
	return director.is_playing()


## The hero met `boss` in its arena (`risen`: it just rose from a fallen form). Plays its story
## if there is one to tell (the game paused meanwhile). Returns true if the boss already woke on
## screen (its intro animation played).
func meet(boss: Monster, risen := false) -> bool:
	var def := boss.def as BossDef if boss else null
	var run := game.run if game else null
	if def == null or run == null:
		return false
	var form := def.id if risen else &""
	if run.has_met_here(form):
		return false  # told already on this floor (a run picked up again)
	run.meet_here(form)
	Narrative.count_meeting(def)
	var beat := Narrative.plan(def, Settings.boss_stories)
	if narrative == null or def.chronicle == null or not beat.has_words():
		return false
	var cinematic := narrative.full_cinematic if beat.is_full else narrative.short_cinematic
	if cinematic == null:
		return false
	Narrative.tell(beat)
	last_told = boss.get_instance_id()
	var player := game.player
	director.camera = player.get_node_or_null("Camera") as Camera2D
	director.hero = player
	game.pause_for_cinematic(true)
	await director.play(cinematic, boss, beat)
	if is_instance_valid(game):
		game.pause_for_cinematic(false)
	return director.played_animation


## What `def` says as it falls (an English key, "" for nothing): its chronicle's last open last
## words, with Boss stories on (Short too: they are one line).
func last_words(def: BossDef) -> String:
	if def == null or Settings.boss_stories == Settings.STORIES_OFF:
		return ""
	var words := Narrative.last_words(def)
	return words.line if words else ""
