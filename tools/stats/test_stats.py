"""Tests of the statistics dashboard (python3 -m unittest, from tools/stats/ or with
`python3 -m unittest discover tools/stats` from the repo root). Standard library only."""

from __future__ import annotations

import contextlib
import io
import json
import os
import re
import sys
import tempfile
import unittest
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "fixtures"))

import build_dashboard  # noqa: E402
import make_fixture  # noqa: E402
import names  # noqa: E402
import stats  # noqa: E402
import talo_export  # noqa: E402

EDGE = os.path.join(HERE, "fixtures", "edge_events.csv")
FLOORS = [3, 3, 3, 3]


def run_end(run: str, time: float, player: str = "p", **props) -> dict:
	"""A run_end event as talo_export gives it."""
	base = {"run": run, "diff": "normal", "depth": "5", "result": "death", "quit": "0", "v": "0.3.0"}
	base.update({k: str(v) for k, v in props.items()})
	return {"id": f"{run}-{time}", "name": "run_end", "player": player, "alias": "", "time": time, "props": base, "dev": False}


class CatalogTests(unittest.TestCase):
	def test_catalog_is_read_from_the_game(self):
		catalog = talo_export.load_catalog()
		self.assertEqual(set(catalog), set(talo_export.DEFAULT_CATALOG), "the same events as the game's catalog")
		self.assertIn("skill.*", catalog["run_end"])
		self.assertEqual(catalog["boss"], talo_export.DEFAULT_CATALOG["boss"],
			"DEFAULT_CATALOG follows data/online/telemetry.tres (update it with the catalog)")
		self.assertEqual(catalog["run_end"], talo_export.DEFAULT_CATALOG["run_end"])

	def test_no_field_ends_another(self):
		# Talo's export fills props.<key> with the first prop whose key ends the column's name.
		for name, fields in talo_export.load_catalog().items():
			plain = [f for f in fields if not f.endswith("*")]
			for field in plain:
				for other in plain:
					self.assertFalse(other != field and other.endswith(field),
						f"{name}: {other} ends with {field} (Talo's export would mix them)")

	def test_old_skills_field_still_read(self):
		self.assertIn("skill_ids", talo_export.DEFAULT_CATALOG["run_end"])
		self.assertNotIn("skills", talo_export.DEFAULT_CATALOG["run_end"])
		self.assertIn("skills", talo_export.LEGACY_FIELDS["run_end"], "older exports' skills are read")

	def test_wildcards(self):
		fields = ["run", "skill.*"]
		self.assertTrue(talo_export.allows(fields, "skill.fireball.uses"))
		self.assertTrue(talo_export.allows(fields, "run"))
		self.assertFalse(talo_export.allows(fields, "skills"))
		self.assertFalse(talo_export.allows(fields, "runs"))


class ParsingTests(unittest.TestCase):
	def setUp(self):
		self.events = talo_export.read_events(EDGE)
		self.by_id = {e["id"]: e for e in self.events}

	def test_columns_quoting_and_times(self):
		self.assertEqual(len(self.events), 6)
		first = self.by_id["e1"]
		self.assertEqual(first["name"], "run_end")
		self.assertEqual(first["player"], "p-1")
		self.assertEqual(first["alias"], "aaaa")
		self.assertEqual(first["props"]["perks"], "strength:2,vitality:1", "a quoted cell keeps its commas")
		self.assertEqual(first["time"], datetime(2026, 10, 1, 10, tzinfo=timezone.utc).timestamp())
		self.assertEqual(self.by_id["e6"]["props"]["zeal"], 'say "hi", twice', "an unknown event keeps every prop")

	def test_other_events_ghosts_are_dropped(self):
		boss = self.by_id["e3"]["props"]
		self.assertEqual(boss["boss"], "king_slime")
		self.assertNotIn("potions_boss", boss, "Talo fills props.potions_boss with the boss: not a boss field")
		self.assertNotIn("weapon", boss)

	def test_same_event_ghosts_are_dropped(self):
		props = self.by_id["e1"]["props"]
		self.assertNotIn("skills", props, "props.skills showing kills is Talo's suffix match, not the skills")
		self.assertNotIn("src_out.weapon", props, "props.src_out.weapon showing the weapon id")
		self.assertEqual(props["kills"], "12")
		self.assertEqual(props["weapon"], "katana")
		self.assertEqual(self.by_id["e5"]["props"]["skills"], "dash,fireball", "a real skills cell is kept")
		self.assertEqual(self.by_id["e5"]["props"]["src_out.weapon"], "1500")

	def test_skill_ids(self):
		run = stats.make_run("r", run_end("r", 1.0, kills=12, skill_ids="dash,fireball,frost_nova"))
		self.assertEqual(run["skills"], ["fireball", "frost_nova"], "skill_ids: the skills held (without the roll)")
		run = stats.make_run("r", run_end("r", 1.0, kills=12, skills="dash,ice_wall"))
		self.assertEqual(run["skills"], ["ice_wall"], "an older run's skills still read")

	def test_skills_rebuilt_from_skill_props(self):
		run = stats.make_run("r1", self.by_id["e1"])
		self.assertEqual(run["skills"], ["fireball"], "from skill.fireball.uses")
		run = stats.make_run("r2", self.by_id["e5"])
		self.assertEqual(run["skills"], ["fireball"], "the roll (dash, slot 0) is not a pick")

	def test_duplicates_are_counted_once(self):
		events = talo_export.load([EDGE])
		self.assertEqual(len([e for e in events if e["name"] == "boss"]), 1, "e4 is e3 sent again")
		self.assertEqual(len(talo_export.load([EDGE, EDGE])), 5, "two overlapping exports: each event once")

	def test_zip_and_folder(self):
		events, _ = make_fixture.generate(seed=3, runs=12)
		with tempfile.TemporaryDirectory() as folder:
			path = os.path.join(folder, "export-1-20261024.zip")
			make_fixture.write_export(events, path)
			from_zip = talo_export.read_events(path)
			from_folder = talo_export.read_events(folder)
		self.assertEqual(len(from_zip), len(events))
		self.assertEqual(len(from_folder), len(events))


class FixtureRoundTripTests(unittest.TestCase):
	"""The synthetic export, written the way Talo writes it, reads back as the game sent it."""

	@classmethod
	def setUpClass(cls):
		cls.events, cls.dev = make_fixture.generate(seed=11, runs=80, dev_runs=5)
		cls.folder = tempfile.TemporaryDirectory()
		cls.path = os.path.join(cls.folder.name, "export.zip")
		cls.dev_path = os.path.join(cls.folder.name, "export_dev.zip")
		make_fixture.write_export(cls.events, cls.path)
		make_fixture.write_export(cls.events + cls.dev, cls.dev_path)

	@classmethod
	def tearDownClass(cls):
		cls.folder.cleanup()

	def test_props_survive_the_export(self):
		read = talo_export.read_events(self.path)
		catalog = talo_export.load_catalog()
		ordered = sorted(self.events, key=lambda e: e["time"])
		self.assertEqual(len(read), len(ordered))
		for sent, got in zip(ordered, read):
			self.assertEqual(sent["name"], got["name"])
			for key, value in sent["props"].items():
				self.assertTrue(talo_export.allows(catalog[sent["name"]], key), f"the fixture sends only catalog fields ({key})")
				if key == "skills" and "kills" in sent["props"]:
					continue  # lost to Talo's suffix match (rebuilt from skill.*)
				self.assertEqual(got["props"].get(key, ""), value, f"{sent['name']}.{key} (an empty prop = no prop)")
			self.assertLessEqual(set(got["props"]), set(sent["props"]), "no prop from another column")

	def test_runs_dedup_and_resumes(self):
		events = talo_export.load([self.path])
		runs = stats.build_runs(events)
		run_ids = {e["props"]["run"] for e in events if e["name"] == "run_end"}
		self.assertEqual(len(runs), len(run_ids), "one run per run id")
		resumed = [r for r in runs if r["ends_sent"] > 1]
		self.assertTrue(resumed, "the fixture has resumed runs")
		for run in resumed:
			self.assertFalse(run["status"] == "abandoned" and run["resumed"] > 0, "the latest end (resumed) is the one kept")

	def test_dev_export(self):
		events = talo_export.load([self.path], [self.dev_path])
		dev = [e for e in events if e["dev"]]
		self.assertEqual(len(dev), len(self.dev), "events only in the dev export are the dev ones")
		without = stats.build_views(events, FLOORS, include_dev=False)
		with_dev = stats.build_views(events, FLOORS, include_dev=True)
		self.assertNotIn("all|all|1", without["views"])
		self.assertEqual(with_dev["views"]["all|all|0"]["overview"]["runs"], without["views"]["all|all|0"]["overview"]["runs"])
		self.assertEqual(with_dev["views"]["all|all|1"]["overview"]["runs"],
			without["views"]["all|all|0"]["overview"]["runs"] + len({e["props"]["run"] for e in self.dev if e["name"] == "run_end"}))

	def test_dev_player(self):
		player = self.events[0]["player"]
		events = talo_export.load([self.path], dev_players=[player["identifier"]])
		self.assertTrue(all(e["dev"] == (e["alias"] == player["identifier"]) for e in events))


class RunTests(unittest.TestCase):
	def test_latest_end_wins_never_summed(self):
		events = [
			run_end("a", 100, quit=1, result="abandoned", depth=4, kills=10),
			run_end("a", 300, depth=7, kills=30, resumed=1),
			run_end("a", 200, quit=1, result="abandoned", depth=6, kills=20, resumed=1),
		]
		runs = stats.build_runs(events)
		self.assertEqual(len(runs), 1)
		self.assertEqual(runs[0]["depth"], 7)
		self.assertEqual(runs[0]["kills"], 30, "the latest end's count, not a sum")
		self.assertEqual(runs[0]["status"], "death")
		self.assertEqual(runs[0]["ends_sent"], 3)

	def test_statuses(self):
		runs = {r["id"]: r for r in stats.build_runs([
			run_end("dead", 1),
			run_end("left", 2, quit=1, result="abandoned"),
			run_end("won", 3, result="victory"),
			run_end("won_then_left", 4, quit=1, result="victory"),
		])}
		self.assertEqual(runs["dead"]["status"], "death")
		self.assertEqual(runs["left"]["status"], "abandoned")
		self.assertFalse(runs["left"]["finished"])
		self.assertTrue(runs["won"]["won"])
		self.assertTrue(runs["won_then_left"]["won"], "a win left in the endless floors is still a win")
		self.assertTrue(runs["won_then_left"]["finished"])

	def test_win_rate_ignores_abandoned(self):
		events = [run_end(f"w{i}", i, result="victory") for i in range(3)]
		events += [run_end(f"d{i}", 10 + i) for i in range(3)]
		events += [run_end(f"q{i}", 20 + i, quit=1, result="abandoned") for i in range(4)]
		runs = stats.build_runs(events)
		overview = stats.aggregate(runs, events, FLOORS)["overview"]
		self.assertEqual(overview["runs"], 10)
		self.assertEqual(overview["abandoned"], 4)
		self.assertEqual(overview["win_rate"], 0.5)

	def test_act_of(self):
		self.assertEqual([stats.act_of(d, FLOORS) for d in (1, 3, 4, 9, 12, 13)], [1, 1, 2, 3, 4, 5])
		self.assertEqual(names.act_floors(), FLOORS, "the game's acts have 3 floors each (else update FLOORS here)")


class RateTests(unittest.TestCase):
	def test_wilson(self):
		lo, hi = stats.wilson(5, 10)
		self.assertAlmostEqual(lo, 0.2366, places=3)
		self.assertAlmostEqual(hi, 0.7634, places=3)
		self.assertEqual(stats.wilson(0, 0), (0.0, 1.0))
		lo, hi = stats.wilson(3, 3)
		self.assertLess(lo, 0.5, "3 wins out of 3 is not proof")
		self.assertEqual(hi, 1.0)

	def test_small_samples_never_ranked_first(self):
		events = []
		for i in range(3):
			events.append(run_end(f"lucky{i}", i, weapon="stick", result="victory"))
		for i in range(40):
			events.append(run_end(f"solid{i}", 100 + i, weapon="katana", result="victory" if i % 5 < 3 else "death"))
		runs = stats.build_runs(events)
		weapons = stats.aggregate(runs, events, FLOORS, min_sample=10)["entities"]["weapon"]
		self.assertEqual([w["key"] for w in weapons], ["katana", "stick"], "60% on 40 runs before 100% on 3")
		stick = weapons[1]
		self.assertEqual(stick["win_rate"], 1.0)
		self.assertEqual(stick["conf"], "low")
		self.assertEqual(weapons[0]["conf"], "good")
		self.assertEqual(stats.confidence(15, 10), "medium")

	def test_combos_need_min_sample(self):
		events = [run_end(f"c{i}", i, weapon="bow", skills="dash,volley", result="victory") for i in range(6)]
		events += [run_end(f"r{i}", 10 + i, weapon="axe", skills="dash,cleave") for i in range(2)]
		runs = stats.build_runs(events)
		combos = stats.aggregate(runs, events, FLOORS, min_combo=5)["combos"]
		self.assertEqual([c["key"] for c in combos["weapon_skill"]], ["bow | volley"])

	def test_pick_rate(self):
		events = [run_end("p", 1, perks="vampirism:2", relics="phoenix_feather")]
		for perks in ("vampirism,strength,echo", "vampirism,fortune,echo", "fortune,thorns,echo"):
			events.append({"id": perks, "name": "perk_offered", "player": "p", "alias": "", "time": 0, "props": {"run": "p", "perks": perks}, "dev": False})
		events.append({"id": "x", "name": "perk_picked", "player": "p", "alias": "", "time": 0, "props": {"run": "p", "perk": "vampirism", "stacks": "1"}, "dev": False})
		runs = stats.build_runs(events)
		perks = {row["key"]: row for row in stats.aggregate(runs, events, FLOORS)["entities"]["perk"]}
		self.assertEqual(perks["vampirism"]["offered"], 2)
		self.assertEqual(perks["vampirism"]["pick_rate"], 0.5)
		self.assertEqual(perks["vampirism"]["avg_level"], 2)
		self.assertEqual(perks["echo"]["offered"], 3, "offered, never held: still a row")
		self.assertEqual(perks["echo"]["pick_rate"], 0)

	def test_bosses_and_next_form(self):
		events = talo_export.load([EDGE])
		runs = stats.build_runs(events)
		bosses = stats.aggregate(runs, events, FLOORS)["bosses"]
		self.assertEqual(len(bosses), 1)
		self.assertEqual(bosses[0]["won"], 1, "a form beaten (next_form) counts as won")
		self.assertEqual(bosses[0]["win_rate"], 1.0)
		self.assertEqual(bosses[0]["avg_time_won"], 61.5)

	def test_depth_and_deaths(self):
		events = [run_end("a", 1, depth=3, cause="monster", killer="king_slime", death_floor=3),
			run_end("b", 2, depth=3, cause="fall", death_floor=3),
			run_end("c", 3, depth=6, result="victory")]
		agg = stats.aggregate(stats.build_runs(events), events, FLOORS)
		floor3 = agg["depth"][2]
		self.assertEqual((floor3["reached"], floor3["deaths"], floor3["boss"]), (3, 2, True))
		self.assertAlmostEqual(floor3["death_rate"], 2 / 3, places=3)
		self.assertEqual({c["key"]: c["n"] for c in agg["causes"]}, {"monster": 1, "fall": 1})
		self.assertEqual(agg["killers"][0]["key"], "king_slime")
		self.assertEqual(agg["acts"][0]["deaths"], 2)

	def test_since_and_version_filters(self):
		events = [run_end("old", 100, v="0.2.9"), run_end("new", 5000, v="0.3.0", diff="hard")]
		data = stats.build_views(events, FLOORS, since=1000)
		self.assertEqual(data["views"]["all|all|0"]["overview"]["runs"], 1)
		data = stats.build_views(events, FLOORS)
		self.assertEqual(data["versions"], ["0.3.0", "0.2.9"])
		self.assertEqual(data["views"]["0.2.9|all|0"]["overview"]["runs"], 1)
		self.assertNotIn("0.2.9|hard|0", data["views"], "an empty combination is left out")


class PageTests(unittest.TestCase):
	def test_page_embeds_its_numbers(self):
		events, dev = make_fixture.generate(seed=5, runs=60, dev_runs=3)
		with tempfile.TemporaryDirectory() as folder:
			path = os.path.join(folder, "export.zip")
			make_fixture.write_export(events, path)
			out = os.path.join(folder, "page.html")
			out_json = os.path.join(folder, "page.json")
			with contextlib.redirect_stdout(io.StringIO()):
				self.assertEqual(build_dashboard.main([path, "-o", out, "--json", out_json]), 0)
			with open(out, encoding="utf-8") as handle:
				html = handle.read()
			with open(out_json, encoding="utf-8") as handle:
				numbers = json.load(handle)
		self.assertNotIn("__DATA__", html)
		self.assertNotIn("<script src", html, "self-contained: no external script")
		self.assertNotIn("<link", html, "self-contained: no external stylesheet")
		payload = re.search(r'<script id="data" type="application/json">(.*?)</script>', html, re.S).group(1)
		data = json.loads(payload)
		self.assertIn("all|all|0", data["views"])
		self.assertEqual(data["names"]["perk"]["multishot"], "Carquois de l'Hydre", "names in French from the game's data")
		self.assertEqual(numbers["overall"]["overview"]["runs"], data["views"]["all|all|0"]["overview"]["runs"])
		self.assertIn("weapon", numbers["overall"]["entities"])

	def test_script_end_in_data_is_escaped(self):
		data = {"views": {}, "names": {"word": {"x": "</script><b>"}}}
		html = build_dashboard.render_html(data)
		self.assertEqual(html.count("</script>"), 2, "only the page's own two script ends")


if __name__ == "__main__":
	unittest.main()
