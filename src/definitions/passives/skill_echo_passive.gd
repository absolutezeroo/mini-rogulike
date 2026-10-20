class_name SkillEchoPassive
extends Passive
## Using a skill may leave it ready again at once (chance per stack).
## An echo can't echo: the cast an echo made ready rolls nothing, whatever the sources (Echo
## perk, Echo runes, of Echoes), so a skill is used at most twice per cooldown. Every source
## rolls on its own, and a single success is enough.

@export_range(0.0, 1.0) var chance_per_stack: float = 0.15
@export var color: Color = Color("b388eb")

## Owner meta: { skill, frame, spent } of the last echo (shared by every echo source).
const STATE := &"_skill_echo"


func on_skill_used(owner: Actor, skill: SkillDef, perk: PerkSet.Entry) -> void:
	var frame := Engine.get_process_frames()
	var state: Dictionary = owner.get_meta(STATE, {})
	if not state.is_empty() and state.skill == skill:
		if state.frame == frame:
			return  # another source already decided for this cast
		if not state.spent:
			# This cast is the echo: it can't echo again.
			owner.set_meta(STATE, { "skill": skill, "frame": frame, "spent": true })
			return
	if randf() >= chance_per_stack * perk.stacks:
		return
	owner.set_meta(STATE, { "skill": skill, "frame": frame, "spent": false })
	owner.skills.reset_cooldown(skill)
	owner.world.spawn_floating_text(owner.head_position(), "ECHO", color)
