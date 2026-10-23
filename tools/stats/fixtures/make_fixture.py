#!/usr/bin/env python3
"""Makes a synthetic Talo data export of the gameplay statistics, to test and show the dashboard.

The events follow data/online/telemetry.tres and RunTelemetry.summary() (the same props, as
strings, the same lists "a,b,c" and "perk:level"), and the file follows Talo's export
(talo_export.py): a ZIP holding events-1.csv, its columns `props.<key>` for every key seen, and
each cell filled the way Talo fills it (the first prop whose key the column name ends with), so
the reader meets the real quirks. Players are invented, numbers are drawn from a fixed seed with
a few patterns built in for the page to show (a weapon stronger than the rest, a boss that blocks,
potions kept until death by weaker players, dodging that pays, resumed and abandoned runs, events
sent twice).

Usage (python3, standard library only):
  python3 tools/stats/fixtures/make_fixture.py out.zip [--runs 600] [--seed 7] [--dev-out dev.zip]
`--dev-out` also writes an export "with dev data on": the same events plus a dev player's runs.
"""

from __future__ import annotations

import argparse
import csv
import io
import math
import random
import zipfile
from datetime import datetime, timedelta, timezone

WEAPONS = {  # id: (weight of being held at the end, strength)
	"katana": (14, 0.0), "big_sword": (8, 0.45), "bow": (9, 0.15), "magic_wand": (7, 0.2),
	"axe": (6, 0.0), "hammer": (6, 0.05), "lance": (5, -0.05), "rapier": (5, 0.0), "sai": (4, -0.1),
	"shuriken": (4, 0.1), "whip": (4, -0.35), "book": (4, 0.1), "ninjaku": (4, 0.0),
	"templar_sword": (3, 0.15), "pickaxe": (2, -0.3), "stick": (2, -0.7),
}
ELEMENTS = ["", "", "fire", "storm", "water", "poison", "holy", "arcane", "earth"]
HEADS = ["leather_cap", "iron_helm", "shadow_cloak", ""]
BODIES = ["leather_armor", "chain_mail", "plate_armor", ""]
SKILLS = ["arcane_bolt", "arrow_rain", "battle_cry", "blink", "cleave", "dash_strike", "fire_wave",
	"fireball", "fissure", "flurry", "frost_nova", "ground_slam", "holy_light", "holy_shield",
	"ice_shards", "kunai_fan", "lash", "piercing_thrust", "riposte", "rock_spike", "shadow_step",
	"shuriken_storm", "smite", "spark_nova", "spear_throw", "sundering_blow", "thunder", "volley",
	"whirlwind"]
STRONG_SKILLS = {"fireball": 0.25, "whirlwind": 0.2, "holy_shield": 0.15, "lash": -0.25, "riposte": -0.15}
PERKS = ["arcane_focus", "arcane_power", "blazing_roll", "bloodrage", "cold_snap", "devotion", "echo",
	"fortune", "frenzy", "frostbite", "ice_shards", "ignite", "iron_skin", "kindling", "precision",
	"shock_roll", "strength", "swiftness", "thorns", "thunderclap", "vampirism", "vitality"]
LIKED_PERKS = {"vampirism": 3.0, "strength": 2.0, "frenzy": 2.0, "fortune": 0.4, "thorns": 0.5}
RELICS = ["executioner", "guardian_ring", "multishot", "phoenix_feather", "sages_codex", "war_banner"]
SETS = ["arcane", "blood", "frost", "inferno", "storm"]
RUNES = ["rime_rune", "echo_rune", "fury_rune", "pyre_rune", "gale_rune", "ember_rune", "prism_rune",
	"leech_rune", "spark_rune", "shatter_rune"]
OATHS = ["", "", "", "colossus", "duelist", "plunderer", "scholar"]
PACTS = ["fast", "knell", "tithe", "untouched"]
BOSSES = {3: ["king_slime", "giant_frog"], 6: ["weeping_spirit", "gilded_hoarder", "crimson_tengu"],
	9: ["red_samurai", "sun_wraith", "demon_cyclops"], 12: ["master_toma"]}
BOSS_HARDNESS = {"sun_wraith": 1.1, "crimson_tengu": 0.5, "master_toma": 0.6, "giant_frog": -0.2}
MONSTERS = {1: ["rat", "bat", "slime", "spider", "mushroom", "snake", "big_slime", "shell_guard"],
	2: ["skeleton", "skull", "spirit", "soul_moth", "bone_lizard", "lantern", "shaman"],
	3: ["flam", "ash_lizard", "ember_heart", "bomber", "red_viper", "sorcerer", "cyclops"],
	4: ["sand_drake", "dune_rex", "sand_drummer", "gold_racoon", "reptile", "dragon"]}
ITEMS = ["health_potion", "greater_health_potion", "bomb", "fire_scroll", "haste_draught", "rage_elixir"]
DIFFICULTY = {"easy": (0.25, 1.0), "normal": (0.55, 0.0), "hard": (0.15, -0.9), "nightmare": (0.05, -1.6)}
SCREENS = ["2400x1080", "2340x1080", "1920x1080", "2560x1440", "1600x720", "2712x1220"]
START = datetime(2026, 9, 20, tzinfo=timezone.utc)


def sigmoid(x: float) -> float:
	return 1 / (1 + math.exp(-x))


class Gen:
	"""One synthetic history of players and their runs, from a seed."""

	def __init__(self, seed: int):
		self.rng = random.Random(seed)
		self.events: list[dict] = []
		self.next_event = 1

	def event(self, name: str, props: dict, when: datetime, player: dict, version: str) -> dict:
		props = dict(props, v=version)
		# Sorted, as TelemetryDef.sanitize() sends them (Talo's export fills a cell from the first
		# prop that matches, so the order matters: `kills` comes before `skills`).
		props = {k: str(props[k]) for k in sorted(props)}
		item = {"name": name, "props": props, "time": when, "player": player}
		self.events.append(item)
		return item

	def players(self, count: int, prefix: str = "") -> list[dict]:
		result = []
		for i in range(count):
			result.append({
				"player_id": f"{prefix}{1000 + i:x}-{self.rng.getrandbits(32):08x}",
				"alias_id": 5000 + i if not prefix else 9000 + i,
				"identifier": f"{self.rng.getrandbits(64):016x}",
				"skill": self.rng.gauss(0, 1),
				"device": self.rng.choices(["touch", "keyboard", "gamepad"], [0.7, 0.2, 0.1])[0],
				"os": "Android" if self.rng.random() < 0.75 else "Windows",
				"screen": self.rng.choice(SCREENS),
			})
		for p in result:
			if p["os"] == "Windows" and p["device"] == "touch":
				p["device"] = "keyboard"
		return result

	def run(self, player: dict, when: datetime, version: str) -> datetime:
		rng = self.rng
		run_id = f"{rng.getrandbits(48):012x}"
		diff = rng.choices(list(DIFFICULTY), [d[0] for d in DIFFICULTY.values()])[0]
		asc = rng.randint(0, 5) if diff == "nightmare" else 0
		weapon = rng.choices(list(WEAPONS), [w[0] for w in WEAPONS.values()])[0]
		skills = rng.sample(SKILLS, rng.choice([1, 2, 2, 3]))
		head, body = rng.choice(HEADS), rng.choice(BODIES)
		power = player["skill"] * 0.9 + DIFFICULTY[diff][1] - 0.25 * asc + WEAPONS[weapon][1]
		power += sum(STRONG_SKILLS.get(s, 0) for s in skills) + (0.15 if body == "plate_armor" else 0)
		if version == "0.3.0":
			power += 0.15  # the newer version is a little kinder
		oath = rng.choice(OATHS)
		daily = rng.random() < 0.12
		perks: dict[str, int] = {}
		relics: list[str] = []
		t = when
		depth = 1
		dead = False
		quit_at = rng.randint(1, 11) if rng.random() < 0.12 else 0
		counts = {"potions": 0, "potions_boss": 0, "rolls": 0, "dodged": 0, "hits_taken": 0, "dmg_out": 0, "dmg_in": 0,
			"crits": 0, "charged": 0, "secrets": 0, "trap_hits": 0, "deeps": 0, "deeps_escaped": 0, "threshold": 0,
			"threshold_won": 0, "gold_earned": 0, "gold_spent": 0, "dismantled": 0, "dropped": 0, "biggest_hit": 0, "kills": 0}
		ratios: list[float] = []
		potion_use: dict[str, int] = {}
		belt = {"health_potion": 2}
		floor_times: list[float] = []
		bosses = 0
		killer = cause = ""
		dodge_skill = sigmoid(player["skill"] * 1.2 - 0.3) * 0.55
		left_events: list[dict] = []
		quit_now = False

		def pend(name: str, props: dict) -> None:
			props = dict(props, run=run_id, depth=depth)
			left_events.append((name, props))

		while True:
			seconds = max(25.0, rng.gauss(95, 30) + depth * 4)
			floor_times.append(round(seconds, 1))
			t += timedelta(seconds=seconds)
			act = (depth - 1) // 3 + 1
			kills = rng.randint(8, 20)
			counts["kills"] += kills
			rolls = int(seconds / 60 * rng.uniform(4, 14) * (1 + max(player["skill"], -0.5)))
			counts["rolls"] += rolls
			hits = max(1, int(rng.gauss(14, 4) * (1.3 - dodge_skill) * (1 + 0.15 * act)))
			dodged = int(hits * dodge_skill / (1 - dodge_skill))
			counts["hits_taken"] += hits
			counts["dodged"] += dodged
			counts["dmg_in"] += hits * rng.randint(4, 9) * act
			counts["dmg_out"] += kills * rng.randint(40, 90) * act
			counts["crits"] += rng.randint(2, 20)
			counts["charged"] += rng.randint(0, 6)
			counts["gold_earned"] += rng.randint(25, 70) * act
			counts["trap_hits"] += rng.randint(0, 2)
			counts["biggest_hit"] = max(counts["biggest_hit"], rng.randint(30, 80) * act)
			counts["secrets"] += 1 if rng.random() < 0.15 else 0
			if rng.random() < 0.05:
				counts["deeps"] += 1
				counts["deeps_escaped"] += 1 if rng.random() < 0.6 else 0
			if rng.random() < 0.6:
				belt["health_potion"] = belt.get("health_potion", 0) + 1
			if rng.random() < 0.15:
				item = rng.choice(ITEMS[1:])
				belt[item] = belt.get(item, 0) + 1
			# A level up: a choice of three perks (sometimes rerolled), one taken.
			for _ in range(rng.choice([1, 1, 2])):
				offer = rng.sample(PERKS, 3)
				pend("perk_offered", {"perks": ",".join(offer)})
				if rng.random() < 0.1:
					offer = rng.sample(PERKS, 3)
					pend("perk_offered", {"perks": ",".join(offer)})
				if rng.random() < 0.05:
					pend("perk_banished", {"perk": offer[0]})
					offer = offer[1:]
				pick = max(offer, key=lambda p: LIKED_PERKS.get(p, 1.0) * rng.random())
				perks[pick] = perks.get(pick, 0) + 1
				pend("perk_picked", {"perk": pick, "stacks": perks[pick]})
			if rng.random() < 0.35:
				item = rng.choice(["health_potion", "greater_health_potion", "rune", "katana", "chain_mail", "iron_helm"])
				price = {"health_potion": 40, "greater_health_potion": 90, "rune": 120}.get(item, 150) * act
				if counts["gold_earned"] - counts["gold_spent"] >= price:
					counts["gold_spent"] += price
					pend("purchase", {"item": item, "rarity": rng.choice([0, 0, 1, 2]) if item in ("katana", "chain_mail", "iron_helm") else 0, "price": price})
			if rng.random() < 0.08:
				pend("pact", {"pact": rng.choice(PACTS), "outcome": "kept" if rng.random() < sigmoid(power) else "broken"})
			# Drinking: weaker players wait too long, or forget.
			wants = rng.random() < 0.7 + 0.1 * player["skill"]
			for item in ("health_potion", "greater_health_potion"):
				while belt.get(item, 0) > 0 and wants and rng.random() < 0.55:
					belt[item] -= 1
					counts["potions"] += 1
					potion_use[item] = potion_use.get(item, 0) + 1
					ratios.append(min(0.95, max(0.03, rng.gauss(0.35 - 0.08 * player["skill"], 0.12))))
			boss_floor = depth in BOSSES
			danger = 2.6 + power - 0.18 * depth - (0.5 if boss_floor else 0) + 0.2 * len(perks) / 4
			if boss_floor:
				boss = rng.choice(BOSSES[depth])
				danger -= BOSS_HARDNESS.get(boss, 0)
				fight = max(20.0, rng.gauss(70, 20))
				won = rng.random() < sigmoid(danger + 0.6)
				boss_potions = min(belt.get("health_potion", 0), rng.randint(0, 2))
				belt["health_potion"] = belt.get("health_potion", 0) - boss_potions
				counts["potions"] += boss_potions
				counts["potions_boss"] += boss_potions
				potion_use["health_potion"] = potion_use.get("health_potion", 0) + boss_potions
				ratios.extend([min(0.9, max(0.05, rng.gauss(0.3, 0.1)))] * boss_potions)
				if boss == "master_toma" and won:
					pend("boss", {"boss": boss, "time": f"{fight:.1f}", "dmg_in": rng.randint(40, 160), "hits_taken": rng.randint(3, 12), "phase": 2, "outcome": "next_form", "potions": boss_potions})
					boss = "the_maw"
					won = rng.random() < sigmoid(danger + 0.2)
				pend("boss", {"boss": boss, "time": f"{fight:.1f}", "dmg_in": rng.randint(40, 200) * (1 if won else 2),
					"hits_taken": rng.randint(3, 15), "phase": rng.randint(1, 3) if not won else 3,
					"outcome": "won" if won else "died", "potions": boss_potions})
				if won:
					bosses += 1
					offer = rng.sample(RELICS, 3)
					pend("perk_offered", {"perks": ",".join(offer)})
					relic = max(offer, key=lambda r: (2.5 if r == "phoenix_feather" else 1) * rng.random())
					relics.append(relic)
					pend("perk_picked", {"perk": relic, "stacks": 1})
				else:
					dead, killer, cause = True, boss, "monster"
			elif rng.random() > sigmoid(danger + 1.6):
				dead = True
				cause = rng.choices(["monster", "fall", "trap", "blast"], [0.8, 0.1, 0.06, 0.04])[0]
				killer = rng.choice(MONSTERS[min(act, 4)]) if cause in ("monster", "blast") else ""
			if dead or depth >= 12:
				break
			if quit_at and depth == quit_at:
				quit_now = True
				break
			depth += 1

		won_run = not dead and not quit_now
		props = {
			"run": run_id, "resumed": 0, "partial": 0, "quit": 1 if quit_now else 0, "os": player["os"],
			"screen": player["screen"], "input": player["device"],
			"inputs": player["device"] if rng.random() < 0.9 else ",".join(sorted({player["device"], "keyboard"})),
			"diff": diff, "asc": asc, "daily": 1 if daily else 0, "official": 1 if daily and rng.random() < 0.7 else 0,
			"oath": oath, "depth": depth, "result": "abandoned" if quit_now else ("death" if dead else "victory"),
			"time": f"{sum(floor_times):.1f}", "kills": counts["kills"], "bosses": bosses,
			"souls": bosses * 20 + depth * 3 + (50 if won_run else 0), "level": 1 + depth + rng.randint(0, 3),
			"weapon": weapon, "weapon_rarity": min(3, int(rng.random() * (1 + depth / 4))),
			"weapon_element": rng.choice(ELEMENTS), "weapon_runes": ",".join(rng.sample(RUNES, rng.randint(0, 2))),
			"weapon_affixes": "", "head": head, "body": body,
			"armor_runes": ",".join(rng.sample(RUNES, rng.randint(0, 1))),
			"sets": ",".join(s for s in SETS if rng.random() < 0.04 * len(perks) / 3),
			"relics": ",".join(relics), "perks": ",".join(f"{p}:{n}" for p, n in perks.items()),
			"skills": ",".join(["dash"] + skills),
		}
		if dead:
			props.update({"cause": cause, "killer": killer, "death_floor": depth})
		for key, value in counts.items():
			props[key] = value
		taken, dodged = counts["hits_taken"], counts["dodged"]
		props["dodge_rate"] = f"{dodged / (dodged + taken):.2f}" if dodged + taken else "0"
		if ratios:
			props["potion_health"] = f"{sum(ratios) / len(ratios):.2f}"
		props["floor_times"] = ",".join(f"{x:.1f}" for x in floor_times)
		for item, n in potion_use.items():
			props[f"potion.{item}"] = n
		for item, n in belt.items():
			if n > 0:
				props[f"left.{item}"] = n
		total_skill = 0
		for skill in skills:
			uses = int(sum(floor_times) / 60 * rng.uniform(1, 4))
			dmg = min(uses * rng.randint(20, 60) * (1 + depth // 3), int(counts["dmg_out"] * 0.6 / len(skills)))
			total_skill += dmg
			props[f"skill.{skill}.uses"] = uses
			props[f"skill.{skill}.dmg"] = dmg
		element = props["weapon_element"] or "plain"
		out = counts["dmg_out"]
		props[f"dmg_out.{element}"] = int(out * 0.7)
		props["dmg_out.fire" if element != "fire" else "dmg_out.plain"] = out - int(out * 0.7)
		props["src_out.weapon"] = out - total_skill
		props["src_out.skill"] = total_skill
		dmg_in = counts["dmg_in"]
		props["dmg_in.plain"] = int(dmg_in * 0.6)
		props["dmg_in." + rng.choice(["fire", "poison", "storm"])] = dmg_in - int(dmg_in * 0.6)
		props["src_in.monster"] = int(dmg_in * 0.8)
		props["src_in.trap"] = dmg_in - int(dmg_in * 0.8)

		for name, extra in left_events:
			self.event(name, extra, t - timedelta(seconds=rng.randint(30, 600)), player, version)
		self.event("run_end", props, t, player, version)
		if quit_now and rng.random() < 0.6:
			# Resumed later: another end under the same run id, every count since the start.
			later = t + timedelta(hours=rng.randint(1, 30))
			final = dict(props, quit=0, resumed=1, depth=min(12, depth + rng.randint(0, 3)))
			final["time"] = f"{float(props['time']) + rng.uniform(60, 600):.1f}"
			if rng.random() < sigmoid(power):
				final["result"] = "victory" if final["depth"] == 12 else "death"
			else:
				final["result"] = "death"
			if final["result"] == "death":
				final.update({"cause": "monster", "killer": rng.choice(MONSTERS[min(4, (final["depth"] - 1) // 3 + 1)]), "death_floor": final["depth"]})
			final["kills"] = int(props["kills"]) + rng.randint(5, 40)
			self.event("run_end", final, later, player, version)
		return t


def generate(seed: int = 7, runs: int = 600, dev_runs: int = 0) -> tuple[list[dict], list[dict]]:
	"""(events, dev events) of a synthetic history: `runs` runs by about runs/4 players over five
	weeks, version 0.2.9 then 0.3.0; `dev_runs` runs of one dev player."""
	gen = Gen(seed)
	players = gen.players(max(4, runs // 4))
	weights = [math.exp(gen.rng.gauss(0, 1)) for _ in players]
	for i in range(runs):
		player = gen.rng.choices(players, weights)[0]
		when = START + timedelta(minutes=i * 85 + gen.rng.randint(0, 60))
		gen.run(player, when, "0.2.9" if i < runs * 0.4 else "0.3.0")
	events = gen.events
	# A few batches sent twice (an answer lost, the batch sent again): new rows, same events.
	for event in gen.rng.sample(events, max(1, len(events) // 60)):
		events.append(dict(event))
	gen.events = []
	dev_player = gen.players(1, prefix="dev")[0]
	for i in range(dev_runs):
		gen.run(dev_player, START + timedelta(days=3, minutes=i * 40), "0.3.0")
	return events, gen.events


def talo_cell(column: str, props: list[tuple[str, str]]) -> str:
	"""What Talo writes in `column` for an event's props (dataExportProcessor.transformColumn():
	the first prop whose key the column name ends with, RFC 4180 quoted by the csv writer)."""
	for key, value in props:
		if column.endswith(key):
			return value
	return ""


def write_export(events: list[dict], path: str) -> None:
	"""`events` as a Talo data export ZIP (events-1.csv)."""
	ordered = sorted(events, key=lambda e: e["time"])
	keys = sorted({k for e in ordered for k in e["props"]})
	columns = ["id", "name", "playerAlias.id", "playerAlias.service", "playerAlias.identifier",
		"playerAlias.player.id", "createdAt", "updatedAt"] + [f"props.{k}" for k in keys]
	text = io.StringIO()
	writer = csv.writer(text, lineterminator="\n")
	writer.writerow(columns)
	for index, event in enumerate(ordered):
		stamp = event["time"].strftime("%Y-%m-%dT%H:%M:%S.") + f"{event['time'].microsecond // 1000:03d}Z"
		player = event["player"]
		props = list(event["props"].items())
		writer.writerow([f"evt-{index:07d}", event["name"], player["alias_id"], "custom", player["identifier"],
			player["player_id"], stamp, stamp] + [talo_cell(c, props) for c in columns[8:]])
	with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
		archive.writestr("events-1.csv", text.getvalue())


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("out")
	parser.add_argument("--runs", type=int, default=600)
	parser.add_argument("--seed", type=int, default=7)
	parser.add_argument("--dev-out", help="also an export with dev data (the same plus a dev player's runs)")
	parser.add_argument("--dev-runs", type=int, default=20)
	args = parser.parse_args()
	events, dev = generate(args.seed, args.runs, args.dev_runs if args.dev_out else 0)
	write_export(events, args.out)
	print(f"{args.out}: {len(events)} events")
	if args.dev_out:
		write_export(events + dev, args.dev_out)
		print(f"{args.dev_out}: {len(events) + len(dev)} events ({len(dev)} dev)")


if __name__ == "__main__":
	main()
