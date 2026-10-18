class_name ParticleBurst
extends CPUParticles2D
## One-shot particle effect: starts emitting when added to the tree and frees itself when done.
## The particle scenes in res://src/vfx/particles/ use this script; tweak them in the editor.


func _ready() -> void:
	one_shot = true
	finished.connect(queue_free)
	restart()
