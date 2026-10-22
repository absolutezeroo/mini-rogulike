class_name BossMeeting
extends Storyteller
## The moment the hero walks into a warden's arena, before it wakes (the World's storyteller,
## called by BossArena.start()): the meeting is counted, and its story told by a cinematic
## (Narrative.plan(): a new chapter, its waking words, or its name and a line it remembers),
## the game paused around it so nothing moves and nothing hurts. Owned by the Game.
## Never twice on the same floor of a run (RunState.met_floors: a run picked up again mid-fight
## doesn't replay it), never with Boss stories off (Settings), never for a boss without a
## chronicle.

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


## The hero met `boss` in its arena. Plays its story if there is one to tell (the game paused
## meanwhile). Returns true if the boss already woke on screen (its intro animation played).
func meet(boss: Monster) -> bool:
	var def := boss.def as BossDef if boss else null
	var run := game.run if game else null
	if def == null or run == null:
		return false
	if run.has_met_here():
		return false  # told already on this floor (a run picked up again)
	run.meet_here()
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
