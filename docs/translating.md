# Languages and translating

## How it works

English and French (`Settings.language`, saved with the other options). On first launch the game
follows the phone (`OS.get_locale_language()`: French if it is French, English otherwise); the
**Options** header has the picker (English / Français, each in its own language). Picking one sets
`TranslationServer`'s locale and rebuilds the Options window in it; the title screen is rebuilt
when the window closes. During a run (pause menu), what is filled when a menu opens follows at
once, but the menus built when the run began keep their words until the next run (the window
says so).

- **The translations** are `locale/strings.csv` (columns `keys,en,fr`), registered in `project.godot`
  (`internationalization/locale/translations`, the `.translation` files Godot imports from it). The
  key is the English text itself, so anything without a translation falls back to English.
- **In code**, every player text goes through `tr()` (`TranslationServer.tr()` in static functions).
  A format is translated whole, then filled: `tr("Level %d / %d") % [a, b]`; where French needs
  another word order, the text uses names: `tr("{rarity} {kind_lower}").format(...)`. Never
  translate pieces of a sentence; one key per plural (`"%d monster"`, `"%d monsters"`). Constants
  and lists of texts translated where they are shown carry an `# i18n` comment on their line.
- **Data texts** (names, descriptions, lore, hints, story, quests...) stay English in `data/`
  and are translated where they are shown: `tr(def.display_name)`. Names built in code follow
  the language's order and agreement: rolled items ("Sharp Katana of the Bear", "Hache de Guerre
  Affûtée de l'Ours") and elites (`LootRoller.rolled_name()`, `Grammar`: the CSV's
  `grammar:gender:<name>` keys say which names are feminine, `grammar:feminine:<adjective>` give
  the adjectives' feminine forms).
- **Not translated**: ids, the debug panel, console output, tests (they run in English:
  `tests/run_tests.gd` sets it).
- **Keeping the CSV up to date**: `python3 tools/i18n/extract.py` (standard library only)
  collects every `tr("...")` literal and `# i18n` line in the scripts, the scenes' texts, the
  player-facing fields of `data/**/*.tres` (and the grammar keys), and rewrites the CSV: existing
  translations kept, new keys with an empty French cell, unused keys dropped (listed).
  `--check` fails if the CSV is out of date or a French text is missing. Then fill the `fr`
  column (any spreadsheet or text editor; keep the `%d`, `%s`, `{name}` codes and the spaces
  around joining words like `" and "`). The unit tests check that every key has its French and
  keeps its codes.
- **Font**: the pixel font (`assets/fonts/normal_font.ttf`) had all French accents but œ Œ « »
  Î Ï … – — and the no-break spaces; `tools/i18n/add_glyphs.py` drew them on its grid, in its style.
  Typography: a plain space before `:`, `;`, `!`, `?` and `%` (`« %s »` for quotes).

**French glossary** (one word per idea, everywhere; the player is "tu"):

| English | Français | English | Français |
|---|---|---|---|
| Health / max Health | Vie / Vie max | Damage | Dégâts |
| Armor | Armure | Move speed | Vitesse |
| Attack speed | Vitesse d'attaque | Skill damage | Dégâts des compétences |
| Critical hit (chance) | coup critique (chance de coup critique) | skills recharge 5% faster | compétences rechargées 5 % plus vite |
| Souls / Gold | Âmes / Or | Shrine | Sanctuaire |
| Tree of Souls | Arbre des Âmes | Oath | Serment |
| Perk / Relic / Family | Atout / Relique / Famille | Rune / Forge / Smith | Rune / Forge / Forgeron |
| Merchant | Marchand | Bag / Belt | Sac / Ceinture |
| Elite / Epic / Legendary / Shiny (monsters) | Élite / Épique / Légendaire / Chromatique | Common / Magic / Rare / Epic (items) | Commun / Magique / Rare / Épique |
| Item level / "Lv 7" | Niveau d'objet / "Nv 7" | Floor / Act | Étage / Acte |
| Stairs / Seal | Escaliers / Sceau | Curse / Cursed | Malédiction / Maudit |
| Ambush | Embuscade | Reroll / Banish | Relancer / Bannir |
| The Well's Call (the daily run) | L'Appel du Puits | Run | Partie |
| Bestiary / Codex / Quests / Achievements | Bestiaire / Codex / Quêtes / Succès | Level up! | Niveau supérieur ! |
| Easy / Normal / Hard / Nightmare | Facile / Normal / Difficile / Cauchemar | Ascension | Ascension |
| Slay | Abattre (bosses: terrasser) | Warden | Gardien |

## After adding or changing texts

1. Write the English: in code inside `tr("...")` (a whole sentence, its numbers as `%d`/`%s`
   or `{name}`), in data in the usual fields (`display_name`, `description`, `lore`, hint
   `title`/`text`...). Show data texts with `tr(def.field)`.
2. Run `python3 tools/i18n/extract.py`. It lists the new keys and the ones no longer used.
3. Fill the empty `fr` cells of `locale/strings.csv`, following the glossary above.
   Keep every `%d`, `%s`, `%+d`, `%%` and `{name}` (same codes, same order for `%` codes), the
   `\n` line breaks, and the spaces at either end of joining words (`" and "` -> `" et "`).
   A new item or monster also gets a `grammar:gender:<name>` row (`m` or `f`), a new item
   prefix or elite affix a `grammar:feminine:<adjective>` row (its feminine form).
4. `python3 tools/i18n/extract.py --check` must pass, and so must the unit tests
   (`--only=unit`: every key has its French, the codes match).
5. Open the screens in French (Options > Français) and look for text that no longer fits: French
   runs 20-30% longer. Shorten the French first; widen or wrap only if that is not enough.

## Style

- The player is "tu". Short, punchy UI words; RPG verbs (abattre, terrasser, déferler).
- Lore and story: written prose, a little solemn and dark.
- Names: evocative French fantasy, not word for word ("Gilded Hoarder" -> "L'Accapareur Doré").
- A plain space before `:`, `;`, `!`, `?` and `%`; quotes as `« ... »`.
