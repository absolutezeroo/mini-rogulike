class_name QuestBoard
## The quests of the day and of the week: drawn from the date, so every player gets the same
## ones and they change at midnight (UTC) and on Monday. Progress comes from what the hero did
## during that day or week (Profile.period_stat); a finished quest pays its souls once.

const DAILY_COUNT := 3
const WEEKLY_COUNT := 3
const DAY := 86400


## Days since 1970-01-01 (UTC).
static func day_index(now: int = -1) -> int:
	return floori(float(now if now >= 0 else int(Time.get_unix_time_from_system())) / DAY)


## Weeks starting on Monday (1970-01-01 was a Thursday).
static func week_index(now: int = -1) -> int:
	return floori(float(day_index(now) + 3) / 7.0)


static func period_key(period: QuestDef.Period, now: int = -1) -> String:
	return "d%d" % day_index(now) if period == QuestDef.Period.DAILY else "w%d" % week_index(now)


## Seconds until this period's quests change.
static func seconds_left(period: QuestDef.Period, now: int = -1) -> int:
	var time := now if now >= 0 else int(Time.get_unix_time_from_system())
	if period == QuestDef.Period.DAILY:
		return (day_index(time) + 1) * DAY - time
	var next_monday := (week_index(time) + 1) * 7 - 3
	return next_monday * DAY - time


## The current quests of `period`: [{def, target, reward, key}], the same for everyone.
static func current(quests: Array[QuestDef], period: QuestDef.Period, now: int = -1) -> Array[Dictionary]:
	var key := period_key(period, now)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key + "quests")
	var pool := quests.filter(func(q: QuestDef) -> bool: return q and q.period == period)
	var picked: Array[Dictionary] = []
	var count := DAILY_COUNT if period == QuestDef.Period.DAILY else WEEKLY_COUNT
	while picked.size() < count and not pool.is_empty():
		var weights := PackedFloat32Array()
		for q: QuestDef in pool:
			weights.append(maxi(q.spawn_weight, 1))
		var index := rng.rand_weighted(weights)
		var def: QuestDef = pool[index]
		pool.remove_at(index)
		var target := rng.randi_range(def.target.x, def.target.y)
		target = maxi(def.step, roundi(float(target) / def.step) * def.step) if def.step > 1 else target
		var span := maxf(def.target.y - def.target.x, 1.0)
		var reward := roundi(lerpf(def.reward.x, def.reward.y, clampf((target - def.target.x) / span, 0.0, 1.0)))
		picked.append({def = def, target = target, reward = reward, key = key})
	return picked


static func progress(quest: Dictionary) -> int:
	var def: QuestDef = quest.def
	return mini(Profile.period_stat(quest.key, def.stat), quest.target)


static func is_done(quest: Dictionary) -> bool:
	return progress(quest) >= int(quest.target)


static func is_claimed(quest: Dictionary) -> bool:
	return Profile.is_quest_claimed(quest.key, (quest.def as QuestDef).id)


static func text(quest: Dictionary) -> String:
	return TranslationServer.tr((quest.def as QuestDef).goal_text) % int(quest.target)


## Pays every finished quest of today and this week not paid yet. Returns them.
static func claim_finished(quests: Array[QuestDef]) -> Array[Dictionary]:
	var paid: Array[Dictionary] = []
	for period in [QuestDef.Period.DAILY, QuestDef.Period.WEEKLY]:
		for quest in current(quests, period):
			if is_done(quest) and Profile.claim_quest(quest.key, (quest.def as QuestDef).id, quest.reward):
				paid.append(quest)
	return paid


## Pays every finished quest not paid yet and tells it (Events.quest_completed: the HUD's toast,
## the records). The one way gameplay pays quests: during a run (RunRecords) and when the title
## screen comes up (a quest finished in a run that ended before it was paid: a crash, an old
## save). Screens only read quests; drawing a list never pays.
static func pay_finished(quests: Array[QuestDef]) -> Array[Dictionary]:
	var paid := claim_finished(quests)
	for quest in paid:
		Events.quest_completed.emit(quest)
	return paid


## "5h 12m", "2d 4h".
static func time_text(seconds: int) -> String:
	if seconds >= DAY:
		return TranslationServer.tr("%dd %dh") % [int(seconds / float(DAY)), int((seconds % DAY) / 3600.0)]
	return TranslationServer.tr("%dh %02dm") % [int(seconds / 3600.0), int((seconds % 3600) / 60.0)]
