class_name PrivacyTests
extends TestSuite
## The player's privacy choices (Privacy), the gameplay statistics (Telemetry, RunTelemetry) and
## the credits, on a fake server (FakeBoardBackend): never the network, a fake clock.
## run_unit(): the rules (off by default, the age question, a refusal kept six months, a consent
## for an older version, nothing queued or sent without consent or from a debug run, what a run
## sends and its sizes, delete my online data, the file), the data (policy, statistics, credits
## and their licence files). run_title(): the questions on the title screen, the Options' Privacy
## section, the policy and the credits pages. game_summary(): what a real run's end sends (the
## game suite).

const DAY := 86400
const T0 := 1_800_000_000

var _fake: FakeBoardBackend


func run_unit() -> void:
	_test_data()
	_test_credits_data()
	_test_rules()
	await _test_no_consent_sends_nothing()
	await _test_consented_run()
	await _test_left_and_resumed()
	await _test_left_without_consent()
	_test_draft()
	await _test_delete()
	_test_file()
	_restore()


func run_title() -> void:
	await _test_title_questions()
	await _test_options()
	await _test_credits_page()
	_restore()


## A fake server, the statistics accepted by a player old enough (the game suite plays a run on it).
func consent_on_fake() -> FakeBoardBackend:
	_fake = FakeBoardBackend.new()
	Leaderboards.use_for_tests(_fake)
	Privacy.use_for_tests()
	Telemetry.use_for_tests()
	Privacy.answer_age(true)
	Privacy.grant()
	return _fake


## Back to the tests' usual: an offline server, no file, no choice, nothing queued.
func _restore() -> void:
	Leaderboards.use_for_tests()
	Privacy.use_for_tests()
	Telemetry.use_for_tests()
	_fake = null


func _use_fake() -> FakeBoardBackend:
	_fake = FakeBoardBackend.new()
	Leaderboards.use_for_tests(_fake)
	Privacy.use_for_tests()
	Telemetry.use_for_tests()
	return _fake


func _test_data() -> void:
	var def := Privacy.def
	check(def != null and def.sections.size() >= 8, "the policy's data loads with its sections (data/online/privacy.tres)")
	for section in def.sections:
		check(not section.title.is_empty() and not section.text.is_empty(), "a policy section has a heading and a text (%s)" % section.title)
	var all := ""
	for section in def.sections:
		all += section.text
	for code in ["{controller}", "{email}", "{months}", "{age}", "{version}"]:
		check(all.contains(code), "the in-game policy says %s" % code)
	check(def.age_threshold == 16 and def.reask_days >= 180 and def.event_retention_days == 395 and def.player_purge_days == 730, "16 years, six months before asking again, 13 months of events, 24 months of players")
	# The placeholders live in one data file; the web page carries the same ones until filled.
	var page := FileAccess.get_file_as_string("res://docs/privacy.html")
	check(not page.is_empty(), "docs/privacy.html exists")
	for field in ["controller_name", "contact_email"]:
		var value := str(def.get(field))
		check(PrivacyDef.is_placeholder(value) == page.contains(value), "the policy page and the game agree on %s (%s)" % [field, value])
	for word in ["CNIL", "Talo", "Hetzner", "Sentry", "13", "730", "16"]:
		check(page.contains(word), "the policy page names %s" % word)
	check(page.contains("lang=\"fr\"") and page.contains("id=\"en\""), "the policy page is in French and English")
	# The statistics' catalog.
	var config := Telemetry.config
	check(config != null and config.event(&"run_end") != null and config.event(&"boss") != null, "the statistics' catalog loads (data/online/telemetry.tres)")
	var names := {}
	for event in config.events:
		check(not event.fields.is_empty() and not names.has(event.name), "%s has its fields and its own name" % event.name)
		names[event.name] = true
		for field in event.fields:
			check(field.length() <= TelemetryDef.MAX_KEY_LENGTH and not field.begins_with("META_"), "%s.%s is a key Talo takes (and never a META_ prop: Talo copies those into the public player props)" % [event.name, field])
	for event_name in [&"perk_offered", &"perk_picked", &"perk_banished", &"purchase", &"pact"]:
		check(config.event(event_name) != null, "the choices are counted: %s" % event_name)


func _test_credits_data() -> void:
	var credits := load(CreditsPanel.DEFS) as CreditsDef
	check(credits != null and credits.entries().size() >= 6, "the credits load (data/credits/credits.tres)")
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	var filters := PackedStringArray()
	for section in presets.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			filters.append(str(presets.get_value(section, "include_filter", "")))
	var engine := false
	for entry in credits.entries():
		check(not entry.work.is_empty() and not entry.makers.is_empty(), "a credit names a work and its makers (%s)" % entry.work)
		engine = engine or entry.engine_notice
		if entry.license_file.is_empty():
			continue
		check(FileAccess.file_exists(entry.license_file) and not CreditsPanel.license_text(entry).is_empty(), "%s's licence file exists: %s" % [entry.work, entry.license_file])
		var file := entry.license_file.trim_prefix("res://")
		for filter in filters:
			var packed := false
			for pattern in filter.split(",", false):
				packed = packed or file.matchn(pattern.strip_edges())
			check(packed, "%s is packed into every build" % file)
	check(engine and CreditsPanel.engine_notice().contains("Godot Engine") and CreditsPanel.engine_notice().contains("MIT"), "Godot's licence and notices come from the engine")
	check(credits.entries().any(func(e: CreditEntryDef) -> bool: return e.work == "Ninja Adventure" and e.license.begins_with("CC0")), "the art pack is credited")
	var fonts := DirAccess.get_files_at("res://assets/fonts")
	for font in fonts:
		if font.ends_with(".ttf") or font.ends_with(".otf"):
			check(credits.entries().any(func(e: CreditEntryDef) -> bool: return e.description.to_lower().contains("font")), "the font %s is credited" % font)


func _test_rules() -> void:
	_use_fake()
	check(not Privacy.analytics_allowed() and Privacy.analytics == Privacy.Answer.NONE, "the statistics are off by default")
	check(Privacy.should_ask() and Privacy.needs_age(), "with a server, the questions are asked, the age first")
	Leaderboards.use_for_tests()
	check(not Privacy.should_ask(), "without a server, nothing is asked")
	_use_fake()
	Privacy.fake_now = T0
	# Too young: off, never offered, a grant does nothing.
	Privacy.answer_age(false)
	Privacy.grant()
	check(not Privacy.analytics_allowed() and not Privacy.should_ask(), "under 16: the statistics stay off and are never offered")
	Privacy.fake_now = T0 + 400 * DAY
	check(not Privacy.should_ask(), "...even a year later")
	# Old enough, refused: kept six months.
	Privacy.use_for_tests()
	Privacy.fake_now = T0
	Privacy.answer_age(true)
	Privacy.refuse()
	check(not Privacy.analytics_allowed() and not Privacy.should_ask(), "a refusal is kept")
	Privacy.fake_now = T0 + (Privacy.def.reask_days - 1) * DAY
	check(not Privacy.should_ask(), "...and not asked again before six months")
	Privacy.fake_now = T0 + (Privacy.def.reask_days + 1) * DAY
	check(Privacy.should_ask() and not Privacy.needs_age(), "...asked again after six months (the age is known)")
	Privacy.grant()
	check(Privacy.analytics_allowed() and not Privacy.should_ask(), "accepted: on, not asked again")
	check(Privacy.history.size() == 2 and Privacy.history[-1].choice == "granted" and Privacy.history[-1].policy == Privacy.def.policy_version, "each answer is logged with its time and versions (to show consent was asked)")
	# A new consent version (new purposes, new processor): asked again, off until then.
	var version := Privacy.def.consent_version
	Privacy.def.consent_version = version + 1
	check(not Privacy.analytics_allowed() and Privacy.should_ask(), "a consent for an older version no longer counts")
	Privacy.def.consent_version = version
	Privacy.answer_age(false)
	check(not Privacy.analytics_allowed(), "a later 'under 16' turns them off")
	Privacy.fake_now = -1


## A run that ends without consent, refused, or as a debug run: nothing queued, nothing sent,
## the server never called.
func _test_no_consent_sends_nothing() -> void:
	var fake := _use_fake()
	var played := _play_run(true)
	await _frames(2)
	check(Telemetry.queue.is_empty() and fake.events.is_empty() and fake.calls == 0, "no consent: nothing queued, nothing sent, no call (%d calls)" % fake.calls)
	_end_run(played)
	Privacy.answer_age(true)
	Privacy.refuse()
	played = _play_run(true)
	await _frames(2)
	check(Telemetry.queue.is_empty() and fake.calls == 0, "refused: nothing either")
	_end_run(played)
	Privacy.grant()
	played = _play_run(false)
	DebugCheats.debug_run = true
	played.records.report_end()
	DebugCheats.debug_run = false
	await _frames(2)
	check(Telemetry.queue.is_empty() and fake.events.is_empty(), "a debug run sends nothing, even with consent")
	_end_run(played)
	Telemetry.use_for_tests()


## With consent: the run's events are queued (bounded, sanitized) and sent once, under the device's
## player; offline they wait; refusing drops what waited.
func _test_consented_run() -> void:
	var fake := consent_on_fake()
	fake.online = false
	var played := _play_run(true)
	await _frames(2)
	var summary := Telemetry.last_summary
	check(not Telemetry.queue.is_empty() and fake.events.is_empty(), "consent, no network: the run's events wait (%d)" % Telemetry.queue.size())
	for key in ["v", "run", "diff", "asc", "daily", "depth", "result", "time", "kills", "skills", "weapon", "rolls", "dodged", "dodge_rate", "hits_taken", "dmg_out", "dmg_in", "potions", "floor_times", "gold_earned", "gold_spent", "souls", "input", "os"]:
		check(summary.has(key), "the run's end says %s" % key)
	check(summary.get("diff") == "normal" and summary.get("depth") == "3" and summary.get("result") == "death", "...its difficulty, depth and how it ended (%s)" % [summary])
	check(summary.get("rolls") == "2" and summary.get("dodged") == "1" and summary.get("hits_taken") == "1" and summary.get("dodge_rate") == "0.50", "...the rolls, the hit dodged by one, the hit taken, the dodge rate")
	check(int(summary.get("dmg_in", "0")) > 0 and summary.has("dmg_in.plain") and summary.has("src_in.monster"), "...the damage taken by element and source")
	check(summary.has("potion.health_potion") and summary.has("potion_health"), "...the potions drunk, and the Health they were drunk at")
	check(Telemetry.queue.any(func(e: Dictionary) -> bool: return e.name == "perk_picked" and e.props.get("perk") == "vampirism"), "a perk taken during the run is an event of its own")
	check(not Leaderboards.shown and Leaderboards.queue.is_empty(), "the statistics don't publish any score")
	# Every event within Talo's limits.
	for event: Dictionary in Telemetry.queue:
		for key: String in event.props:
			check(key.length() <= TelemetryDef.MAX_KEY_LENGTH and str(event.props[key]).length() <= TelemetryDef.MAX_VALUE_LENGTH, "%s.%s fits Talo's limits" % [event.name, key])
		check((event.props as Dictionary).size() <= Telemetry.config.max_props, "%s has at most %d props" % [event.name, Telemetry.config.max_props])
	var huge := { "run": "x", "perks": ",".join(PackedStringArray(range(400).map(func(i: int) -> String: return "perk_%d" % i))), "x".repeat(200): "1", "META_OS": "Android", "secret": "1" }
	var clean := Telemetry.config.sanitize(Telemetry.config.event(&"perk_offered"), huge)
	check(str(clean.get("perks", "")).length() <= TelemetryDef.MAX_VALUE_LENGTH and str(clean.perks).ends_with(str(clean.perks).get_slice(",", str(clean.perks).count(","))) and not clean.has("META_OS") and not clean.has("secret") and clean.size() == 2, "a long list is cut at a comma, unknown, too long and META_ keys are dropped (%s)" % [clean.keys()])
	# The queue is bounded.
	var limit := Telemetry.config.max_queue
	for i in limit + 10:
		Telemetry._enqueue({ "name": &"pact", "props": { "pact": "p%d" % i }, "timestamp": 1 })
	check(Telemetry.queue.size() == limit, "the queue never holds more than %d events" % limit)
	Telemetry.queue.clear()
	Telemetry._enqueue({ "name": &"run_end", "props": summary, "timestamp": 1 })
	Telemetry._enqueue({ "name": &"boss", "props": { "boss": "golem" }, "timestamp": 2 })
	# Back online: sent once, in batches, under the device's player.
	fake.online = true
	await Telemetry.flush()
	check(Telemetry.queue.is_empty() and fake.events.size() == 2 and fake.events[0].name == "run_end", "back online, the events are sent once (%d)" % fake.events.size())
	check(not Leaderboards.device_id.is_empty() and fake.alias_id() > 0, "...under this device's random id")
	await Telemetry.flush()
	check(fake.events.size() == 2, "nothing is sent twice")
	# Withdrawn: what waits is dropped, nothing more goes.
	Telemetry._enqueue({ "name": &"boss", "props": { "boss": "golem" }, "timestamp": 3 })
	Privacy.refuse()
	check(Telemetry.queue.is_empty(), "withdrawing drops what waited")
	await Telemetry.flush()
	check(fake.events.size() == 2, "...and nothing more is sent")
	_end_run(played)


func _test_delete() -> void:
	var fake := consent_on_fake()
	Leaderboards.set_shown(true)
	Leaderboards.set_pseudonym("Kagari")
	await Leaderboards.identity()
	var id := Leaderboards.device_id
	check(not id.is_empty() and not Leaderboards.player_id.is_empty(), "identified: a device id and its server player")
	Telemetry._enqueue({ "name": &"boss", "props": { "boss": "golem" }, "timestamp": 3 })
	var request := Privacy.deletion_request()
	check(request.id == id and request.player == Leaderboards.player_id and request.name == "Kagari" and str(request.body).contains(id), "the deletion request names the online id, the server's player and the pseudonym")
	check(str(request.mailto).is_empty() == PrivacyDef.is_placeholder(Privacy.def.contact_email), "no email can be sent to a placeholder address")
	Privacy.forget_online()
	check(Leaderboards.device_id.is_empty() and Leaderboards.player_id.is_empty() and Leaderboards.pseudonym.is_empty() and not Leaderboards.shown, "deleted: the id, the player and the name forgotten, the leaderboards off")
	check(Telemetry.queue.is_empty() and not Privacy.analytics_allowed(), "...the statistics off and nothing waiting")
	check(not Leaderboards.needs_name(), "...and not asked again at once (the player's answer)")
	var calls := fake.calls
	Telemetry._enqueue({ "name": &"boss", "props": { "boss": "golem" }, "timestamp": 4 })
	await Telemetry.flush()
	await Leaderboards.flush()
	check(fake.calls == calls, "after a deletion nothing reaches the server")


## The choices survive a restart in their own file, which holds no age.
func _test_file() -> void:
	_use_fake()
	var file := "user://test_privacy_%d.json" % OS.get_process_id()
	Privacy.path = file
	Privacy.answer_age(true)
	Privacy.grant()
	Privacy.load_state()
	check(Privacy.analytics_allowed() and Privacy.old_enough and Privacy.history.size() == 1, "the choices survive a restart")
	var text := FileAccess.get_file_as_string(file)
	check(not text.contains("\"age\"") and not text.contains("birth") and text.contains("\"old_enough\": true"), "only 'old enough' is kept, never an age")
	check(file != RunSave.path and file != Profile.save_path, "its own file, not the run's save nor the profile")
	Privacy.path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	# A leaderboards file of version 1 ("shown" on by default): asked again.
	var old := "user://test_old_boards_%d.json" % OS.get_process_id()
	SafeFile.write_json(old, { "version": 1, "device_id": "abc", "name": "Old", "name_chosen": true, "shown": true, "queue": [{ "board": "daily_challenge", "period": "1", "score": 1, "props": {} }] })
	Leaderboards.path = old
	Leaderboards.load_state()
	check(not Leaderboards.shown and Leaderboards.needs_name() and Leaderboards.queue.is_empty(), "an older leaderboards file: publishing off until asked again, its queue dropped")
	Leaderboards.path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old))


## A run left for the title, then resumed from its save and ended: the quit sends one run_end
## "abandoned" (quit 1) with what was counted; the save keeps the counts, the resumed run's end
## covers both parts under the same run id (resumed 1), and nothing is sent twice.
func _test_left_and_resumed() -> void:
	var fake := consent_on_fake()
	fake.online = false
	var played := _play_run(false, false)
	var run_id := Telemetry.tracker.run_id
	# Save and quit (Game: _save_run(), then report_left(true)).
	Events.run_saving.emit(played.run)
	var saved := JSON.parse_string(JSON.stringify((played.run as RunState).to_data())) as Dictionary
	(played.records as RunRecords).report_left(true)
	var ends := _queued("run_end")
	check(ends.size() == 1, "quitting to the title queues one run_end (%d)" % ends.size())
	var left: Dictionary = ends[0].props if not ends.is_empty() else {}
	check(left.get("result") == "abandoned" and left.get("quit") == "1" and left.get("run") == run_id, "...result abandoned, quit 1, the run's id (%s)" % [left])
	check(left.get("rolls") == "2" and left.get("hits_taken") == "1" and left.has("potion.health_potion") and left.has("weapon") and left.has("floor_times") and left.get("depth") == "3", "...with the run's stats and build so far")
	check(_queued("perk_picked").size() == 1, "...and the events of the run so far")
	check(Telemetry.tracker == null, "the run left is no longer followed")
	_end_run(played)
	# Resumed from the save: the counts come back, the run goes on, then ends.
	var resumed := _start_run(saved)
	check(Telemetry.tracker.run_id == run_id and Telemetry.tracker.resumes == 1 and not Telemetry.tracker.partial, "a resumed run keeps its id and its counts")
	var player := resumed.player as Player
	player.skill_used.emit(RunTelemetry.ROLL_SLOT)
	var taken := HitInfo.new()
	taken.amount = 4
	Events.actor_damaged.emit(player, taken, 4)
	(resumed.run as RunState).time = 300.0
	player.is_dead = true
	player.death_cause = &"monster"
	(resumed.records as RunRecords).report_end()
	ends = _queued("run_end")
	check(ends.size() == 2, "the resumed run's end is a second run_end (%d)" % ends.size())
	var end: Dictionary = ends[-1].props if ends.size() == 2 else {}
	check(end.get("run") == run_id and end.get("result") == "death" and end.get("quit") == "0" and end.get("resumed") == "1" and end.get("partial") == "0", "...same run id, a death, resumed once (%s)" % [end])
	check(end.get("rolls") == "3" and end.get("hits_taken") == "2" and end.get("dmg_in") == "11" and end.has("potion.health_potion"), "...its counts cover the whole run: 2 + 1 rolls, 1 + 1 hits, 7 + 4 damage taken")
	check(_queued("perk_picked").size() == 1, "...and the events before the quit are not sent again")
	check(end.get("floor_times") == "60.0,70.0,170.0", "...the time per floor of the whole run (%s)" % end.get("floor_times"))
	_end_run(resumed)
	# A save from before the counts were kept: resumed, partial.
	saved.erase("telemetry")
	var old := _start_run(saved)
	check(Telemetry.tracker.resumes == 1 and Telemetry.tracker.partial and Telemetry.tracker.run_id != run_id, "an older save without counts: resumed, partial, a new id")
	_end_run(old)
	_restore()


## Without consent, or a debug run: quitting queues nothing either.
func _test_left_without_consent() -> void:
	var fake := _use_fake()
	var played := _play_run(false, false)
	(played.records as RunRecords).report_left(true)
	await _frames(1)
	check(Telemetry.queue.is_empty() and Telemetry.draft.is_empty() and fake.calls == 0, "no consent: a quit queues nothing")
	_end_run(played)
	consent_on_fake()
	played = _play_run(false, false)
	DebugCheats.debug_run = true
	(played.records as RunRecords).report_left(false)
	(played.records as RunRecords).report_left(true)
	DebugCheats.debug_run = false
	check(Telemetry.queue.is_empty() and Telemetry.draft.is_empty(), "a debug run's quit queues nothing, even with consent")
	_end_run(played)
	_restore()


## The app put in the background mid-run: the run's end waits as a draft (nothing queued),
## dropped when the app comes back; killed there, it is queued at the next launch (the file).
func _test_draft() -> void:
	var fake := consent_on_fake()
	fake.online = false
	var played := _play_run(false, false)
	(played.records as RunRecords).report_left(false)
	var drafted := Telemetry.draft.filter(func(e: Dictionary) -> bool: return e.name == "run_end")
	check(Telemetry.queue.is_empty() and drafted.size() == 1 and drafted[0].props.get("result") == "abandoned", "put in the background: an abandoned end drafted, nothing queued")
	check(Telemetry.tracker != null and Telemetry.tracker.pending.size() > 0, "...the run still followed, its events still waiting for its end")
	Telemetry._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(Telemetry.draft.is_empty() and Telemetry.queue.is_empty(), "back in the app: the draft dropped")
	var file := "user://test_telemetry_%d.json" % OS.get_process_id()
	Telemetry.path = file
	(played.records as RunRecords).report_left(false)
	Telemetry.load_state()  # (the next launch: the app was killed in the background)
	check(Telemetry.draft.is_empty() and Telemetry.queue.filter(func(e: Dictionary) -> bool: return e.name == "run_end" and e.props.get("quit") == "1").size() == 1, "killed in the background: the abandoned end is queued at the next launch")
	check(file != RunSave.path and file != Privacy.path, "...from the statistics' own file")
	Telemetry.path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	_end_run(played)
	_restore()


## The queued events named `event_name`.
func _queued(event_name: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in Telemetry.queue:
		if event.name == event_name:
			found.append(event)
	return found


## A run from `saved` (empty: a new one) on a hero out of the world, as the Game begins it: its
## records bound, Events.run_started.
func _start_run(saved: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var run := RunState.create(CONTENT, saved, rng)
	run.difficulty = CONTENT.get_difficulty(&"normal")
	var player := (load("res://src/entities/player/player.tscn") as PackedScene).instantiate() as Player
	player.process_mode = Node.PROCESS_MODE_DISABLED  # (no floor under it)
	add_child(player)
	player.setup(CONTENT.player)
	var records := RunRecords.new()
	records.content = CONTENT
	add_child(records)
	records.bind(run, player)
	Events.run_started.emit(run, player)
	return { "run": run, "player": player, "records": records }


## A run on a hero out of the world, followed from Events.run_started: two rolls, a hit dodged in
## one, a hit taken, a potion drunk, a perk taken, on floor 3 at 200 s; death there (`dies`).
## `ends`: Events.run_ended.
func _play_run(ends: bool, dies := true) -> Dictionary:
	var started := _start_run({})
	var run := started.run as RunState
	var player := started.player as Player
	var records := started.records as RunRecords
	player.skill_used.emit(RunTelemetry.ROLL_SLOT)
	player.skill_used.emit(RunTelemetry.ROLL_SLOT)
	var dodged := HitInfo.new()
	dodged.amount = 5
	Events.hit_dodged.emit(player, dodged)
	var taken := HitInfo.new()
	taken.amount = 7
	Events.actor_damaged.emit(player, taken, 7)
	var potion := load("res://data/items/consumables/health_potion.tres") as ConsumableDef
	if potion:
		player.healed.emit(10, StringName("item:%s" % potion.id))
		player.consumable_used.emit(potion)
	var perk := _perk("vampirism")
	if perk:
		player.perks.add(perk)
		Events.perk_chosen.emit(perk)
	run.depth = 3
	run.time = 200.0
	run.splits.assign([60.0, 130.0])
	player.is_dead = dies
	player.death_cause = &"monster" if dies else &""
	if ends:
		records.report_end()
	return { "run": run, "player": player, "records": records }


func _end_run(played: Dictionary) -> void:
	if Telemetry.tracker:
		Telemetry.tracker.unbind()
		Telemetry.tracker = null
	(played.records as Node).queue_free()
	(played.player as Node).queue_free()


# --- Title -------------------------------------------------------------------------

func _test_title_questions() -> void:
	_use_fake()
	Privacy.ask_on_title = true
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(2)
	title.ask_privacy()
	await _frames(2)
	var dialog := title.consent
	check(dialog.visible and dialog.step == ConsentDialog.Step.AGE, "the first time, the title asks the age first")
	check(_fake.calls == 0, "nothing reaches the server while asking (%d calls)" % _fake.calls)
	var under := dialog.get_node("%AgeUnder") as Button
	var over := dialog.get_node("%AgeOver") as Button
	check(under.size.is_equal_approx(over.size), "the two age answers are the same size")
	under.pressed.emit()
	await _frames(2)
	check(not dialog.visible and not Privacy.analytics_allowed() and not Privacy.should_ask(), "under 16: closed, no consent question, off")
	# Old enough: the consent question, plain, both answers equal, Accept not focused first.
	Privacy.use_for_tests()
	Privacy.ask_on_title = true
	title.ask_privacy()
	await _frames(2)
	(dialog.get_node("%AgeOver") as Button).pressed.emit()
	await _frames(2)
	check(dialog.visible and dialog.step == ConsentDialog.Step.CONSENT, "16 or older: the consent question")
	var accept := dialog.get_node("%AcceptButton") as Button
	var decline := dialog.get_node("%DeclineButton") as Button
	check(accept.size.is_equal_approx(decline.size) and accept.get_theme_stylebox("normal") == decline.get_theme_stylebox("normal"), "Accept and Decline: the same size and look")
	check(dialog.get_meta(MenuNav.FIRST, null) == dialog.get_node("%PolicyButton"), "keys and gamepads start on the policy, not on Accept")
	var screen := get_viewport().get_visible_rect()
	check(screen.encloses(dialog.board_rect()), "the question fits the screen (%s)" % dialog.board_rect())
	check(_off_grid_texts(dialog).is_empty(), "its texts are on the font's grid: %s" % [_off_grid_texts(dialog)])
	(dialog.get_node("%PolicyButton") as Button).pressed.emit()
	await _frames(2)
	check(dialog.policy.visible, "the policy can be read from the question")
	check(title.back() and not dialog.policy.visible and dialog.visible, "Back closes the policy first")
	check(title.back() and not dialog.visible and Privacy.analytics == Privacy.Answer.REFUSED, "closing the question declines")
	Privacy.use_for_tests()
	Privacy.answer_age(true)
	title.ask_privacy()
	await _frames(2)
	check(dialog.step == ConsentDialog.Step.CONSENT, "the age known: straight to the consent")
	(dialog.get_node("%AcceptButton") as Button).pressed.emit()
	await _frames(2)
	check(not dialog.visible and Privacy.analytics_allowed(), "Accept: the statistics are on")
	Privacy.ask_on_title = false
	title.queue_free()
	await _frames(2)


func _test_options() -> void:
	var fake := _use_fake()
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(2)
	var options: OptionsPanel = title.get_node("%OptionsPanel")
	options.open()
	await _frames(2)
	var analytics := options.get_node("%AnalyticsCheck") as CheckButton
	var boards := options.get_node("%BoardsShowCheck") as CheckButton
	check(not analytics.button_pressed and not boards.button_pressed, "Options > Privacy: both switches off by default")
	check((options.get_node("%OnlineIdText") as Label).text == tr("None yet (nothing was sent)"), "no online id before anything is on")
	analytics.button_pressed = true
	await _frames(2)
	var consent := options.get_node("%ConsentDialog") as ConsentDialog
	check(consent.visible and not analytics.button_pressed, "turning the statistics on asks first (the switch waits for the answer)")
	(consent.get_node("%AgeOver") as Button).pressed.emit()
	await _frames(1)
	(consent.get_node("%AcceptButton") as Button).pressed.emit()
	await _frames(2)
	check(analytics.button_pressed and Privacy.analytics_allowed(), "accepted: the switch is on")
	analytics.button_pressed = false
	check(not Privacy.analytics_allowed() and Privacy.analytics == Privacy.Answer.REFUSED, "off: withdrawn at once")
	boards.button_pressed = true
	await _frames(2)
	check(options.get_node("%NameDialog").visible and not Leaderboards.shown, "publishing never chosen: the switch asks the question first")
	(options.get_node("%NameDialog").get_node("%ConfirmButton") as Button).pressed.emit()
	await _frames(2)
	options.open()
	check(Leaderboards.shown and boards.button_pressed, "published from the Options")
	boards.button_pressed = false
	check(not Leaderboards.shown, "the switch turns publishing off")
	await Leaderboards.identity()
	options.open()
	check((options.get_node("%OnlineIdText") as Label).text == Leaderboards.device_id, "the online id is shown (for a deletion request)")
	# Delete my online data.
	DeleteDataDialog.opens_email = false
	(options.get_node("%DeleteDataButton") as Button).pressed.emit()
	await _frames(2)
	var delete := options.get_node("%DeleteDialog") as DeleteDataDialog
	check(delete.visible, "Delete my online data asks first")
	var id := Leaderboards.device_id
	(delete.get_node("%ConfirmButton") as Button).pressed.emit()
	await _frames(2)
	check(Leaderboards.device_id.is_empty() and (delete.get_node("%DoneText") as Label).text.contains(id), "deleted: the id forgotten, and shown to write with")
	options.close()
	check(not delete.visible and options.visible, "Back closes the dialog first")
	check(not analytics.button_pressed and not boards.button_pressed, "...and everything online is off")
	DeleteDataDialog.opens_email = true
	# The policy and the credits from the Options.
	(options.get_node("%PolicyButton") as Button).pressed.emit()
	await _frames(2)
	var policy := options.get_node("%PolicyPanel") as PrivacyPolicyPanel
	check(policy.visible and policy.content.get_child_count() >= Privacy.def.sections.size() * 2, "the policy opens, every section shown")
	check(_off_grid_texts(policy).is_empty(), "the policy's texts are on the font's grid")
	options.close()
	check(not policy.visible and options.visible, "Back closes the policy first")
	(options.get_node("%CreditsButton") as Button).pressed.emit()
	await _frames(2)
	check((options.get_node("%CreditsPanel") as Control).visible, "the credits open from the Options")
	options.close()
	options.close()
	check(not options.visible, "then the Options")
	check(fake.calls > 0, "(the server was called once the player chose)")
	title.queue_free()
	await _frames(2)
	# No server in the build: no switches, the policy and the credits still there.
	Leaderboards.use_for_tests()
	title = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(2)
	options = title.get_node("%OptionsPanel")
	options.open()
	await _frames(1)
	check(not options.has_node("%AnalyticsCheck") and options.has_node("%PolicyButton") and options.has_node("%CreditsButton"), "no server: no online switches, the policy and the credits remain")
	options.close()
	title.queue_free()
	await _frames(2)


func _test_credits_page() -> void:
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(2)
	var button := title.get_node("%CreditsButton") as Button
	check(button.is_visible_in_tree(), "the title screen has a Credits button")
	button.pressed.emit()
	await _frames(2)
	var page := title.credits
	check(page.visible and page.content.get_child_count() >= page.credits.sections.size(), "it opens the credits, every section")
	var shown := ""
	for label: Label in page.find_children("*", "Label", true, false):
		shown += label.text + "\n"
	for entry in page.credits.entries():
		check(shown.contains(entry.work), "the credits show %s" % entry.work)
	check(_off_grid_texts(page).is_empty(), "the credits' texts are on the font's grid")
	var license := page.get_node("%License_1") as Button
	license.pressed.emit()
	await _frames(2)
	check(page.license_page.visible and page.license_page.content.get_child_count() == 1, "a licence opens over the credits")
	check(title.back() and not page.license_page.visible and page.visible, "Back closes the licence first")
	check(title.back() and not page.visible, "then the credits")
	title.queue_free()
	await _frames(2)


# --- Game ----------------------------------------------------------------------------

## A real run's end (the game suite, after the bot played and died): its summary holds every field
## the catalog lists that a dead hero has.
func game_summary(player: Player) -> void:
	var summary := Telemetry.last_summary
	check(not summary.is_empty() and (_fake == null or _fake.events.any(func(e: Dictionary) -> bool: return e.name == "run_end")), "a real run's end is sent with consent (%d events)" % (_fake.events.size() if _fake else -1))
	var optional := ["weapon", "weapon_rarity", "weapon_element", "weapon_runes", "weapon_affixes", "potion_health"]
	for field in Telemetry.config.event(&"run_end").fields:
		if field.ends_with("*") or (optional.has(field) and player.get_weapon() == null):
			continue
		check(summary.has(field) or (field == "potion_health" and summary.get("potions", "0") == "0"), "a real run's end says %s" % field)
	check(summary.keys().any(func(k: String) -> bool: return k.begins_with("skill.")), "...each skill's uses or damage")
	check(summary.keys().any(func(k: String) -> bool: return k.begins_with("dmg_out.")) and summary.keys().any(func(k: String) -> bool: return k.begins_with("src_out.")), "...the damage dealt by element and source")
	check(int(summary.get("dmg_out", "0")) > 0 and int(summary.get("potions", "0")) > 0, "...damage was dealt and potions drunk (%s, %s)" % [summary.get("dmg_out"), summary.get("potions")])
	for key: String in summary:
		check(key.length() <= TelemetryDef.MAX_KEY_LENGTH and str(summary[key]).length() <= TelemetryDef.MAX_VALUE_LENGTH, "run_end.%s fits Talo's limits" % key)
	_restore()
