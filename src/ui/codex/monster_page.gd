class_name MonsterPage
extends HBoxContainer
## One monster's page in the bestiary. Left: its look (animated), name, hunter rank and what
## each rank pays. Right: what it is, its stats and ways, its attacks (tap one to watch it in
## the AttackPreview), and its challenges (HuntChallenge). A monster only seen shows its look
## and its challenges; slay one to learn the rest.

signal back_requested

const LEFT_WIDTH := 330.0
const DIM := Color(1, 1, 1, 0.65)
const SOUL_COLOR := Color(0.65, 0.95, 1, 0.9)

var _monster: MonsterDef
var _content: ContentDB
var _preview: AttackPreview
var _attack_text: Label
var _attack_buttons: Array[Button] = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 24)
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func show_monster(monster: MonsterDef, content: ContentDB) -> void:
	_monster = monster
	_content = content
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var rules := content.bestiary
	var rank := Bestiary.rank_of(monster, rules)
	add_child(_left_column(rank, rules))
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	scroll.add_child(right)
	add_child(scroll)
	if rank >= 1:
		_fill_known(right)
	else:
		right.add_child(_label("Slay one to learn how it fights.", 18, DIM, true))
	right.add_child(_header("Challenges"))
	for challenge in rules.challenges_for(monster):
		right.add_child(_challenge_row(challenge))


# --- Left: look, name, rank ---------------------------------------------------------

func _left_column(rank: int, rules: BestiaryRules) -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = LEFT_WIDTH
	column.add_theme_constant_override("separation", 6)
	var back := Button.new()
	back.text = "< Bestiary"
	back.custom_minimum_size = Vector2(160, 48)
	back.focus_mode = Control.FOCUS_NONE
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func() -> void: back_requested.emit())
	column.add_child(back)
	column.add_child(_look())
	var name_label := _label(_monster.display_name, 26, Palette.DANGER if _monster is BossDef else Palette.GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var boss := _monster as BossDef
	if boss and not boss.title.is_empty():
		var title := _label(boss.title, 15, DIM)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(title)
	var kills := Profile.kill_count(_monster.id)
	if Profile.has_shiny(_monster.id):
		var shiny := _label("* Shiny found! *", 16, Color(1.0, 0.6, 0.95))
		shiny.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(shiny)
	var rank_line := _label("%s   -   %d slain" % [Bestiary.rank_name(rank, rules), kills], 18, Color.WHITE)
	rank_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(rank_line)
	var next := Bestiary.next_kills(_monster, rules)
	var bar := StatBar.new()
	bar.custom_minimum_size = Vector2(LEFT_WIDTH, 18)
	bar.font_size = 12
	bar.fill_color = Palette.GOLD if next > 0 else Palette.HEAL
	column.add_child(bar)
	if next > 0:
		bar.set_values(kills, next, "%d / %d to %s" % [kills, next, Bestiary.rank_name(maxi(rank, 0) + 1, rules)])
	else:
		bar.set_values(1, 1, "Mastered: +%d%% damage to it" % roundi(rules.mastery_damage * 100.0))
	var thresholds := rules.kills_for(_monster)
	var souls := rules.souls_for(_monster)
	for i in thresholds.size():
		var reached := rank > i
		var reward := "+%d souls" % souls[i] if i < souls.size() else ""
		if i == thresholds.size() - 1:
			reward += ", +%d%% damage" % roundi(rules.mastery_damage * 100.0)
		var line := _label("%s  (%d)   %s%s" % [rules.rank_names[i], thresholds[i], reward, "   Done" if reached else ""], 14, Palette.HEAL if reached else DIM)
		column.add_child(line)
	return column


## The monster, big and moving (unknown ones as a shadow).
func _look() -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(LEFT_WIDTH, 150)
	box.clip_contents = true
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _monster.frames
	sprite.offset = _monster.frames_offset
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(LEFT_WIDTH * 0.5, 100)
	sprite.scale = Vector2.ONE * (2.5 if _monster is BossDef else 4.0)
	AttackPreview._play_anim(sprite, [&"walk_down", &"idle_down", &"walk", &"idle"])
	if Bestiary.rank_of(_monster, _content.bestiary) == Bestiary.UNSEEN:
		sprite.modulate = Color(0, 0, 0, 0.8)
	box.add_child(sprite)
	return box


# --- Right: what it is, how it fights -----------------------------------------------

func _fill_known(column: VBoxContainer) -> void:
	if not _monster.description.is_empty():
		column.add_child(_label(_monster.description, 17, Color.WHITE, true))
	var stats := _monster.stats
	var weapon := _monster.weapon
	column.add_child(_label("HP %d   Damage %d   Armor %d   Speed %d   (on its first floors)" % [
		stats.max_hp if stats else 0, weapon.damage if weapon else 0, stats.defense if stats else 0,
		roundi(stats.move_speed) if stats else 0], 15, Palette.GOLD, true))
	for line in _ways():
		column.add_child(_label("-  " + line, 15, DIM, true))
	column.add_child(_header("Attacks"))
	_preview = AttackPreview.new()
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_preview)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	column.add_child(row)
	_attack_text = _label("", 15, Color.WHITE, true)
	column.add_child(_attack_text)
	_attack_buttons.clear()
	var attacks := _attacks()
	for i in attacks.size():
		var button := Button.new()
		button.text = attacks[i].name
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 44)
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_show_attack.bind(attacks[i], i))
		row.add_child(button)
		_attack_buttons.append(button)
	if not attacks.is_empty():
		_show_attack.call_deferred(attacks[0], 0)


## Its basic attack, its skills, and a boss' phase skills: [{ name, attack, text }].
func _attacks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var weapon := _monster.weapon
	if weapon:
		var how := "Melee, reach %d" % roundi(weapon.reach) if weapon.kind == WeaponDef.Kind.MELEE else "Shoots %s" % ("%d at a time" % weapon.projectile_count if weapon.projectile_count > 1 else "from afar")
		result.append({ "name": weapon.display_name if not weapon.display_name.is_empty() else "Attack", "attack": weapon, "text": "%s. %d damage." % [how, weapon.damage] })
	var skills: Array[SkillDef] = []
	for skill in _monster.skills:
		if skill and not skills.has(skill):
			skills.append(skill)
	var boss := _monster as BossDef
	var phase_of := {}
	if boss:
		for p in boss.phases.size():
			for skill in boss.phases[p].skills:
				if skill and not skills.has(skill):
					skills.append(skill)
					phase_of[skill] = p + 2
	var names := {}
	for skill in skills:
		var text := skill.description if not skill.description.is_empty() else ""
		text += "%sEvery %.0f s." % [" " if not text.is_empty() else "", skill.cooldown]
		var name := skill.display_name
		if phase_of.has(skill):
			text = "Phase %d: %s" % [phase_of[skill], text]
			if names.has(name):
				name += " (phase %d)" % phase_of[skill]  # its fiercer form
		names[skill.display_name] = true
		result.append({ "name": name, "attack": skill, "text": text })
	return result


func _show_attack(attack: Dictionary, index: int) -> void:
	for i in _attack_buttons.size():
		_attack_buttons[i].set_pressed_no_signal(i == index)
	_attack_text.text = attack.text
	var hero_frames := _content.player.frames if _content.player else null
	_preview.play(_monster, attack.attack, hero_frames)


## How it behaves, in a few lines.
func _ways() -> PackedStringArray:
	var lines := PackedStringArray()
	if _monster.flies:
		lines.append("Flies: holes and water don't stop it")
	if _monster.keep_distance > 0.0:
		lines.append("Keeps its distance")
	if _monster.knockback_resistance >= 0.5:
		lines.append("Hard to push around")
	for monster_trait in _monster.traits:
		if monster_trait and not monster_trait.describe().is_empty():
			lines.append(monster_trait.describe())
	var boss := _monster as BossDef
	if boss:
		if not boss.phases.is_empty():
			var at := PackedStringArray()
			for phase in boss.phases:
				at.append("%d%%" % roundi(phase.hp_ratio * 100.0))
			lines.append("%d phases: stronger and faster at %s HP" % [boss.phases.size() + 1, ", ".join(at)])
		if boss.shockwave_after_hits > 0:
			lines.append("Too many hits in a row: it throws you off with a shockwave")
	return lines


# --- Challenges -------------------------------------------------------------------

func _challenge_row(challenge: HuntChallenge) -> Control:
	var done := Profile.is_challenge_done(_monster.id, challenge.id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var mark := _label("Done" if done else "-", 15, Palette.HEAL if done else DIM)
	mark.custom_minimum_size.x = 44
	row.add_child(mark)
	var text := _label(challenge.describe(_monster), 15, Palette.HEAL if done else Color.WHITE, true)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	row.add_child(_label("+%d souls" % challenge.souls, 14, SOUL_COLOR))
	return row


func _header(text: String) -> Label:
	var label := _label(text, 20, Palette.GOLD)
	label.custom_minimum_size.y = 30
	return label


func _label(text: String, font_size: int, color: Color, wrap := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
