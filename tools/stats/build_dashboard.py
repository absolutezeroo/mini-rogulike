#!/usr/bin/env python3
"""Builds the gameplay statistics' dashboard: one self-contained HTML page (French, phone-sized,
light and dark) from a Talo data export (docs/online.md "Reading the statistics").

The page reads no network and needs nothing else: its numbers are computed here (stats.py) for
every filter it offers (version x difficulty x dev data) and embedded as JSON; the page only
shows them. `--json` writes the same numbers for scripts (the game-balancer, docs/balance.md).

Usage (from the repo root, python3, standard library only):
  python3 tools/stats/build_dashboard.py ~/Downloads/export-1234-20261024.zip -o stats.html
  python3 tools/stats/build_dashboard.py exports/ --since 2026-10-01 -o stats.html --json stats.json
  python3 tools/stats/build_dashboard.py prod.zip --include-dev --dev-export with_dev.zip -o stats.html
Inputs: the export ZIP Talo mails, a folder of exports or of their CSVs, or one events CSV;
several may be given (overlapping exports are merged, each event counted once).
Options:
  -o, --out PATH       the HTML page (default stats_dashboard.html)
  --json PATH          also the numbers as JSON ("views" keyed "<version>|<difficulty>|<dev 0/1>",
                       "all" for every one; "overall" = all versions and difficulties, no dev data)
  --include-dev        keep the dev data (the page gets a "Données dev" switch, off at first)
  --dev-export PATH    an export made with the dashboard's "Dev data" on: its events missing from
                       the other exports are the dev ones (the export itself has no dev column)
  --dev-player ID      a player (Talo player id, or the alias identifier = the device id shown in
                       Options > Privacy) whose events are dev data; repeatable
  --since DATE         only events from this day on (YYYY-MM-DD, UTC)
  --min-sample N       finished runs below which a rate is "low" and not ranked (default 10)
  --min-combo N        finished runs a build combination needs to be listed (default 5)
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import names as names_module  # noqa: E402
import stats  # noqa: E402
import talo_export  # noqa: E402

TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dashboard_template.html")


def parse_since(text: str | None) -> float:
	if not text:
		return 0.0
	return datetime.strptime(text, "%Y-%m-%d").replace(tzinfo=timezone.utc).timestamp()


def build(paths: list[str], include_dev: bool = False, dev_paths: list[str] | None = None,
		dev_players: list[str] | None = None, since: float = 0.0, min_sample: int = 10,
		min_combo: int = 5, generated: str | None = None) -> dict:
	"""Everything the page shows: {meta, names, versions, difficulties, include_dev, views}."""
	events = talo_export.load(paths, dev_paths, dev_players)
	floors = names_module.act_floors()
	data = stats.build_views(events, floors, include_dev, since, min_sample, min_combo)
	kept = [e for e in events if e["time"] >= since and (include_dev or not e.get("dev"))]
	times = [e["time"] for e in kept if e["time"] > 0]
	day = lambda t: datetime.fromtimestamp(t, timezone.utc).strftime("%d/%m/%Y")
	data["meta"] = {
		"events": len(kept),
		"period": f"du {day(min(times))} au {day(max(times))}" if times else "aucune date",
		"generated": generated or datetime.now(timezone.utc).strftime("%d/%m/%Y %H:%M UTC"),
		"sources": ", ".join(os.path.basename(os.path.normpath(p)) for p in paths + (dev_paths or [])),
		"floors": floors,
	}
	data["names"] = names_module.load_names()
	return data


def render_html(data: dict) -> str:
	with open(TEMPLATE, encoding="utf-8") as handle:
		template = handle.read()
	payload = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
	return template.replace("__DATA__", payload)


def balancer_json(data: dict) -> dict:
	"""The numbers for scripts: every view, and "overall" (all versions and difficulties, no dev)."""
	return {
		"meta": data["meta"],
		"versions": data["versions"],
		"difficulties": data["difficulties"],
		"overall": data["views"].get(stats.view_key("all", "all", False)),
		"views": data["views"],
	}


def main(argv: list[str] | None = None) -> int:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("inputs", nargs="+", help="export ZIP(s), folder(s) or events CSV(s)")
	parser.add_argument("-o", "--out", default="stats_dashboard.html")
	parser.add_argument("--json", dest="json_out")
	parser.add_argument("--include-dev", action="store_true")
	parser.add_argument("--dev-export", action="append", default=[])
	parser.add_argument("--dev-player", action="append", default=[])
	parser.add_argument("--since")
	parser.add_argument("--min-sample", type=int, default=10)
	parser.add_argument("--min-combo", type=int, default=5)
	args = parser.parse_args(argv)
	data = build(args.inputs, args.include_dev, args.dev_export, args.dev_player, parse_since(args.since),
		args.min_sample, args.min_combo)
	overall = data["views"].get(stats.view_key("all", "all", False))
	if overall is None:
		print("No run in these exports (no run_end event): is it an export of the Events?", file=sys.stderr)
	with open(args.out, "w", encoding="utf-8") as handle:
		handle.write(render_html(data))
	if args.json_out:
		with open(args.json_out, "w", encoding="utf-8") as handle:
			json.dump(balancer_json(data), handle, ensure_ascii=False, indent=1)
	runs = overall["overview"]["runs"] if overall else 0
	size = os.path.getsize(args.out) // 1024
	print(f"{args.out}: {runs} runs, {data['meta']['events']} events, {len(data['views'])} views, {size} KB")
	return 0


if __name__ == "__main__":
	sys.exit(main())
