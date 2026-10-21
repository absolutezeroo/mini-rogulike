# Translating

The game ships in English and French. How the texts flow is in the README (Languages); this is
the routine for keeping the French complete.

## After adding or changing texts

1. Write the English: in code inside `tr("...")` (a whole sentence, its numbers as `%d`/`%s`
   or `{name}`), in data in the usual fields (`display_name`, `description`, `lore`, hint
   `title`/`text`...). Show data texts with `tr(def.field)`.
2. Run `python3 tools/i18n/extract.py`. It lists the new keys and the ones no longer used.
3. Fill the empty `fr` cells of `locale/strings.csv`, following the glossary in the README.
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
