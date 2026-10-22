class_name NameStep
extends CinematicStep
## The subject's name and title appear in the top bar ("La Matrone du Bourbier" / "Gardienne de
## la Source Croupie").

@export var hold: float = 0.9
@export var name_color: Color = Color(1.0, 0.36, 0.3)
@export var title_color: Color = Color(1.0, 0.82, 0.4)


func play(director: CinematicDirector) -> void:
	var beat := director.story
	if beat == null:
		return
	director.view.show_name(tr(beat.name), tr(beat.title) if not beat.title.is_empty() else "", name_color, title_color)
	await director.wait(hold)
