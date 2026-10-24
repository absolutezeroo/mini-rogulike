"""Reads the gameplay statistics out of a Talo data export (docs/online.md "Reading the statistics").

Talo's admin API has no route that reads events or starts an export (its admin keys cover
players, leaderboards, stats, live config and channels only): the events leave Talo through the
dashboard's data export (Services > Export > Events), a ZIP mailed to the account. This module
reads that ZIP, a folder of its CSVs, or one CSV, and gives back the events as plain dicts.

The export's format (TaloDev/backend, src/lib/queues/data-exports/dataExportProcessor.ts):
`events-1.csv`, `events-2.csv`... (100,000 rows each), header
`id,name,playerAlias.id,playerAlias.service,playerAlias.identifier,playerAlias.player.id,
createdAt,updatedAt` then one `props.<key>` column per prop key any event of the game ever had
(`META_` keys first, then sorted), RFC 4180 quoting, an empty cell for a prop the event lacks.
`createdAt` is the event's own timestamp (ISO, UTC). The export has no dev-build column: it holds
dev data or not depending on the dashboard's "Dev data" toggle when it was made.

A Talo quirk to know: a cell is filled with the first of the event's props whose key the column
name *ends with* (`column.endsWith(prop.key)`), so a column can carry a shorter key's value (a
`purchase` row shows its `rarity` under `props.weapon_rarity`, a `boss` row its `boss` under
`props.potions_boss`), and worse, a run_end's `props.skills` showed its `kills` (sorted first;
the game sends `skill_ids` since, and checks that no key of an event ends another one).
Each event is therefore read through the telemetry catalog (data/online/telemetry.tres): only the
fields its own event lists are kept, which drops the ghosts from other events; and a cell equal to
a shorter key's value of the same event is dropped (_drop_ghosts()), the skills being rebuilt from
the `skill.<id>.uses` / `.dmg` props.
"""

from __future__ import annotations

import csv
import io
import os
import re
import sys
import zipfile
from datetime import datetime, timezone

BASE_COLUMNS = (
	"id", "name", "playerAlias.id", "playerAlias.service", "playerAlias.identifier",
	"playerAlias.player.id", "createdAt", "updatedAt",
)

## The catalog as the game had it when this tool was written: used when the repo's
## data/online/telemetry.tres can't be read (the tool copied elsewhere).
DEFAULT_CATALOG = {
	"run_end": [
		"v", "run", "os", "screen", "input", "inputs", "resumed", "partial", "quit", "diff", "asc",
		"daily", "official", "oath", "depth", "result", "cause", "killer", "death_floor", "time",
		"level", "kills", "bosses", "weapon", "weapon_rarity", "weapon_element", "weapon_runes",
		"weapon_affixes", "head", "body", "armor_runes", "sets", "relics", "perks", "skill_ids",
		"skill.*", "potions", "potions_boss", "potion_health", "potion.*", "left.*", "rolls",
		"dodged", "dodge_rate", "hits_taken", "dmg_out", "dmg_in", "dmg_out.*", "dmg_in.*",
		"src_out.*", "src_in.*", "biggest_hit", "crits", "charged", "floor_times", "secrets",
		"trap_hits", "deeps", "deeps_escaped", "threshold", "threshold_won", "gold_earned",
		"gold_spent", "souls", "dismantled", "dropped",
	],
	"boss": ["v", "run", "depth", "boss", "time", "dmg_in", "hits_taken", "phase", "outcome", "potions"],
	"perk_offered": ["v", "run", "depth", "perks"],
	"perk_picked": ["v", "run", "depth", "perk", "stacks"],
	"perk_banished": ["v", "run", "depth", "perk"],
	"purchase": ["v", "run", "depth", "item", "rarity", "price"],
	"pact": ["v", "run", "depth", "pact", "outcome"],
}

## Fields older versions of the game sent, still read from older exports: run_end's `skills`
## (renamed `skill_ids`: Talo's suffix match filled `props.skills` with `kills`).
LEGACY_FIELDS = {
	"run_end": ["skills"],
}

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CATALOG_PATH = os.path.join(REPO_ROOT, "data", "online", "telemetry.tres")


def load_catalog(path: str = CATALOG_PATH) -> dict[str, list[str]]:
	"""Each event's fields, read from telemetry.tres (`name = &"..."` then `fields = PackedStringArray(...)`)."""
	try:
		with open(path, encoding="utf-8") as handle:
			text = handle.read()
	except OSError:
		return {name: list(fields) for name, fields in DEFAULT_CATALOG.items()}
	catalog: dict[str, list[str]] = {}
	for block in text.split("[sub_resource")[1:]:
		name = re.search(r'^name = &"([^"]+)"', block, re.M)
		fields = re.search(r"^fields = PackedStringArray\((.*)\)", block, re.M)
		if name and fields:
			catalog[name.group(1)] = re.findall(r'"([^"]*)"', fields.group(1))
	return catalog or {name: list(fields) for name, fields in DEFAULT_CATALOG.items()}


def allows(fields: list[str], key: str) -> bool:
	"""`key` is one of `fields` (`skill.*` stands for every `skill.<...>` key)."""
	for field in fields:
		if field.endswith(".*"):
			if key.startswith(field[:-1]):
				return True
		elif field == key:
			return True
	return False


def parse_time(text: str) -> float:
	"""Unix seconds of an ISO time ("2026-10-24T10:00:00.000Z"); 0 if unreadable."""
	text = (text or "").strip()
	if not text:
		return 0.0
	try:
		moment = datetime.fromisoformat(text.replace("Z", "+00:00"))
	except ValueError:
		return 0.0
	if moment.tzinfo is None:
		moment = moment.replace(tzinfo=timezone.utc)
	return moment.timestamp()


def _csv_sources(path: str) -> list[tuple[str, io.TextIOBase]]:
	"""The events CSVs in `path` (a ZIP, a folder, a CSV) as (name, text stream)."""
	sources: list[tuple[str, io.TextIOBase]] = []
	if os.path.isdir(path):
		for name in sorted(os.listdir(path)):
			full = os.path.join(path, name)
			if name.lower().endswith(".zip"):
				sources.extend(_csv_sources(full))
			elif _is_events_csv(name):
				sources.append((full, open(full, encoding="utf-8-sig", newline="")))
	elif zipfile.is_zipfile(path):
		archive = zipfile.ZipFile(path)
		for name in sorted(archive.namelist()):
			if _is_events_csv(os.path.basename(name)):
				raw = archive.open(name)
				sources.append((f"{path}:{name}", io.TextIOWrapper(raw, encoding="utf-8-sig", newline="")))
	elif os.path.isfile(path):
		sources.append((path, open(path, encoding="utf-8-sig", newline="")))
	else:
		raise FileNotFoundError(path)
	return sources


def _is_events_csv(name: str) -> bool:
	return bool(re.fullmatch(r"events(-\d+)?\.csv", name.lower()))


def read_events(path: str, catalog: dict[str, list[str]] | None = None) -> list[dict]:
	"""Every event of the export at `path`: {id, name, player, alias, time, props}.

	`props` holds only the event's catalog fields with a value (an empty cell = no prop). An event
	whose name the catalog doesn't know keeps every prop (a newer game than the tool).
	"""
	catalog = catalog if catalog is not None else load_catalog()
	csv.field_size_limit(min(sys.maxsize, 2**31 - 1))
	events: list[dict] = []
	for source_name, stream in _csv_sources(path):
		with stream:
			reader = csv.reader(stream)
			header = next(reader, None)
			if not header:
				continue
			if "name" not in header or "id" not in header:
				raise ValueError(f"{source_name}: not a Talo events export (no id/name column)")
			index = {column: i for i, column in enumerate(header)}
			prop_columns = [(i, column[len("props."):]) for i, column in enumerate(header) if column.startswith("props.")]
			for row in reader:
				if not row:
					continue
				def cell(column: str) -> str:
					i = index.get(column)
					return row[i] if i is not None and i < len(row) else ""
				name = cell("name")
				fields = catalog.get(name)
				if fields is not None:
					fields = fields + LEGACY_FIELDS.get(name, [])
				props: dict[str, str] = {}
				for i, key in prop_columns:
					if i >= len(row) or row[i] == "":
						continue
					if fields is None or allows(fields, key):
						props[key] = row[i]
				_drop_ghosts(props)
				events.append({
					"id": cell("id"),
					"name": name,
					"player": cell("playerAlias.player.id") or cell("playerAlias.id"),
					"alias": cell("playerAlias.identifier"),
					"time": parse_time(cell("createdAt")),
					"props": props,
				})
	return events


def _drop_ghosts(props: dict[str, str]) -> None:
	"""Drops the cells Talo filled with a shorter key's value: `props.skills` shows `kills` when the
	event's `kills` comes first (its props are sorted), `props.src_out.weapon` may show `weapon`.
	A cell equal to the value of another key its name ends with can't be told apart: it goes (the
	run's skills are then rebuilt from its `skill.<id>.*` props, stats.make_run())."""
	for key in list(props):
		for other in props:
			if other != key and ("props." + key).endswith(other) and props[key] == props[other]:
				del props[key]
				break


def event_key(event: dict) -> tuple:
	"""What makes two rows the same event sent twice (a batch sent again after a lost answer):
	same name, player, timestamp and props."""
	return (event["name"], event["player"], event["time"], tuple(sorted(event["props"].items())))


def load(paths: list[str], dev_paths: list[str] | None = None, dev_players: list[str] | None = None,
		catalog: dict[str, list[str]] | None = None) -> list[dict]:
	"""The events of every export in `paths`, each once, `dev` False; with the events found only in
	`dev_paths` (exports made with the dashboard's dev data on) marked `dev` True, as are those of
	`dev_players` (player ids or alias identifiers, e.g. the device id shown in Options > Privacy).
	"""
	catalog = catalog if catalog is not None else load_catalog()
	dev_players = set(dev_players or [])
	seen: set = set()
	result: list[dict] = []

	def add(event: dict, dev: bool) -> None:
		key = event_key(event)
		if key in seen:
			return
		seen.add(key)
		event["dev"] = dev or event["player"] in dev_players or event["alias"] in dev_players
		result.append(event)

	for path in paths:
		for event in read_events(path, catalog):
			add(event, False)
	for path in dev_paths or []:
		for event in read_events(path, catalog):
			add(event, True)
	result.sort(key=lambda e: (e["time"], e["id"]))
	return result
