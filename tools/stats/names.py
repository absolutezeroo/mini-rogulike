"""The names the dashboard shows for the ids the statistics carry, read from the game's data.

Each kind of id (weapon, perk, boss...) is looked up in its folders of data/: the `id` and
`display_name` of the file's own [resource] (not its sub-resources), then the French of that
English name in locale/strings.csv. Ids kept their first names when the names changed
(AGENTS.md), so `multishot` shows as "Carquois de l'Hydre". An id not found shows as itself.
"""

from __future__ import annotations

import csv
import glob
import os
import re

from talo_export import REPO_ROOT

## Folders of each kind of id (relative to data/; ** = every sub-folder).
KINDS = {
	"weapon": ["items/weapons/*.tres"],
	"armor": ["items/armors/*.tres"],
	"item": ["items/consumables/*.tres", "items/weapons/*.tres", "items/armors/*.tres", "items/tomes/*.tres", "items/keys/*.tres"],
	"skill": ["skills/player/*.tres"],
	"perk": ["perks/common/*.tres", "perks/relics/*.tres"],
	"set": ["perks/synergies/*.tres"],
	"monster": ["monsters/**/*.tres"],
	"element": ["vfx/elements/*.tres"],
	"rune": ["runes/**/*.tres"],
	"affix": ["affixes/**/*.tres"],
	"oath": ["oaths/*.tres"],
	"pact": ["pacts/*.tres"],
	"difficulty": ["difficulties/*.tres"],
	"act": ["dungeon/acts/*.tres"],
}

## Words the statistics use that are not data ids.
WORDS = {
	"death": "Mort", "victory": "Victoire", "abandoned": "Abandon",
	"monster": "Monstre", "fall": "Chute", "trap": "Piège", "unknown": "Inconnue", "giving_up": "Reddition",
	"blast": "Explosion", "status": "Altération", "weapon": "Arme", "skill": "Compétence", "perk": "Don",
	"rune": "Rune", "item": "Objet", "other": "Autre", "plain": "Sans élément",
	"touch": "Tactile", "keyboard": "Clavier", "gamepad": "Manette",
	"won": "Gagné", "died": "Mort", "left": "Quitté", "next_form": "Forme suivante",
	"kept": "Tenu", "broken": "Rompu", "nightmare": "Cauchemar", "none": "Aucun",
}

## The elements' data (data/vfx/elements/) has no names: theirs here.
ELEMENTS = {
	"plain": "Sans élément", "physical": "Physique", "fire": "Feu", "water": "Eau", "storm": "Foudre",
	"poison": "Poison", "holy": "Sacré", "arcane": "Arcane", "earth": "Terre", "spirit": "Esprit",
	"blood": "Sang", "frost": "Givre",
}

RARITIES = ["Commune", "Magique", "Rare", "Épique"]


def _french() -> dict[str, str]:
	path = os.path.join(REPO_ROOT, "locale", "strings.csv")
	table: dict[str, str] = {}
	try:
		with open(path, encoding="utf-8", newline="") as handle:
			for row in csv.DictReader(handle):
				if row.get("keys") and row.get("fr"):
					table[row["keys"]] = row["fr"]
	except OSError:
		pass
	return table


def _own_resource(text: str) -> tuple[str, str, str]:
	"""(id, display_name, title) of a .tres file's [resource] section."""
	part = text.split("\n[resource]", 1)
	body = part[1] if len(part) > 1 else ""
	found = {}
	for key in ("id", "display_name", "title", "subtitle"):
		match = re.search(r'^%s = &?"((?:[^"\\]|\\.)*)"' % key, body, re.M)
		found[key] = match.group(1) if match else ""
	return found["id"], found["display_name"], found["title"]


def act_floors(root: str = REPO_ROOT) -> list[int]:
	"""Floors of each act in order (ActDef.floors, 3 when the file doesn't say), boss floor included."""
	floors: list[int] = []
	for path in sorted(glob.glob(os.path.join(root, "data", "dungeon", "acts", "act_*.tres"))):
		with open(path, encoding="utf-8") as handle:
			match = re.search(r"^floors = (\d+)", handle.read(), re.M)
		floors.append(int(match.group(1)) if match else 3)
	return floors or [3, 3, 3, 3]


def load_names(root: str = REPO_ROOT) -> dict[str, dict[str, str]]:
	"""{kind: {id: French name}} for every kind of KINDS; acts are keyed "1".."4"."""
	french = _french()
	names: dict[str, dict[str, str]] = {"word": dict(WORDS)}
	for kind, patterns in KINDS.items():
		table: dict[str, str] = {}
		for pattern in patterns:
			for path in sorted(glob.glob(os.path.join(root, "data", pattern), recursive=True)):
				try:
					with open(path, encoding="utf-8") as handle:
						rid, display, title = _own_resource(handle.read())
				except OSError:
					continue
				if kind == "act":
					number = re.search(r"act_(\d+)", os.path.basename(path))
					if number and title:
						table[number.group(1)] = french.get(title, title)
					continue
				if not rid:
					rid = os.path.splitext(os.path.basename(path))[0]
				if display:
					table.setdefault(rid, french.get(display, display))
		names[kind] = table
	names["element"] = {**ELEMENTS, **names["element"]}
	return names
