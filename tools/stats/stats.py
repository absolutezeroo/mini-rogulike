"""Turns the gameplay statistics' events into runs and numbers (docs/online.md "Reading the statistics").

Runs: one per distinct `run` id, its **latest** `run_end` (highest timestamp) holding the whole
run's numbers (a run left then resumed sends one at each quit, each covering everything since its
start: never sum them). `result` victory = a win (even if the hero later left the endless floors,
`quit` 1); `quit` 1 otherwise = abandoned (never finished, or not yet), neither a win nor a loss.
Win rates are over finished runs (wins / (wins + deaths)).

Every rate comes with its sample size and a 95% Wilson interval; a row with fewer than
`min_sample` finished runs is marked "low" and never ranked above a row with enough. The build
is the one the run *ended* with: a run that went deep had time to gather more, so perks and
relics read better than they are (survivorship); compare rows, don't read them as causes.
"""

from __future__ import annotations

import math
import statistics
from collections import Counter, defaultdict

HEAL_ITEMS = ("health_potion", "greater_health_potion")
## The hero's roll: always in the first skill slot, not a pick.
ROLL_SKILL = "dash"


# --- Small helpers ---------------------------------------------------------------

def num(props: dict, key: str, default: float = 0.0) -> float:
	try:
		return float(props.get(key, default))
	except (TypeError, ValueError):
		return default


def ids(props: dict, key: str) -> list[str]:
	return [part for part in (props.get(key) or "").split(",") if part]


def wilson(successes: int, n: int, z: float = 1.96) -> tuple[float, float]:
	"""95% Wilson score interval of successes / n ((0, 1) when n is 0)."""
	if n <= 0:
		return 0.0, 1.0
	p = successes / n
	denominator = 1 + z * z / n
	centre = (p + z * z / (2 * n)) / denominator
	half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denominator
	return max(0.0, centre - half), min(1.0, centre + half)


def confidence(n: int, min_sample: int) -> str:
	"""How far a rate can be trusted: "low" (< min_sample), "medium" (< 3x), "good"."""
	if n < min_sample:
		return "low"
	return "medium" if n < 3 * min_sample else "good"


def mean(values) -> float | None:
	values = list(values)
	return round(sum(values) / len(values), 3) if values else None


def ratio(a: float, b: float) -> float | None:
	return round(a / b, 4) if b else None


# --- Runs ---------------------------------------------------------------------

def build_runs(events: list[dict]) -> list[dict]:
	"""One run per run id: its latest run_end, plus how many run_ends it sent. A run_end without a
	run id is a run of its own."""
	latest: dict[str, dict] = {}
	sent: Counter = Counter()
	for event in events:
		if event["name"] != "run_end":
			continue
		run_id = event["props"].get("run") or "event:" + event["id"]
		sent[run_id] += 1
		current = latest.get(run_id)
		if current is None or (event["time"], event["id"]) >= (current["time"], current["id"]):
			latest[run_id] = event
	return [make_run(run_id, event, sent[run_id]) for run_id, event in latest.items()]


def make_run(run_id: str, event: dict, ends_sent: int = 1) -> dict:
	"""A run's numbers, from its latest run_end."""
	p = event["props"]
	result = p.get("result", "death")
	quit_ = num(p, "quit") >= 1
	won = result == "victory"
	if won:
		status = "victory"
	elif quit_ or result == "abandoned":
		status = "abandoned"
	else:
		status = "death"
	key = "skill_ids" if "skill_ids" in p else "skills"  # (`skills`: older games, often a ghost)
	skills = ids(p, key)
	if skills and skills[0] == ROLL_SKILL:
		skills = skills[1:]
	if key not in p or any(part.isdigit() for part in skills):
		# Lost in Talo's export (talo_export._drop_ghosts()): the skills the run used instead.
		skills = sorted({k.split(".")[1] for k in p if k.startswith("skill.") and k.count(".") == 2} - {ROLL_SKILL})
	perks = {}
	for entry in ids(p, "perks"):
		name, _, level = entry.partition(":")
		perks[name] = int(level) if level.isdigit() else 1
	return {
		"id": run_id,
		"player": event["player"],
		"time_end": event["time"],
		"dev": bool(event.get("dev")),
		"ends_sent": ends_sent,
		"v": p.get("v", "?"),
		"status": status,
		"finished": status != "abandoned",
		"won": won,
		"diff": p.get("diff", "?") or "?",
		"asc": int(num(p, "asc")),
		"daily": num(p, "daily") >= 1,
		"official": num(p, "official") >= 1,
		"oath": p.get("oath", ""),
		"resumed": int(num(p, "resumed")),
		"partial": num(p, "partial") >= 1,
		"depth": int(num(p, "depth")),
		"cause": p.get("cause", ""),
		"killer": p.get("killer", ""),
		"death_floor": int(num(p, "death_floor", num(p, "depth"))),
		"seconds": num(p, "time"),
		"level": int(num(p, "level")),
		"weapon": p.get("weapon", ""),
		"weapon_rarity": int(num(p, "weapon_rarity")),
		"weapon_element": p.get("weapon_element", ""),
		"runes": ids(p, "weapon_runes") + ids(p, "armor_runes"),
		"head": p.get("head", ""),
		"body": p.get("body", ""),
		"sets": ids(p, "sets"),
		"relics": ids(p, "relics"),
		"perks": perks,
		"skills": skills,
		"skill_uses": {k[6:-5]: num(p, k) for k in p if k.startswith("skill.") and k.endswith(".uses")},
		"skill_dmg": {k[6:-4]: num(p, k) for k in p if k.startswith("skill.") and k.endswith(".dmg")},
		"potions": num(p, "potions"),
		"potions_boss": num(p, "potions_boss"),
		"potion_health": num(p, "potion_health", -1.0) if "potion_health" in p else None,
		"potion": {k[7:]: num(p, k) for k in p if k.startswith("potion.")},
		"left": {k[5:]: num(p, k) for k in p if k.startswith("left.")},
		"rolls": num(p, "rolls"),
		"dodged": num(p, "dodged"),
		"dodge_rate": num(p, "dodge_rate"),
		"hits_taken": num(p, "hits_taken"),
		"dmg_out": num(p, "dmg_out"),
		"dmg_in": num(p, "dmg_in"),
		"dmg_out_el": {k[8:]: num(p, k) for k in p if k.startswith("dmg_out.")},
		"dmg_in_el": {k[7:]: num(p, k) for k in p if k.startswith("dmg_in.")},
		"src_out": {k[8:]: num(p, k) for k in p if k.startswith("src_out.")},
		"src_in": {k[7:]: num(p, k) for k in p if k.startswith("src_in.")},
		"biggest_hit": num(p, "biggest_hit"),
		"crits": num(p, "crits"),
		"charged": num(p, "charged"),
		"floor_times": [float(x) for x in ids(p, "floor_times") if _is_number(x)],
		"secrets": num(p, "secrets"),
		"trap_hits": num(p, "trap_hits"),
		"deeps": num(p, "deeps"),
		"deeps_escaped": num(p, "deeps_escaped"),
		"threshold": num(p, "threshold"),
		"threshold_won": num(p, "threshold_won"),
		"gold_earned": num(p, "gold_earned"),
		"gold_spent": num(p, "gold_spent"),
		"souls": num(p, "souls"),
		"dismantled": num(p, "dismantled"),
		"dropped": num(p, "dropped"),
		"os": p.get("os", ""),
		"screen": p.get("screen", ""),
		"input": p.get("input", ""),
		"inputs": sorted(ids(p, "inputs")),
		"kills": num(p, "kills"),
		"bosses": num(p, "bosses"),
	}


def _is_number(text: str) -> bool:
	try:
		float(text)
		return True
	except ValueError:
		return False


def act_of(floor: int, floors: list[int]) -> int:
	"""The act (1..) of a depth; past the last act's floors: len(floors) + 1 (the endless floors)."""
	total = 0
	for index, count in enumerate(floors):
		total += count
		if floor <= total:
			return index + 1
	return len(floors) + 1


# --- Aggregation -----------------------------------------------------------------

def rate_row(key, runs: list[dict], baseline: float | None, min_sample: int, total: int) -> dict:
	"""Usage and outcome of a group of runs: count, share, win rate with its interval, depth."""
	finished = [r for r in runs if r["finished"]]
	wins = sum(1 for r in finished if r["won"])
	lo, hi = wilson(wins, len(finished))
	rate = ratio(wins, len(finished))
	return {
		"key": key,
		"runs": len(runs),
		"share": ratio(len(runs), total),
		"finished": len(finished),
		"wins": wins,
		"win_rate": rate,
		"lo": round(lo, 4),
		"hi": round(hi, 4),
		"delta": round(rate - baseline, 4) if rate is not None and baseline is not None else None,
		"avg_depth": mean(r["depth"] for r in runs),
		"conf": confidence(len(finished), min_sample),
	}


def ranked(rows: list[dict]) -> list[dict]:
	"""Rows with enough data first, by the low end of their win-rate interval, then by size."""
	order = {"good": 0, "medium": 0, "low": 1}
	return sorted(rows, key=lambda r: (order[r["conf"]], -(r["lo"] if r["finished"] else -1), -r["runs"]))


def group_rate(runs: list[dict], key_of, baseline, min_sample: int, total: int | None = None) -> list[dict]:
	"""rate_row() for each key `key_of(run)` gives (a list: the run counts under each)."""
	groups: dict = defaultdict(list)
	for run in runs:
		keys = key_of(run)
		if not isinstance(keys, (list, tuple, set)):
			keys = [keys]
		for key in set(k for k in keys if k not in ("", None)):
			groups[key].append(run)
	total = len(runs) if total is None else total
	return ranked([rate_row(key, members, baseline, min_sample, total) for key, members in groups.items()])


def counts(values, total: int | None = None, top: int | None = None) -> list[dict]:
	counter = Counter(v for v in values if v not in ("", None))
	total = total if total is not None else sum(counter.values())
	return [{"key": k, "n": n, "share": ratio(n, total)} for k, n in counter.most_common(top)]


def sums(dicts: list[dict], top: int | None = None) -> list[dict]:
	"""Totals of {key: amount} dicts, with each key's share."""
	total: Counter = Counter()
	for d in dicts:
		for k, v in d.items():
			total[k] += v
	grand = sum(total.values())
	return [{"key": k, "total": round(v), "share": ratio(v, grand)} for k, v in total.most_common(top)]


def aggregate(runs: list[dict], events: list[dict], floors: list[int], min_sample: int = 10,
		min_combo: int = 5) -> dict:
	"""Every number of the dashboard for these runs and the events of the same runs."""
	finished = [r for r in runs if r["finished"]]
	wins = [r for r in finished if r["won"]]
	deaths = [r for r in finished if not r["won"]]
	abandoned = [r for r in runs if not r["finished"]]
	baseline = ratio(len(wins), len(finished))
	lo, hi = wilson(len(wins), len(finished))
	run_ids = {r["id"] for r in runs}
	own = [e for e in events if e["name"] != "run_end" and e["props"].get("run") in run_ids]
	n = len(runs)

	result = {
		"overview": {
			"runs": n,
			"finished": len(finished),
			"wins": len(wins),
			"deaths": len(deaths),
			"abandoned": len(abandoned),
			"players": len({r["player"] for r in runs}),
			"win_rate": baseline,
			"lo": round(lo, 4),
			"hi": round(hi, 4),
			"avg_depth": mean(r["depth"] for r in runs),
			"median_depth": statistics.median([r["depth"] for r in runs]) if runs else None,
			"avg_minutes": mean(r["seconds"] / 60 for r in finished),
			"resumed_runs": sum(1 for r in runs if r["resumed"] > 0),
			"partial_runs": sum(1 for r in runs if r["partial"]),
			"daily_runs": sum(1 for r in runs if r["daily"]),
			"runs_per_player": ratio(n, len({r["player"] for r in runs})),
			"min_sample": min_sample,
			"min_combo": min_combo,
		},
	}
	result["by_difficulty"] = group_rate(runs, lambda r: r["diff"], baseline, min_sample)
	result["by_difficulty"].sort(key=lambda row: difficulty_order(row["key"]))
	result["by_ascension"] = sorted(
		group_rate(runs, lambda r: f'{r["diff"]}+{r["asc"]}', baseline, min_sample),
		key=lambda row: (difficulty_order(row["key"].split("+")[0]), int(row["key"].split("+")[1])))
	result["depth"] = _depth(runs, floors)
	result["acts"] = _acts(runs, floors)
	result["causes"] = counts((r["cause"] or "unknown" for r in deaths), len(deaths))
	result["killers"] = counts((r["killer"] for r in deaths if r["killer"]), len(deaths), 25)
	result["bosses"] = _bosses(own, deaths, min_sample)
	result["entities"] = _entities(runs, own, baseline, min_sample)
	result["combos"] = _combos(runs, baseline, min_combo)
	result["potions"] = _potions(runs, finished, deaths)
	result["defence"] = _defence(runs, finished, floors, baseline, min_sample)
	result["damage"] = _damage(runs)
	result["skills_use"] = _skill_use(runs)
	result["floor_times"] = _floor_times(runs)
	result["economy"] = _economy(runs, own)
	result["pacts"] = _pacts(own, min_sample)
	result["oaths"] = group_rate(runs, lambda r: r["oath"] or "none", baseline, min_sample)
	result["devices"] = {
		"input": counts((r["input"] for r in runs), n),
		"inputs": counts(("+".join(r["inputs"]) for r in runs), n),
		"input_rate": group_rate(runs, lambda r: r["input"], baseline, min_sample),
		"os": counts((r["os"] for r in runs), n),
		"screen": counts((r["screen"] for r in runs), n, 8),
	}
	result["extras"] = {
		"secrets": mean(r["secrets"] for r in runs),
		"trap_hits": mean(r["trap_hits"] for r in runs),
		"deeps_runs": ratio(sum(1 for r in runs if r["deeps"] > 0), n),
		"deeps_escaped": ratio(sum(r["deeps_escaped"] for r in runs), sum(r["deeps"] for r in runs)),
		"threshold_runs": ratio(sum(1 for r in runs if r["threshold"] > 0), n),
		"threshold_won": ratio(sum(r["threshold_won"] for r in runs), sum(r["threshold"] for r in runs)),
		"kills": mean(r["kills"] for r in runs),
		"level": mean(r["level"] for r in runs),
	}
	return result


def _depth(runs: list[dict], floors: list[int]) -> list[dict]:
	"""For each depth: runs that reached it, runs that ended there by result, and the share of the
	finished runs reaching it that died there (where the Well stops people)."""
	top = max((r["depth"] for r in runs), default=0)
	rows = []
	for depth in range(1, top + 1):
		reached = [r for r in runs if r["depth"] >= depth]
		ended = [r for r in runs if r["depth"] == depth]
		died = sum(1 for r in ended if r["status"] == "death")
		finished_reached = sum(1 for r in reached if r["finished"])
		rows.append({
			"depth": depth,
			"act": act_of(depth, floors),
			"boss": depth <= sum(floors) and depth in _boss_floors(floors),
			"reached": len(reached),
			"ended": len(ended),
			"deaths": died,
			"wins": sum(1 for r in ended if r["won"]),
			"abandoned": sum(1 for r in ended if r["status"] == "abandoned"),
			"death_rate": ratio(died, finished_reached),
		})
	return rows


def _boss_floors(floors: list[int]) -> set[int]:
	total, result = 0, set()
	for count in floors:
		total += count
		result.add(total)
	return result


def _acts(runs: list[dict], floors: list[int]) -> list[dict]:
	rows = []
	start = 1
	for act in range(1, len(floors) + 2):
		reached = [r for r in runs if r["depth"] >= start and r["finished"]]
		died = [r for r in reached if r["status"] == "death" and act_of(r["death_floor"] or r["depth"], floors) == act]
		rows.append({
			"act": act,
			"reached": len(reached),
			"deaths": len(died),
			"death_rate": ratio(len(died), len(reached)),
			"killers": counts((r["killer"] for r in died if r["killer"]), len(died), 5),
		})
		if act <= len(floors):
			start += floors[act - 1]
	return [row for row in rows if row["reached"]]


def _bosses(events: list[dict], deaths: list[dict], min_sample: int) -> list[dict]:
	fights: dict[str, list[dict]] = defaultdict(list)
	for event in events:
		if event["name"] == "boss" and event["props"].get("boss"):
			fights[event["props"]["boss"]].append(event["props"])
	killed_by = Counter(r["killer"] for r in deaths)
	rows = []
	for boss, props in fights.items():
		outcome = Counter(p.get("outcome", "") for p in props)
		# A form beaten (next_form: the boss rises again as another) is a fight won.
		won, died = outcome["won"] + outcome["next_form"], outcome["died"]
		lo, hi = wilson(won, won + died)
		won_props = [p for p in props if p.get("outcome") in ("won", "next_form")]
		died_props = [p for p in props if p.get("outcome") == "died"]
		rows.append({
			"key": boss,
			"fights": won + died + outcome["left"],
			"won": won,
			"died": died,
			"left": outcome["left"],
			"next_form": outcome["next_form"],
			"win_rate": ratio(won, won + died),
			"lo": round(lo, 4),
			"hi": round(hi, 4),
			"conf": confidence(won + died, min_sample),
			"avg_time_won": mean(num(p, "time") for p in won_props),
			"avg_time": mean(num(p, "time") for p in props),
			"avg_dmg_in": mean(num(p, "dmg_in") for p in props),
			"avg_hits": mean(num(p, "hits_taken") for p in props),
			"avg_potions": mean(num(p, "potions") for p in props),
			"avg_phase_died": mean(num(p, "phase") for p in died_props),
			"phases_died": dict(sorted(Counter(str(int(num(p, "phase"))) for p in died_props).items())),
			"run_deaths": killed_by.get(boss, 0),
		})
	order = {"good": 0, "medium": 0, "low": 1}
	# The blocking ones first: enough fights, lowest win rate (its interval's high end).
	return sorted(rows, key=lambda r: (order[r["conf"]], r["hi"], -r["fights"]))


def _entities(runs: list[dict], events: list[dict], baseline, min_sample: int) -> dict:
	offered: Counter = Counter()
	picked: Counter = Counter()
	banished: Counter = Counter()
	for event in events:
		props = event["props"]
		if event["name"] == "perk_offered":
			for perk in set(ids(props, "perks")):
				offered[perk] += 1
		elif event["name"] == "perk_picked" and props.get("perk"):
			picked[props["perk"]] += 1
		elif event["name"] == "perk_banished" and props.get("perk"):
			banished[props["perk"]] += 1
	relic_ids = {relic for r in runs for relic in r["relics"]}

	def with_choices(rows: list[dict]) -> list[dict]:
		for row in rows:
			key = row["key"]
			row["offered"] = offered.get(key, 0)
			row["picked"] = picked.get(key, 0)
			row["banished"] = banished.get(key, 0)
			row["pick_rate"] = ratio(picked.get(key, 0), offered.get(key, 0))
		return rows

	perks = with_choices(group_rate(runs, lambda r: list(r["perks"]), baseline, min_sample))
	for row in perks:
		levels = [r["perks"][row["key"]] for r in runs if row["key"] in r["perks"]]
		row["avg_level"] = mean(levels)
	relics = with_choices(group_rate(runs, lambda r: r["relics"], baseline, min_sample))
	# Offered but never held at a run's end: still worth a row (a pick rate of 0 says something).
	for rows, pool in ((perks, lambda k: k not in relic_ids), (relics, lambda k: k in relic_ids)):
		present = {row["key"] for row in rows}
		for key in offered:
			if key not in present and pool(key):
				row = rate_row(key, [], baseline, min_sample, len(runs))
				rows.extend(with_choices([row]))
	return {
		"weapon": group_rate(runs, lambda r: r["weapon"], baseline, min_sample),
		"weapon_rarity": group_rate(runs, lambda r: str(r["weapon_rarity"]) if r["weapon"] else "", baseline, min_sample),
		"element": group_rate(runs, lambda r: r["weapon_element"] or "plain", baseline, min_sample),
		"head": group_rate(runs, lambda r: r["head"] or "none", baseline, min_sample),
		"body": group_rate(runs, lambda r: r["body"] or "none", baseline, min_sample),
		"armor": group_rate(runs, lambda r: f'{r["head"] or "none"}+{r["body"] or "none"}', baseline, min_sample),
		"skill": group_rate(runs, lambda r: r["skills"], baseline, min_sample),
		"perk": ranked(perks),
		"relic": ranked(relics),
		"set": group_rate(runs, lambda r: r["sets"], baseline, min_sample),
		"rune": group_rate(runs, lambda r: r["runes"], baseline, min_sample),
	}


def _combos(runs: list[dict], baseline, min_combo: int) -> dict:
	"""Build combinations, only those seen in at least `min_combo` finished runs."""
	def keep(rows: list[dict]) -> list[dict]:
		return ranked([row for row in rows if row["finished"] >= min_combo])[:40]

	return {
		"weapon_skills": keep(group_rate(runs, lambda r: (r["weapon"] + " | " + " + ".join(sorted(r["skills"]))) if r["weapon"] and r["skills"] else "", baseline, min_combo)),
		"weapon_skill": keep(group_rate(runs, lambda r: [f'{r["weapon"]} | {s}' for s in r["skills"]] if r["weapon"] else [], baseline, min_combo)),
		"weapon_armor": keep(group_rate(runs, lambda r: f'{r["weapon"]} | {r["head"] or "none"}+{r["body"] or "none"}' if r["weapon"] else "", baseline, min_combo)),
		"weapon_relic": keep(group_rate(runs, lambda r: [f'{r["weapon"]} | {x}' for x in r["relics"]] if r["weapon"] else [], baseline, min_combo)),
	}


def _potions(runs: list[dict], finished: list[dict], deaths: list[dict]) -> dict:
	ratios = [r["potion_health"] for r in runs if r["potion_health"] is not None and r["potion_health"] >= 0]
	hist = [0] * 10
	for value in ratios:
		hist[min(9, int(value * 10))] += 1
	items = sorted({k for r in runs for k in list(r["potion"]) + list(r["left"])})
	by_item = []
	for item in items:
		using = [r for r in runs if r["potion"].get(item, 0) > 0]
		by_item.append({
			"key": item,
			"per_run": mean(r["potion"].get(item, 0) for r in runs),
			"runs_using": ratio(len(using), len(runs)),
			"left_at_death": mean(r["left"].get(item, 0) for r in deaths),
			"deaths_with_left": ratio(sum(1 for r in deaths if r["left"].get(item, 0) > 0), len(deaths)),
		})
	by_item.sort(key=lambda row: -(row["per_run"] or 0))
	heal_left = [sum(r["left"].get(k, 0) for k in HEAL_ITEMS) for r in deaths]
	return {
		"avg_drunk": mean(r["potions"] for r in runs),
		"avg_drunk_per_floor": mean(r["potions"] / max(1, r["depth"]) for r in runs),
		"avg_boss": mean(r["potions_boss"] for r in runs),
		"avg_health_when_drunk": mean(ratios),
		"health_hist": hist,
		"drunk_by_result": {
			"victory": mean(r["potions"] for r in finished if r["won"]),
			"death": mean(r["potions"] for r in deaths),
		},
		"by_item": by_item,
		"deaths_with_heal_left": ratio(sum(1 for x in heal_left if x > 0), len(deaths)),
		"avg_heal_left_at_death": mean(heal_left),
		"never_drank": ratio(sum(1 for r in runs if r["potions"] == 0), len(runs)),
	}


def _defence(runs: list[dict], finished: list[dict], floors: list[int], baseline, min_sample: int) -> dict:
	def per_minute(r: dict, key: str) -> float:
		return r[key] / max(r["seconds"] / 60, 0.5)

	def summary(group: list[dict]) -> dict:
		return {
			"runs": len(group),
			"avg_rolls": mean(r["rolls"] for r in group),
			"rolls_per_min": mean(per_minute(r, "rolls") for r in group),
			"dodge_rate": mean(r["dodge_rate"] for r in group),
			"hits_per_min": mean(per_minute(r, "hits_taken") for r in group),
			"trap_hits": mean(r["trap_hits"] for r in group),
		}

	buckets = group_rate(finished, lambda r: f"{min(int(r['dodge_rate'] * 10), 9) / 10:.1f}", baseline, min_sample, len(finished))
	buckets.sort(key=lambda row: row["key"])
	by_act = []
	for act in range(1, len(floors) + 2):
		group = [r for r in runs if act_of(r["depth"], floors) == act]
		if group:
			row = summary(group)
			row["act"] = act
			by_act.append(row)
	return {
		"all": summary(runs),
		"victory": summary([r for r in finished if r["won"]]),
		"death": summary([r for r in finished if not r["won"]]),
		"dodge_buckets": buckets,
		"by_act_reached": by_act,
	}


def _damage(runs: list[dict]) -> dict:
	return {
		"out_element": sums([r["dmg_out_el"] for r in runs]),
		"in_element": sums([r["dmg_in_el"] for r in runs]),
		"out_source": sums([r["src_out"] for r in runs]),
		"in_source": sums([r["src_in"] for r in runs]),
		"avg_dmg_out": mean(r["dmg_out"] for r in runs),
		"avg_dmg_in": mean(r["dmg_in"] for r in runs),
		"avg_biggest_hit": mean(r["biggest_hit"] for r in runs),
		"avg_crits": mean(r["crits"] for r in runs),
		"avg_charged": mean(r["charged"] for r in runs),
	}


def _skill_use(runs: list[dict]) -> list[dict]:
	rows = []
	for skill in sorted({s for r in runs for s in r["skills"]}):
		having = [r for r in runs if skill in r["skills"]]
		uses = sum(r["skill_uses"].get(skill, 0) for r in having)
		damage = sum(r["skill_dmg"].get(skill, 0) for r in having)
		minutes = sum(r["seconds"] for r in having) / 60
		rows.append({
			"key": skill,
			"runs": len(having),
			"avg_uses": mean(r["skill_uses"].get(skill, 0) for r in having),
			"uses_per_min": ratio(uses, minutes),
			"avg_dmg": mean(r["skill_dmg"].get(skill, 0) for r in having),
			"dmg_per_use": ratio(damage, uses),
			"dmg_share": mean(r["skill_dmg"].get(skill, 0) / r["dmg_out"] for r in having if r["dmg_out"] > 0),
		})
	return sorted(rows, key=lambda row: -row["runs"])


def _floor_times(runs: list[dict]) -> list[dict]:
	by_floor: dict[int, list[float]] = defaultdict(list)
	for r in runs:
		for index, seconds in enumerate(r["floor_times"]):
			by_floor[index + 1].append(seconds)
	return [{"floor": f, "n": len(v), "avg": mean(v), "median": round(statistics.median(v), 1)}
		for f, v in sorted(by_floor.items())]


def _economy(runs: list[dict], events: list[dict]) -> dict:
	purchases = [e["props"] for e in events if e["name"] == "purchase"]
	by_item: dict[str, list[dict]] = defaultdict(list)
	for p in purchases:
		by_item[p.get("item", "?")].append(p)
	items = [{
		"key": item,
		"n": len(rows),
		"avg_price": mean(num(p, "price") for p in rows),
		"rarities": dict(Counter(p.get("rarity", "0") for p in rows)),
	} for item, rows in by_item.items()]
	items.sort(key=lambda row: -row["n"])
	earned = sum(r["gold_earned"] for r in runs)
	return {
		"avg_gold_earned": mean(r["gold_earned"] for r in runs),
		"avg_gold_spent": mean(r["gold_spent"] for r in runs),
		"spent_share": ratio(sum(r["gold_spent"] for r in runs), earned),
		"gold_per_floor": mean(r["gold_earned"] / max(1, r["depth"]) for r in runs),
		"purchases_per_run": ratio(len(purchases), len(runs)),
		"purchases": items[:30],
		"avg_souls": {
			"victory": mean(r["souls"] for r in runs if r["status"] == "victory"),
			"death": mean(r["souls"] for r in runs if r["status"] == "death"),
			"abandoned": mean(r["souls"] for r in runs if r["status"] == "abandoned"),
		},
		"avg_dismantled": mean(r["dismantled"] for r in runs),
		"avg_dropped": mean(r["dropped"] for r in runs),
	}


def _pacts(events: list[dict], min_sample: int) -> list[dict]:
	by_pact: dict[str, Counter] = defaultdict(Counter)
	for e in events:
		if e["name"] == "pact" and e["props"].get("pact"):
			by_pact[e["props"]["pact"]][e["props"].get("outcome", "")] += 1
	rows = []
	for pact, outcome in by_pact.items():
		total = outcome["kept"] + outcome["broken"]
		lo, hi = wilson(outcome["kept"], total)
		rows.append({"key": pact, "n": total, "kept": outcome["kept"], "kept_rate": ratio(outcome["kept"], total),
			"lo": round(lo, 4), "hi": round(hi, 4), "conf": confidence(total, min_sample)})
	return sorted(rows, key=lambda r: -r["n"])


# --- Views (the dashboard's filters) ------------------------------------------------

def view_key(version: str, difficulty: str, dev: bool) -> str:
	return f"{version}|{difficulty}|{1 if dev else 0}"


def build_views(events: list[dict], floors: list[int], include_dev: bool = False, since: float = 0.0,
		min_sample: int = 10, min_combo: int = 5, max_versions: int = 8) -> dict:
	"""Every filter combination the page offers (version x difficulty x dev data), each
	aggregated here so the page only shows numbers (one tested computation, in Python)."""
	events = [e for e in events if e["time"] >= since and (include_dev or not e.get("dev"))]
	runs = build_runs(events)
	versions = sorted({r["v"] for r in runs}, key=_version_order, reverse=True)[:max_versions]
	difficulties = sorted({r["diff"] for r in runs}, key=difficulty_order)
	views = {}
	for dev in ([False, True] if include_dev else [False]):
		for version in ["all"] + versions:
			for difficulty in ["all"] + difficulties:
				chosen = [r for r in runs if (dev or not r["dev"])
					and (version == "all" or r["v"] == version)
					and (difficulty == "all" or r["diff"] == difficulty)]
				if not chosen and (version != "all" or difficulty != "all"):
					continue
				views[view_key(version, difficulty, dev)] = aggregate(chosen, events, floors, min_sample, min_combo)
	return {
		"versions": versions,
		"difficulties": difficulties,
		"include_dev": include_dev,
		"dev_runs": sum(1 for r in runs if r["dev"]),
		"views": views,
	}


def difficulty_order(difficulty: str) -> tuple:
	"""Pilgrim, Keeper, Martyr, Nightmare, then any other id."""
	known = ["easy", "normal", "hard", "nightmare"]
	return (known.index(difficulty), "") if difficulty in known else (len(known), difficulty)


def _version_order(version: str) -> tuple:
	return tuple(int(part) if part.isdigit() else 0 for part in version.split("."))
