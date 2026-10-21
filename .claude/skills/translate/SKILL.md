---
name: translate
description: Write or review the French translation of Le Puits des Âmes - fill empty fr cells of locale/strings.csv, translate new texts, keep the glossary and typography. Use after adding player-facing texts, when extract.py --check fails, or when asked about French wording.
---

# Translating

The full rules and the glossary are in docs/translating.md: read its "French glossary" table and
the "Style" section before writing French. Names and lore follow the dark-fantasy voice of
docs/lexicon.md (vocabulary bank, naming patterns, words to avoid); rules stay plain.

1. `python3 tools/i18n/extract.py` updates `locale/strings.csv` (columns `keys,en,fr`; the key is
   the English text) and lists new keys.
2. Fill each empty `fr` cell:
   - one word per idea, from the glossary (Health = Vie, Damage = Dégâts, Perk = Atout...);
   - the player is "tu"; UI short and punchy; lore a little solemn and dark;
   - keep every `%d`, `%s`, `%+d`, `%%`, `{name}` code (same `%` codes in the same order), `\n`, and
     the spaces around joining words (`" and "` -> `" et "`);
   - a plain space before `:` `;` `!` `?` `%`, quotes as `« ... »`;
   - names: evocative French fantasy, not word for word;
   - new item or monster names: a `grammar:gender:<name>` row (`m`/`f`); item prefixes and elite
     affixes: a `grammar:feminine:<adjective>` row.
3. Keep the CSV valid: quote cells containing commas, quotes or line breaks.
4. `python3 tools/i18n/extract.py --check` must pass, then
   `godot --headless --fixed-fps 60 res://tests/run_tests.tscn -- --only=unit`.
5. French runs 20-30% longer: flag texts likely to overflow buttons or cards, since headless tests
   can't see that.
