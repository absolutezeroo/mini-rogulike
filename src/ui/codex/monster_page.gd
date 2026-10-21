class_name MonsterPage
extends HBoxContainer
## One monster's page in the bestiary, in three dark insets. Left: its look (animated), name,
## what it is, where it lives, its Shiny. Middle: its attacks (tap one to watch it in the AttackPreview),
## how it behaves and its stats, each with what the number means. Right: your hunter rank with
## it (what each rank needs and pays) and its challenges (HuntChallenge). A monster
## only seen shows its look, ranks and challenges; slay one to learn the rest.

signal back_requested

const LEFT_WIDTH := 300.0
const RIGHT_WIDTH := 370.0
const SHINY_COLOR := CodexCard.SHINY_COLOR

var _monster: MonsterDef
var _content: ContentDB
var _preview: AttackPreview
var _attack_text: Label
var _attack_buttons: Array[Button] = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 12)
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func show_monster(monster: MonsterDef, content: ContentDB) -> void:
	_monster = monster
	_content = content
	clear()
	var rules := content.bestiary
	var rank := Bestiary.rank_of(monster, rules)
	add_child(_column(LEFT_WIDTH, _fill_identity.bind(rank, rules)))
	var middle := _column(0.0, _fill_attacks.bind(rank))
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(middle)
	add_child(_column(RIGHT_WIDTH, _fill_hunt.bind(rank, rules)))
	if rank >= 1:
		var attacks := _attacks()
		if not attacks.is_empty():
			_show_attack.call_deferred(attacks[0], 0)


func clear() -> void:
	_preview = null
	_attack_buttons.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()


## A dark inset that scrolls with a finger, filled by `fill` (it gets the inner column).
func _column(width: float, fill: Callable) -> Control:
	var box := UiSkin.section()
	box.custom_minimum_size.x = width
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 12)  # room for the scroll bar
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	TouchScroll.attach(scroll)
	fill.call(column)
	return box


# --- Left: look, name, what it is --------------------------------------------------

func _fill_identity(column: VBoxContainer, rank: int, rules: BestiaryRules) -> void:
	var back := Button.new()
	back.text = tr("< All monsters")
	back.name = "BackButton"
	back.custom_minimum_size = Vector2(0, 46)
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 17)
	back.pressed.connect(func() -> void: back_requested.emit())
	column.add_child(back)
	column.add_child(_look())
	var name_label := UiSkin.label(tr(_monster.display_name), 24, Palette.DANGER if _monster is BossDef else UiSkin.GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var boss := _monster as BossDef
	if boss:
		var kind_label := UiSkin.label(tr("Boss  -  %s") % tr(boss.title) if not boss.title.is_empty() else tr("Boss"), 15, UiSkin.DIM, true)
		kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(kind_label)
	var kills := Profile.kill_count(_monster.id)
	var status := UiSkin.label(tr("%s  -  %d slain") % [Bestiary.rank_name(rank, rules), kills], 17, CodexRows.DONE if Bestiary.is_mastered(_monster, rules) else UiSkin.TEXT, true)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(status)
	if rank < 1:
		column.add_child(UiSkin.label(tr("You have seen it, but never slain one. Slay one to learn what it is, its stats and how it attacks."), 15, UiSkin.DIM, true))
		_add_shiny(column)
		return
	if not _monster.description.is_empty():
		column.add_child(UiSkin.label(tr(_monster.description), 16, UiSkin.TEXT, true))
	var home := _home()
	if not home.is_empty():
		column.add_child(CodexRows.fact(tr("Lives in"), home))
	_add_shiny(column)



## "Act I, floors 1 to 3" (bosses: "Act I, floor 3"): where it first shows up.
func _home() -> String:
	var acts := _content.dungeon.acts
	for i in acts.size():
		var act := acts[i]
		var first := _content.dungeon.first_depth(i)
		var last := first + act.floors - 1
		if act.all_bosses().has(_monster):
			return tr("%s, floor %d") % [tr(act.subtitle), last]
		if act.monsters.has(_monster):
			if act.floors <= 1:
				return tr("%s, floor %d") % [tr(act.subtitle), first]
			return tr("%s, floors %d to %d") % [tr(act.subtitle), first, last]
	var hidden := _content.dungeon.hidden_floor
	if hidden and hidden.boss == _monster:
		return tr(hidden.title)
	return ""


## [name, value, what it means] for Health, Damage, Armor and Move speed.
func _stats() -> Array[Array]:
	var stats := _monster.stats
	var weapon := _monster.weapon
	var hero := _content.player.base_stats if _content.player else null
	var health := stats.max_hp if stats else 0
	var damage := weapon.damage if weapon else 0
	var armor := stats.defense if stats else 0
	var speed := roundi(stats.move_speed) if stats else 0
	var health_note := tr("How much damage it takes to slay it.")
	var damage_note := tr("Health you lose when its basic attack hits you.")
	if hero:
		damage_note += " " + tr("You start a run with %d Health.") % hero.max_hp
	var armor_note := tr("Softens your hits, small ones most: a 10-damage hit does %d, a 30-damage hit %d.") % [Combat.mitigate(10, armor), Combat.mitigate(30, armor)] if armor > 0 else tr("None: your hits land in full.")
	var speed_note := tr("How fast it walks.")
	if hero and stats:
		var ratio := stats.move_speed / maxf(hero.move_speed, 1.0)
		speed_note = tr("Slower than you (%d).") % roundi(hero.move_speed)
		if ratio > 1.08:
			speed_note = tr("Faster than you (%d): you can't outrun it.") % roundi(hero.move_speed)
		elif ratio > 0.92:
			speed_note = tr("About as fast as you (%d).") % roundi(hero.move_speed)
	return [
		[tr("Health"), str(health), health_note],
		[tr("Damage"), str(damage), damage_note],
		[tr("Armor"), str(armor), armor_note],
		[tr("Move speed"), str(speed), speed_note],
	]


## The monster, big and moving (unknown ones as a shadow).
func _look() -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(LEFT_WIDTH - 44, 104)
	box.clip_contents = true
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _monster.frames
	sprite.offset = _monster.frames_offset
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2((LEFT_WIDTH - 44) * 0.5, 74)
	sprite.scale = Vector2.ONE * (2.2 if _monster is BossDef else 3.5)
	AttackPreview._play_anim(sprite, [&"walk_down", &"idle_down", &"walk", &"idle"])
	if Bestiary.rank_of(_monster, _content.bestiary) == Bestiary.UNSEEN:
		sprite.modulate = Color(0, 0, 0, 0.8)
	box.add_child(sprite)
	return box


# --- Middle: how it fights -----------------------------------------------------------

func _fill_attacks(column: VBoxContainer, rank: int) -> void:
	column.add_child(_heading(tr("Attacks")))
	if rank < 1:
		column.add_child(UiSkin.label(tr("Slay one to see how it attacks."), 16, UiSkin.DIM, true))
		return
	column.add_child(UiSkin.label(tr("Tap an attack to watch it. Red marks on the ground show where it will land: step out!"), 14, UiSkin.DIM, true))
	_preview = AttackPreview.new()
	_preview.custom_minimum_size = Vector2(0, 184)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_preview)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	column.add_child(row)
	var attacks := _attacks()
	for i in attacks.size():
		var button := Button.new()
		button.text = attacks[i].name
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 44)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_show_attack.bind(attacks[i], i))
		row.add_child(button)
		_attack_buttons.append(button)
	_attack_text = UiSkin.label("", 16, UiSkin.TEXT, true)
	column.add_child(_attack_text)
	var ways := _ways()
	if not ways.is_empty():
		column.add_child(_heading(tr("How it behaves")))
		for line in ways:
			column.add_child(UiSkin.label("-  " + line, 15, UiSkin.TEXT, true))
	column.add_child(_heading(tr("Stats")))
	column.add_child(UiSkin.label(tr("On the floors where it first shows up: deeper down, it grows stronger."), 14, UiSkin.DIM, true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	for line in _stats():
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(CodexRows.fact(line[0], line[1], UiSkin.GOLD))
		cell.add_child(UiSkin.label(line[2], 14, UiSkin.DIM, true))
		grid.add_child(cell)


## Its basic attack, its skills, and a boss' phase skills: [{ name, attack, text }].
func _attacks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var weapon := _monster.weapon
	if weapon:
		var how := tr("Up close")
		if weapon.kind == WeaponDef.Kind.RANGED:
			how = tr("Shoots %d at once, from afar") % weapon.projectile_count if weapon.projectile_count > 1 else tr("Shoots from afar")
		elif weapon.reach >= 40.0:
			how = tr("Up close, with a long reach")
		result.append({ "name": tr(weapon.display_name) if not weapon.display_name.is_empty() else tr("Attack"), "attack": weapon, "text": tr("Basic attack. %s: %d damage.") % [how, weapon.damage] })
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
		var text := tr(skill.description) if not skill.description.is_empty() else ""
		text += (" " if not text.is_empty() else "") + tr("Used every %.0f seconds.") % skill.cooldown
		var name := tr(skill.display_name)
		if phase_of.has(skill):
			text = tr("From phase %d. %s") % [phase_of[skill], text]
			if names.has(name):
				name += " " + tr("(phase %d)") % phase_of[skill]  # its fiercer form
		names[tr(skill.display_name)] = true
		result.append({ "name": name, "attack": skill, "text": text })
	return result


func _show_attack(attack: Dictionary, index: int) -> void:
	if _preview == null or not is_instance_valid(_preview):
		return
	for i in _attack_buttons.size():
		_attack_buttons[i].set_pressed_no_signal(i == index)
	_attack_text.text = attack.text
	var hero_frames := _content.player.frames if _content.player else null
	_preview.play(_monster, attack.attack, hero_frames)


## How it behaves, in a few lines.
func _ways() -> PackedStringArray:
	var lines := PackedStringArray()
	if _monster.flies:
		lines.append(tr("Flies: holes and water don't stop it."))
	if _monster.keep_distance > 0.0:
		lines.append(tr("Keeps its distance: close in on it."))
	if _monster.knockback_resistance >= 0.5:
		lines.append(tr("Hard to push around (or into holes)."))
	for monster_trait in _monster.traits:
		if monster_trait and not monster_trait.describe().is_empty():
			lines.append(monster_trait.describe())
	var boss := _monster as BossDef
	if boss:
		if not boss.phases.is_empty():
			var at := PackedStringArray()
			for phase in boss.phases:
				at.append(tr("%d%%") % roundi(phase.hp_ratio * 100.0))
			lines.append(tr("Fights in %d phases: stronger and faster once its Health drops to %s.") % [boss.phases.size() + 1, tr(", then ").join(at)])
		if boss.shockwave_after_hits > 0:
			lines.append(tr("Hit it too many times in a row and it throws you off with a shockwave."))
	return lines


# --- Right: your hunt ------------------------------------------------------------------

## The Shiny: a rare glowing one of this kind, found (slain) or not yet.
func _add_shiny(column: VBoxContainer) -> void:
	column.add_child(_heading(tr("Celestial")))
	var found := Profile.has_shiny(_monster.id)
	column.add_child(_goal_row(found, tr("Found!") if found else tr("Not found yet"), ""))
	column.add_child(UiSkin.label(tr("A rare glowing version%s: tougher, but it drops plenty of loot and gold. Slay one to add it to your collection.") % _shiny_odds(), 14, UiSkin.DIM, true))


## " (about 1 in 400)", from the Shiny rank's chance ("" if there is none).
func _shiny_odds() -> String:
	for rank in _content.dungeon.rare_ranks:
		if rank and rank.shimmer:
			var chance := rank.boss_chance if _monster is BossDef else rank.chance
			return tr(" (about 1 in %d)") % roundi(1.0 / chance) if chance > 0.0 else ""
	return ""


func _fill_hunt(column: VBoxContainer, rank: int, rules: BestiaryRules) -> void:
	var kills := Profile.kill_count(_monster.id)
	column.add_child(_heading(tr("Hunter rank")))
	column.add_child(UiSkin.label(tr("Slay more of this kind to rank up. Each rank pays its souls once."), 14, UiSkin.DIM, true))
	var thresholds := rules.kills_for(_monster)
	var souls := rules.souls_for(_monster)
	for i in thresholds.size():
		var reward := CodexRows.souls(souls[i]) if i < souls.size() else ""
		var extra := ""
		if i == thresholds.size() - 1:
			extra = tr("and +%d%% damage to this kind, for good") % roundi(rules.mastery_damage * 100.0)
		column.add_child(_goal_row(rank > i, tr("%s: slay %d") % [tr(rules.rank_names[i]), thresholds[i]], reward, extra))
	var next := Bestiary.next_kills(_monster, rules)
	if next > 0:
		column.add_child(CodexRows.bar(kills, next, tr("%d / %d slain, to %s") % [kills, next, Bestiary.rank_name(maxi(rank, 0) + 1, rules)]))
	else:
		column.add_child(CodexRows.bar(1, 1, tr("Mastered!")))

	var challenges := rules.challenges_for(_monster)
	if not challenges.is_empty():
		column.add_child(_heading(tr("Challenges")))
		column.add_child(UiSkin.label(tr("Slay it in a special way. Each one pays its souls once."), 14, UiSkin.DIM, true))
		for challenge in challenges:
			column.add_child(_goal_row(Profile.is_challenge_done(_monster.id, challenge.id), challenge.describe(_monster), CodexRows.souls(challenge.souls)))



## A goal with its mark: done or not, what to do, the souls it pays (and what else).
func _goal_row(done: bool, text: String, reward: String, extra := "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(CodexRows.check(done, false))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	words.add_child(UiSkin.label(text, 16, CodexRows.DONE if done else UiSkin.TEXT, true))
	if not extra.is_empty():
		words.add_child(UiSkin.label(extra, 14, CodexRows.SOUL, true))
	if not reward.is_empty():
		var amount := UiSkin.label(reward, 15, CodexRows.SOUL)
		amount.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(amount)
	return row


func _heading(text: String) -> Label:
	var label := UiSkin.label(text, 19, UiSkin.GOLD)
	label.custom_minimum_size.y = 28
	return label
