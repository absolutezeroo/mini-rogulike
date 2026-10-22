---
name: lore
description: Write or review the lore of Le Puits des Âmes in its dark-fantasy voice - story pages, act and curse lore, boss and NPC lines, the Veilleuse's dialogue, fragments, item and monster descriptions, endings. Use whenever a player-facing text tells the story or speaks for a character.
---

# Writing the lore

Two pages decide everything; read both before writing a line:
- **docs/lore.md** — the canon: what is true (the Maw, Solhar, Maître Tôma, Hana, the wardens,
  the keepers, the places, the revelation schedule, the rules of the canon).
- **docs/lexicon.md** — the voice: register, vocabulary bank, naming patterns, words to avoid,
  rules stay plain, who speaks how.

## Steps

1. **Place the text.** Who speaks (narrator, the Well, a warden, a keeper, the Veilleuse, a
   fragment's author)? Where does it show (story page, act card, banner, dialogue box, codex
   entry, item card)? When can the player see it (which progress step of docs/lore.md section 7)?
2. **Check the canon.** The line must agree with docs/lore.md. If it needs a new fact, add the
   fact to docs/lore.md first (same commit), in the right section, without contradicting it.
3. **Respect the reveal.** A line may hint at a later step, never state it. Before the Effigy is
   slain and the journal found, nobody names Tôma as the culprit; the wardens say "the keeper".
4. **Write French first**, then English as its equal (not word for word):
   - narrator and the Well: present tense, short, one image, no exclamation marks; the Well never
     says "I";
   - wardens: one or two sentences at waking and at death, their own obsession (see the table in
     docs/lore.md section 5); lines change with each meeting (first, again, many times);
   - a warden's chronicle (docs/lore.md 5b): the Well's narrator in chapters of 2-4 lines (what
     you see, its life, how it fell, the keeper who bound it, its truth), its own waking words in
     quotes, a deed's riddle that is fair but never the rule (the rule is plain, and a fragment may
     give it away);
   - keepers (the Old Wanderer, Brann, the Grinning Spirit, the Veilleuse): in quotes « ... », weary, dry, a
     little wry; each has a voice (docs/lore.md section 6);
   - fragments: a real author (Tôma's journal, a Solhar archivist, a tithe ledger, a prayer), a
     date or a place, ends on an image; 2-5 short lines;
   - rules and numbers stay plain (docs/lexicon.md (e)): a dark name, a plain rule.
5. **Lengths.** Banners and hints ≤ 120 characters; a dialogue line ≤ 2 sentences (it must fit a
   phone's dialogue box at Fonts.BODY); story pages ≤ 3 lines; codex entries ≤ 6 lines.
6. **Names** follow docs/lexicon.md (c): Kagari's things are Japanese-rooted (Tôma, Hana, rônin,
   tengu; write ô not ō: the font has no macron), Solhar's are older and foreign (Solhar, Brann,
   gold, sun). Never rename an id; change `display_name` only.
7. **Data, not code.** Texts live in data (`data/story/`, monster/boss/item/NPC `.tres`,
   dialogue and fragment resources) as English keys translated where shown with `tr()`; run
   `python3 tools/i18n/extract.py`, fill the French in `locale/strings.csv` with your French
   original, then `python3 tools/i18n/extract.py --check`. Follow the `translate` skill for
   typography (« », spaces before : ; ! ? %).
8. **Review checklist** before committing:
   - agrees with docs/lore.md; any new fact added there;
   - right speaker voice; no modern/gamer words (lexicon (d));
   - reveal respected (gated by the right progress condition);
   - fits its box on a phone (screenshot at 1540x720 and 2340x1080 in FR and EN);
   - French reads as French (not translated English), « » and spacing right.

## Where things go

| Text | Data |
|---|---|
| Intro pages, victory, death lines, shrine text, tagline | `data/story/story.tres` (StoryDef) |
| Act titles and lore | `data/dungeon/acts/act_*.tres` (`title`, `lore`) |
| Curse, event, pact lore | `data/curses/`, `data/floor_events/`, `data/pacts/` |
| Bosses' and monsters' descriptions, titles | `data/monsters/**/*.tres` |
| Merchant, smith, encounters | `data/shop/`, `data/forge/`, `data/encounters/` |
| Places beyond the floors | `data/threshold/`, `data/abyss/`, `data/secrets/nameless_charnel.tres` |
| A warden's story (chapters, waking words, deeds' riddles) | `data/story/chronicles/<boss id>.tres` (`BossChronicleDef`, on the `BossDef`) |
| Fragments (pages, tablets, letters, Tôma's journal) | `data/story/fragments/<id>.tres` (`FragmentDef`), listed in their warden's chronicle |
| What gates a reveal | `ProgressCondition`s; shared ones in `data/story/conditions/` (`keeper_named`: any text naming Tôma) |
| Dialogue, endings (when built) | their own resources, gated by the same progress conditions |
