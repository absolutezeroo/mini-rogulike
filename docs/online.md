# Online leaderboards and gameplay statistics (Talo)

The game's two online features, both on [Talo](https://trytalo.com), an open-source game backend,
and both off until the player turns them on: the **leaderboards** and the **gameplay statistics**
(Talo's events). What the player sees is in
[design/progression.md](design/progression.md#online-leaderboards) and
[design/interface.md](design/interface.md#privacy-and-credits); the privacy rules, the dashboard's
retention settings, the Play Console form and deletion requests are in
[privacy-ops.md](privacy-ops.md); this page is how they are built, how to set them up and what
they protect against.

**The rule: no Talo call at all before the player's choice.** Until the player answers "Publish my
scores" (or turns it on in Options) and/or accepts the statistics, the game makes no request, not
even to read a board or the remote settings, and makes no id. The tests check it (`LeaderboardTests`, `PrivacyTests`:
the fake server counts its calls).

## How it is built

- **REST, not the Talo plugin.** The game talks to Talo's HTTP API with `HTTPRequest`
  (`TaloBackend`, `src/online/talo_backend.gd`): a few endpoints (identify a player, set its name,
  add an entry, list entries, send events, add to a game stat and read them). The official Godot addon (MIT, `TaloDev/godot`) was read and left
  out: about 7,700 lines for 14 services we don't use, an autoload that takes over quitting
  (`set_auto_accept_quit(false)`), opens a websocket at start, writes a `settings.cfg` into
  `res://` on first run (read-only in an export), prints `push_error`s on every failed request
  (noise in the tests and on a phone without network) and keeps its own replay queue. Ours is
  under 200 lines (the service around it, ~370), works the same on Android and Windows (Godot's own TLS and CA list), and fails
  quietly.
- **`Leaderboards`** (autoload, `src/autoload/leaderboards.gd`): listens for `Events.run_ended`
  (a `RunSummary` made by `RunRecords.report_end()` when the Game gives the souls: a death, or a
  win), queues the scores the boards take, sends them, retries every `retry_seconds` while there
  is no network (and when the app comes back to the front), and reads the boards for the page
  (`load_board()`). UI asks it; it never asks the UI.
- **Backends** (`BoardBackend`, `src/online/board_backend.gd`): the base class is the offline one
  (every call answers UNAVAILABLE); `TaloBackend` is Talo; the tests use `FakeBoardBackend`
  (`tests/support/`), a server in memory that acts like Talo's boards. A new service (Google Play
  Games, Steam) would be another subclass.
- **Boards are data**: `LeaderboardDef` resources in `data/leaderboards/boards/`, listed in
  `data/leaderboards/leaderboards.tres` (`LeaderboardsConfig`, with the page's sizes, the retry
  delay, the pseudonym's rules and refused words, and the limits of a plausible run). A board has
  its id, its name and rule (translated), its Talo internal name, what it ranks (`Score`), which
  way, its period (daily, weekly, all time), which runs it takes (the daily run's official attempt
  or normal runs), a difficulty and ascension filter, `submits` (scores are sent to it) and `shown`
  (a tab on the page). Adding a board: a file there, its line in `leaderboards.tres`, the same
  board in the dashboard (below).
- **Its own file**: `user://leaderboards.json` holds the device's random id (shown in Options >
  Privacy, for a deletion request), the Talo player id it became, the pseudonym, "Publish my
  scores online" (off until chosen; a file from before, version 1, is asked again) and the queue.
  Never the player's save or the Profile.
- **Periods.** Each daily (weekly) entry carries its day (week) as a prop, `day` = the UTC day
  number of `DailyRun.today()` (`week` = `QuestBoard.week_index()`); the page asks Talo for one
  day's entries (`propKey=day&propValue=<day>`, archived ones with `withDeleted=1` for
  yesterday). The board itself refreshes daily, so "one entry per player" means one per day.
  A score that could not be sent before its day ended is dropped: sent the next day, Talo would
  count it on the new day.

## The boards in Clayton's Talo game

Already created (23 October 2026), all with **unique entries** (one per player), no unique-by-props:

| Internal name | Sort | Refresh | Sent to | Shown |
|---|---|---|---|---|
| `daily-challenge` | descending | daily | yes (the Dawn Knell's official attempt) | yes |
| `depth-easy`, `depth-normal`, `depth-hard` | descending | never | not yet (`submits = false`) | no |
| `fastest-win-easy`, `fastest-win-normal`, `fastest-win-hard` | ascending (milliseconds) | never | not yet | no |
| `ascension` | descending | never | not yet | no |
| `vigil` | descending | never | not yet (La Veille isn't in the game) | no |

Turning one on is data: `submits = true` (then `shown = true` once it has entries) in its file.
Never rename an internal name: the data and the dashboard must keep matching.

**Midnight.** Talo empties a daily board at its server's midnight (its `archive-leaderboard-entries`
task at 00:00, `isToday()` in the server's time zone; Talo's own tests run in UTC and the cloud
service is expected to be UTC, but that can't be checked from the game). The game doesn't depend
on it to show a day (it filters by the `day` prop). If Talo's midnight were not UTC, a score sent
between the two midnights could replace the previous day's entry of the same player instead of
making a new one.

## Setting it up (what Clayton does)

What is left: **only the key file**. For reference, the whole setup:

1. **Game**: on [dashboard.trytalo.com](https://dashboard.trytalo.com), create the game (done).
2. **Access key**: *API keys* > create a key with only these scopes: **Players: read and write**
   (`read:players` to identify the device's player, `write:players` to set its name),
   **Leaderboards: read and write** (`read:leaderboards`, `write:leaderboards`), **Events: write**
   (`write:events`, the gameplay statistics). Nothing else is needed (done; the key also has Game
   Stats, Game Feedback and Game Config scopes; **Game Config: read** is used by the remote
   settings).
3. **Display name** (recommended): *Game settings* > **Display name prop key** = `name`. The
   pseudonym is a player prop called `name`: with this set, a renamed player shows the new name on
   every entry. Without it the game falls back on the name copied into each entry.
4. **Profanity**: if *Game settings* offers it, turn on Talo's profanity filter for props (the
   server's own check, after the game's: `blockPropsProfanity` in Talo's code).
5. **A new board** (later): *Leaderboards* > create one with the internal name of its
   `LeaderboardDef` (`talo_name`), the sort mode matching `higher_first` (descending when true),
   **Unique entries** on, **Unique by props** off, refresh **daily** for a daily board, **weekly**
   for a weekly one, **never** for all time. Then `submits = true` in its file.
6. **The key in the game**: copy `online/talo.cfg.example` to `online/talo.cfg` and paste the key
   as `access_key`. Git ignores this file (`.gitignore`): **never commit it**. The export presets
   pack it into the builds (`include_filter="online/talo.cfg"`). In a CI, write the file from a
   secret before exporting, e.g. `printf '[talo]\naccess_key="%s"\n' "$TALO_ACCESS_KEY" >
   online/talo.cfg`. On a computer the environment variable `TALO_ACCESS_KEY` also works at run
   time, without the file. No key (or an empty one): the game is offline, the page says the
   leaderboards are unavailable, nothing fails.

The key ships inside the game, like every client key: anyone can dig it out of an APK. Its scopes
are what limits the harm (no deleting, no reading saves), which is why it has only those four.

Builds from the editor (debug builds) send `X-Talo-Dev-Build: 1`: their players and entries are
**development data**, kept apart (orange) in the dashboard and hidden from release builds; debug
builds see them (`X-Talo-Include-Dev-Data: 1`).

## What it protects against (honestly)

- **In the game**: no score from a debug run (`DebugCheats.debug_run`), a practice attempt, the
  tests, or a player who turned "Show me in the leaderboards" off. Before a run is queued,
  `RunSummary.check()` refuses what no real run does: a score that isn't what its numbers make
  (`DailyRun.score()`), floors cleared faster than `min_seconds_per_floor`, more kills or gold
  than floors hold, more bosses than floors, a win without its time.
- **On the server**: one entry per player and day (unique entries: only a better score replaces
  it), and every entry carries the run in short as props (`v` the game's version, `day`, `seed`,
  `diff`, `asc`, `depth`, `kills`, `bosses`, `gold`, `won`, `time`, `weapon`, `relic`, `name`), to
  read in the dashboard. A suspicious entry is **hidden or deleted by hand** there (Leaderboards >
  the board > the entry); a cheater's player can be deleted.
- **Not more.** The client can be modified and the key extracted: anyone determined can post any
  score. Talo's request signing (`X-Talo-Signature`) would make it harder; it is not used.

## Gameplay statistics (Talo events)

With the player's consent only (`Privacy.analytics_allowed()`: 16 or older, accepted, for the
current consent version), each run that ends sends what it was, to balance the game and find its
bugs. Built so that the game never depends on it:

- **`RunTelemetry`** (`src/online/run_telemetry.gd`) follows one run from `Events.run_started`
  (the Game emits it once the hero is made): it listens to the hero's signals (skills, potions and
  the heal they gave, charged blows, gold, dismantling, dropping) and the Events bus
  (`actor_damaged` and `hit_dodged`, emitted by `Actor.take_hit()`; boss fights, perk choices,
  purchases, pacts, secrets, the Deeps and the Threshold), counts in memory, and at the end makes
  the `run_end` event's props (`summary()`). Damage is sorted by element (`HitInfo.element`) and
  source (`HitInfo.via`: the acting skill, perk, rune or item when the hit was made, a shot's when
  it was fired; else status, trap, fall..., the weapon or a monster).
- **`Telemetry`** (autoload, `src/autoload/telemetry.gd`) makes a tracker per run; at
  `Events.run_ended` it queues the run's events (if consented, never for a debug run), keeps only
  the fields the catalog lists, and sends them in batches through the leaderboards' server
  (`Leaderboards.identity()`, `BoardBackend.send_events()`: `POST /v1/events` with the
  `X-Talo-Alias` header; the same device id, so one player on Talo). Queue in
  `user://telemetry.json` (at most `max_queue` events, the oldest dropped), retried every
  `retry_seconds` without network, sent at a run's end and when the app goes to the background.
  Refusing or withdrawing drops what waited. Debug builds' events are dev data
  (`X-Talo-Dev-Build: 1`), like the leaderboards'.
- **The catalog is data**: `data/online/telemetry.tres` (`TelemetryDef`, `TelemetryEventDef`): each
  event, on or off, its purpose and its fields (`skill.*` stands for each skill's). A field not
  listed is dropped before it is queued; turning one off is data.
- **Talo's limits**: a prop key at most 128 characters, a value at most 512
  (`MAX_KEY_LENGTH`/`MAX_VALUE_LENGTH` in the backend's `src/entities/prop.ts`); `sanitize()`
  keeps every event inside (a long list loses its last items at a comma) and caps the props
  (`max_props`). Never a `META_` prop: Talo copies those into the player's props, which its API
  shows to anyone reading a board.
- **A run left for the title** (pause > Save and quit, or the window closed: `Events.run_left`,
  for good) sends its `run_end` at once, `result` "abandoned" (or "victory" after a win, in the
  endless floors) and `quit` 1, with the build and every count so far, and the events waiting for
  it (boss fights, perks...). **The app put in the background** (Android's pause, a lost focus)
  writes the same end as a draft in `user://telemetry.json`: dropped when the app comes back,
  queued at the next launch if the app was killed there (`Telemetry.draft`).
- **A resumed run counts from its start**: the tracker's counts go into the run's save
  (`Events.run_saving` -> `RunState.telemetry` -> `run.json`, local only) each time it is saved,
  and come back with it (`RunTelemetry.from_data()`), with the same `run` id; `resumed` counts the
  resumes; `partial` 1 marks a run resumed from a save made before the counts were kept (they
  start at the resume). Nothing leaves the device without consent: the save is local.
- **Reading it in the dashboard (no double count)**: a run left then resumed sends a `run_end` at
  each quit and one at its end, all with the same `run` id, each covering everything since the
  run's start. Count runs as distinct `run` ids and keep each id's **latest** `run_end` (highest
  timestamp): its numbers are the whole run's. `quit` 1 on that latest one means the run was
  never finished (or not yet). Never sum `run_end` events of one id. The other events (`boss`,
  `perk_*`, `purchase`, `pact`) are sent once each, with whichever `run_end` follows them.
  Sending at every quit, rather than only when the save is thrown away, keeps the runs of players
  who never come back (or uninstall), and needs nothing kept on the device after the run.

| Event | When | Fields |
|---|---|---|
| `run_end` | a death or a win (again at the real end after the endless floors); a run left for the title or the app closed (`result` abandoned, `quit` 1; again at its real end if resumed) | version, run id, resumes (`resumed`), counts missing before a resume (`partial`), left without ending (`quit`), OS, screen, input device(s), difficulty, ascension, daily/official, oath, depth, result, cause, killer, death floor, time, level, kills, bosses; the build (weapon id, rarity, element, runes, affixes; head, body, armor runes; awakened families, relics, perks with levels, skills); per skill uses and damage; potions drunk (in a boss fight, the average Health ratio when drunk, per potion), consumables left; rolls, hits dodged by rolling, dodge rate, hits taken; damage dealt and taken in total, by element and by source; biggest hit, crits, charged blows; time per floor; secrets, trap hits, falls into the Deeps (escaped), Threshold trials (won); gold earned and spent, souls, items dismantled and dropped |
| `boss` | a boss fight ends | boss, time, damage taken, hits taken, last phase, outcome (won, died, left, next_form), potions |
| `perk_offered` / `perk_picked` / `perk_banished` | a choice dealt (or rerolled) / taken / a banish | the perks, the perk (and its level) |
| `purchase` | bought from the merchant | item, rarity, price |
| `pact` | a pact ends | pact, outcome (kept, broken) |

Every event also carries `v` (the game's version), `run` (a random id per run) and `depth`.

## Reading the statistics (tools/stats)

Talo's dashboard charts one event at a time; the questions that matter (which weapon wins, which
boss blocks, do players drink too late) need the runs put together. `tools/stats/` is a dev tool
(Python 3, standard library only, nothing in the game) that reads a **data export** and makes one
self-contained HTML page, in French, readable on a phone:

```
python3 tools/stats/build_dashboard.py ~/Downloads/export-<game>-<date>.zip -o stats.html
python3 tools/stats/build_dashboard.py exports/ --since 2026-11-01 --json stats.json -o stats.html
python3 tools/stats/build_dashboard.py prod.zip --include-dev --dev-export with_dev.zip -o stats.html
python3 -m unittest discover tools/stats      # its tests
```

- **How the events leave Talo.** Only through the dashboard's export: Talo's admin API (the
  admin key we used for the world counters) has routes for players, leaderboards, game stats,
  live config and channels, and **none that reads events or starts an export** (checked in
  TaloDev/backend: `src/routes/admin/*`, `AdminAPIKeyScope`); the export route
  (`POST /games/:id/data-exports`) takes a logged-in dashboard user, an admin with a confirmed
  email, and the ZIP is **mailed** (attached, or a download link). The game's own key can only
  write events. So the export is a step done by hand (below), and the tool reads its ZIP.
- **The export's format** (backend `dataExportProcessor.ts`): `events-1.csv` (then `-2`... per
  100,000 rows) with `id, name, playerAlias.id, playerAlias.service, playerAlias.identifier,
  playerAlias.player.id, createdAt, updatedAt` and a `props.<key>` column per prop key the game
  ever sent. **No dev column**: the export holds dev data or not depending on the dashboard's
  "Dev data" switch when it is made. To look at dev runs, make a second export with dev data on
  and pass it as `--dev-export` (its events missing from the normal one are the dev ones), or name
  the dev devices with `--dev-player <device id>` (Options > Privacy shows it).
- **Talo's export bug.** A cell is filled with the first prop whose key the column name *ends
  with*, so `props.skills` holds the run's `kills` (the game sends its props sorted, `kills`
  first), and a `boss` row shows its boss under `props.potions_boss`. The tool keeps only each
  event's catalog fields (`data/online/telemetry.tres`), drops a cell equal to a shorter key's
  value, and rebuilds the skills from `skill.<id>.uses`/`.dmg` (the skills used, not those held).
  Renaming the `skills` prop in the game would avoid it (roadmap card).
- **What the tool counts**: runs as distinct `run` ids with their latest `run_end` (above),
  abandoned runs apart (never in a win rate), events sent twice counted once (same name, player,
  time and props). Every rate shows its sample and a 95% Wilson interval; rows under
  `--min-sample` finished runs (default 10) are grey and never ranked above the others; build
  combinations need `--min-combo` runs (5). The build is the one the run *ended* with
  (survivorship: deep runs gather more perks and relics).
- **The page**: overview (runs, players, win rate, abandons), difficulty and ascension, depth
  reached and the death rate of each floor (boss floors marked), deaths by cause, killer and act,
  the bosses (fights, win rate, time, damage and hits taken, potions, phase reached at death),
  weapons, their rarity and element, head, body and both, runes, skills (results and use),
  perks and relics (offered, picked, pick rate, banished, results), awakened families, oaths,
  pacts, the best combinations (weapon + a skill, + armor, + a relic, + every skill), potions
  (drunk per run, in boss fights, the Health when drunk, left unused at death), the roll (rolls a
  minute, dodge rate, win rate by dodge rate, by act), damage by element and source, time per
  floor, the economy (gold, purchases, souls), devices. Filters (version, difficulty, dev data)
  are computed beforehand for every combination and embedded; the page needs no network, works
  light and dark, and holds no player id (it can be shared; the export can't).
- **`--json`** writes the same numbers for scripts (the `game-balancer`: docs/balance.md).
- **Tests**: `tools/stats/test_stats.py` on `fixtures/edge_events.csv` (quoting, the export bug,
  a resumed run, a boss's next form, a batch sent twice) and on a synthetic export made by
  `fixtures/make_fixture.py` (fixed seed, the catalog's events, written the way Talo writes them:
  props must come back as sent). `python3 tools/stats/fixtures/make_fixture.py demo.zip` makes
  one to try the page.

### Sortir les données de Talo (à faire par Clayton)

1. Sur [dashboard.trytalo.com](https://dashboard.trytalo.com), choisir le jeu, puis le menu
   **Services** > **Export** (« Export your data »; adresse directe `dashboard.trytalo.com/exports`).
   Il faut être administrateur du jeu, avec une adresse email confirmée.
2. En haut de la page, l'interrupteur **Dev data** : le laisser **désactivé** (« not enabled »)
   pour n'avoir que les vrais joueurs.
3. Sous *Create data export*, cocher **Events** (c'est tout ce que l'outil lit; *Players* et
   *Player aliases* ne servent pas). Cliquer **Create**.
4. Talo envoie un email quand l'export est prêt (un ZIP en pièce jointe, ou un lien de
   téléchargement). Le nombre d'exports par mois dépend de l'offre Talo.
5. Garder le ZIP **hors du dépôt** (il contient les identifiants des appareils : jamais dans git),
   puis lancer :
   `python3 tools/stats/build_dashboard.py chemin/vers/export-....zip -o stats.html`
   et ouvrir `stats.html` (sur l'ordinateur ou le téléphone). Le ZIP peut être supprimé ensuite.
6. Pour voir aussi ses propres parties de test : refaire un export avec **Dev data** activé et
   ajouter `--include-dev --dev-export chemin/vers/export_dev.zip` (la page aura un interrupteur
   « Données dev »).

## World counters (the Well's Toll)

Numbers every player adds to, kept by Talo as **global game stats** (`/v1/game-stats`): the
world's total, and each player's own share. Shown on the title screen (a line at the bottom that
turns every `title_line_seconds`, from `title_min_count`) and on the Leaderboards page's last tab,
**The Well's Toll** / *Le Tribut du Puits* (every counter, the world's number, the player's share).

- **`WorldStats`** (autoload, `src/autoload/world_stats.gd`) listens to the Events bus during a
  run and counts in `pending`: `monster_killed` (not a summoned one), `boss_defeated`,
  `depth_changed` (deeper than the run's deepest so far: a resumed floor isn't counted again), the
  hero's `consumable_used` (a healing potion), a death at `run_ended`, a new Dawn Knell at
  `run_started` (not a resumed one), `ending_chosen` (emitted by the Game when the ending is picked,
  after `run_ended`) and `souls_offered` (`Profile.buy()`, at the shrine). At `run_ended` (and
  `ending_chosen`, `souls_offered`) the counts join the queue, each **capped to its counter's max
  change**, and go. A run left unfinished keeps its counts in the file and they go with the next
  run's end (an abandoned run's end, once it is told on the same `run_ended` path, is the same).
- **One update per counter**, never one call per kill: `PUT /v1/game-stats/{internalName}`
  `{change}` with the `X-Talo-Alias` header (the leaderboards' player). A share past the max
  change goes in parts. Queue in `user://world_stats.json` (`pending`, `queue`, `mine`: the
  player's share), tried again every `retry_seconds` without network, at a run's end and when the
  app comes back. A counter the server refuses (unknown, past its max change) is dropped.
- **Reading**: `GET /v1/game-stats` (every stat with its `globalValue`, no player needed) at most
  every `refresh_seconds` (300), kept in memory only (offline, nothing shows); with the statistics'
  consent also `GET /v1/game-stats/player-stats` (the player's own totals; the server caches it 30
  s, so the larger of it and what was sent is shown). Numbers by language: `NumberText.of()`
  ("1,284,302", "1 284 302" with a narrow no-break space, which the font has).
- **Consent** (privacy-ops.md): sending needs the **gameplay statistics' consent**
  (`Privacy.analytics_allowed()`); reading the world's numbers needs either online feature turned
  on (published scores or the statistics). Before any choice: no call at all.
- **Never from a debug build.** Talo's PUT adds the change to the stat's global value whatever
  `X-Talo-Dev-Build` says (`stat.incrementGlobalValue()` in `src/routes/api/game-stat/put.ts`; only
  the dashboard's view recalculates without dev players): an editor run would show in every
  player's numbers. `WorldStats.debug_builds_send` is off (the tests turn it on for their fake
  server). Never from a debug run (`DebugCheats.debug_run`, `RunSummary.debug`), nor the tests.
- **The counters are data**: `data/online/world_stats.tres` (`WorldStatsDef`, `WorldStatDef`):
  Talo's internal name, the name on the page and the title line (`{count}`), what feeds it
  (`Feed`), the ending for an ENDING feed, `max_change`, on or off.

### The counters in Clayton's Talo game

Created on 23 October 2026 with the admin API (`POST /admin/v1/game-stats`, scope `write:stats`):
all **global**, default 0, **min value 0**, no max value, **no time between updates** (0).

| Internal name | Talo id | Max change | Fed by | Shown as (EN / FR) |
|---|---|---|---|---|
| `demons-slain` | 5220 | 5000 | KILLS | Demons slain in the Well / Démons abattus dans le Puits |
| `wardens-laid-to-rest` | 5221 | 200 | BOSSES | Wardens laid to rest / Gardiens rendus au repos |
| `souls-claimed` | 5222 | 50 | DEATHS | Souls claimed by the Well / Âmes réclamées par le Puits |
| `floors-descended` | 5223 | 2000 | FLOORS | Floors descended / Étages descendus |
| `potions-drunk` | 5224 | 1000 | POTIONS | Potions drunk in the deep / Potions bues dans les profondeurs |
| `last-knells-rung` | 5225 | 50 | ENDING `ring_the_bell` | Last Knells rung / Derniers Glas sonnés |
| `nameless-keepers` | 5226 | 50 | ENDING `take_his_place` | Nameless Keepers before the seal / Gardiens Sans Nom devant le sceau |
| `dawn-knells-answered` | 5227 | 50 | DAILY_RUNS | Dawn Knells answered / Glas de l'Aube entendus |
| `souls-offered` | 5228 | 1000000 | SOULS_OFFERED | Souls offered to the Tree / Âmes offertes à l'Arbre |

**Adding a counter**: a `WorldStatDef` in `world_stats.tres` (its texts translated: `extract.py`
reads `display_name` and `title_line`), then the same stat in the dashboard (*Stats* > create, or
the admin API): the same internal name, **Global** on, default 0, min value 0, max change at
least the def's `max_change`, time between updates 0. A new kind of event to count is a new
`Feed` and its listener in `WorldStats`. Never rename an internal name. The game's key needs
**Game Stats: read and write** (`read:gameStats`, `write:gameStats`; already on it).

Smoke test (23 October 2026, `_tool/world_stats_smoke.gd`, dev data): a test player
`world-stats-smoke-test`, a PUT of change 0 on `demons-slain` (0: a dev build's change would count
in the world's value), the list read back (every counter at 0), the player's own totals read, an
unknown stat and a change past the max refused (400).

## Remote settings (Talo game config)

A few values the game takes from Talo's **game config** (the game's live config: key/value
texts), so a balance hotfix, a weekend event, the Dawn Knell's omen, a message of the day or a
kill switch needs no update. **The game's own data stays the default**: no network, no key, no
online choice, no value or a bad one, and the game is exactly as its data makes it.

- **`RemoteConfig`** (autoload, `src/autoload/remote_config.gd`) reads `GET /v1/game-config`
  (`TaloBackend.fetch_config()`, the key's `read:gameConfig` scope) a few seconds after the start,
  when an online choice is made, and on the title screen when the last read is older than
  `refresh_seconds` (900; Talo itself caches the config 10 minutes). The read carries **no
  player** (no `X-Talo-Alias`), and like the world counters it is made only once the player turned
  an online feature on (published scores or accepted statistics): before that, no call at all.
- **The allow-list is data**: `data/online/remote_config.tres` (`RemoteConfigDef`, one
  `RemoteKeyDef` per key: its Talo key, its kind, its bounds, the hook it acts on, its purpose). A
  key not listed, a value of the wrong form, **out of its bounds** (ignored, never clamped: a typo
  of 15 for 1.5 must not become 2), an id that isn't one of the game's curses or floor events, a
  text too long: ignored, listed in `RemoteConfig.ignored` (the debug panel) and printed in debug
  builds. An empty value means "unset". Nothing from the server is ever a path, a resource or
  code: each key reaches one fixed hook (`RemoteKeyDef.Hook`) the game reads.
- **Safe points**: what is read goes into `latest`; the game uses `active`, copied from it only at
  the **title screen** (`RemoteConfig.at_title()`) and when a **run starts or is resumed**
  (`RemoteTuning.run_starting()` from `Game._begin_run()`), never in the middle of a run. A run's
  values are then fixed in its `RemoteTuning` (`RunState.tuning`) and **saved with it**: a run
  resumed after a change keeps the values it began with. The kill switches are the exception
  (below).
- **How a value reaches the game**: the multipliers go onto the run's own copy of its
  `DifficultyDef` (`RemoteTuning.apply_to()`, like an ascension level: `monster_hp` and `boss_hp`,
  `monster_damage`, `souls`), so `FloorRules` and `RunState.souls()` scale with them where they
  read the difficulty; nothing multiplies them by hand. The omen and an event's boosted floor
  event are read by `FloorRoute.offer()` and `World.build_floor()` from the run's tuning.
  (The game's classes ask through `RemoteTuning`'s static hooks, which the autoload fills: naming
  the autoload from `World` or `RunState` makes a load cycle that breaks the World's subclasses.)
- **The version gate**: `min_version` / `max_version` make the whole config apply to those game
  versions only (`application/config/version`, compared part by part: 0.10.0 after 0.9.2). Outside
  them, every key is ignored, the kill switches too. Empty: every version.
- **The cache**: the last good read (the allow-list's keys only) in `user://remote_config.json`;
  it applies from the next start, offline too. Nothing personal is in it.

### The keys

| Key | Kind, bounds | What it does (default: the game unchanged) |
|---|---|---|
| `enemy_health_easy`, `_normal`, `_hard`, `_nightmare` | number 0.5 to 2 (1) | multiplies every monster's and boss's Health in runs of that difficulty |
| `enemy_damage_easy`, `_normal`, `_hard`, `_nightmare` | number 0.5 to 2 (1) | multiplies everything that hurts the hero (monsters, traps, the cold) in runs of that difficulty |
| `souls_multiplier` | number 0.5 to 3 (1) | multiplies the souls every run gives |
| `daily_omen` | a curse or floor event id (`frostbound`, `ashen_breath`, `lanternless`, `blood_moon`, `darkness`, `haunted`, `market_day`, `swarm`, `treasure_vault`) | the Dawn Knell of the day `daily_omen_date` names puts it on **every normal floor** (not the first, not the wardens'; both ways down). Told in the Dawn Knell's card and in the log |
| `daily_omen_date` | date, `2026-10-31` (UTC) | the day the omen is for; any other day is untouched (no date: no omen) |
| `event_name_en`, `event_name_fr` | text, 40 characters | the event's name on the title screen (English is the fallback); no name: no event |
| `event_ends` | date (`2026-10-26`: the end of that UTC day) or moment (`2026-10-26T22:00:00Z`) | when the event ends; no end: no event |
| `event_souls` | number 1 to 3 (1) | the event's souls bonus (runs started during it; on top of `souls_multiplier`) |
| `event_floor_event` | a floor event id | made more likely among the floor events during the event |
| `event_floor_weight` | number 1 to 10 (1) | how much more likely (multiplies its spawn weight) |
| `motd_en`, `motd_fr` | text, 120 characters | a message of the day on the title screen, in the tagline's place (English is the fallback) |
| `scores_off` | true / false | **kill switch**: no score queued or sent (applies at once, mid-run too) |
| `statistics_off` | true / false | **kill switch**: no gameplay statistics nor world counters counted, queued or sent (applies at once) |
| `min_version`, `max_version` | version, `0.3.0` | the game versions the config is for |

**In Clayton's Talo game** the 23 keys were created on 24 October 2026 with the admin API
(`PATCH /admin/v1/game-config`, scope `write:gameConfig`) with neutral values: numbers `1`, flags
`false`, the rest empty. The game then behaves exactly as without them.

### Changing a value (the dashboard)

On [dashboard.trytalo.com](https://dashboard.trytalo.com): the game > **Game config** (Talo calls
it the live config) > edit the key's value > save. The game reads it within about 10 minutes (Talo's
cache) the next time it starts or shows the title, and applies it at the title or the next run's
start. Give values exactly in the forms above (a decimal point, not a comma: `1.25`). Check it took:
the debug panel's **Remote** tab in an editor build (it lists what was ignored and why). To go
back, put the neutral value back (`1`, `false`, empty).

### Running a weekend event

1. Set `event_name_en` and `event_name_fr` (in the Well's voice: "Night of Souls" / "La Nuit des
   Âmes"), `event_ends` (Sunday's date: the end of that UTC day), `event_souls` (`1.5` = +50%),
   and if you want `event_floor_event` (`blood_moon`) with `event_floor_weight` (`4`).
2. Optionally `motd_en` / `motd_fr` to say it on the title.
3. The title shows the event's plaque under Credits (its name, the bonus, the floor event, the
   time left); every run **started** before the end gets it (a run keeps it to its end).
4. Nothing to undo: past `event_ends` it stops by itself. Empty the name afterwards to tidy up.

To start it at a set time, Talo can **schedule** a config change (the dashboard's scheduled changes,
or `POST /admin/v1/game-config/scheduled-changes` with `{changes: [{key, value, applyAt}]}`); set
the name that way and the event begins when the name appears.

## Privacy

Leaderboards: a random id made on the device, the pseudonym, the scores and their run summary.
Statistics: the events above, linked to the same id; with them, the player's shares of the world
counters (their totals per counter, and Talo's snapshot of each update). The remote settings'
read sends no id (Talo sees the device's IP address, as with any request), only once an online
feature is on. No email, no account, no hardware device id
(the id is random, never `OS.get_unique_id()`), no location. Both are off until chosen and can be
turned off in Options > Privacy, which also shows the id and prepares a deletion request. The
policy is `docs/privacy.html` (FR and EN) and, short, in the game (`data/online/privacy.tres`);
what to do in Talo's dashboard and the Play Console: [privacy-ops.md](privacy-ops.md).

## Tests

`LeaderboardTests` (unit and title suites) run on `FakeBoardBackend`, never the network: nothing
is queued, sent or read before the player chose to publish, the data
is valid, the pseudonym filter, an official daily attempt is queued once with its score and props,
practice and debug runs and impossible runs are not, the queue and the device id survive a
restart, the queue empties when the network is back (and a past day's score is dropped), opting
out sends nothing, no key means offline; the page's unavailable, offline (Retry) and filled
states. The test runner gives the autoload an offline backend and no file before any suite runs.
`PrivacyTests` (unit, title, and the game suite's run) check the consent rules (off by default,
the age, six months after a refusal on a fake clock, a newer consent version), that nothing is
queued or sent without consent or from a debug run, what a run's end sends and its sizes, a run
quit to the title (one `run_end` abandoned with its stats) then resumed (its end covers both
parts, same id, nothing sent twice), the background draft (dropped on return, queued at the next
launch), the queue's bound, deleting one's data, the files, and the questions, Options > Privacy, the policy
and the credits on screen.
`WorldStatsTests` (unit and title suites, `FakeBoardBackend`'s game stats): the data (unique
internal names, translated names and lines, the endings), numbers per language, nothing counted,
sent or read without a choice or in a debug run or build, published scores read the world without
counting the player, one update per counter at a run's end and the cap, the queue offline (and in
the file) sent once when the network is back, endings and offerings, withdrawing and deleting,
reads cached and hidden offline; the title's line (French, grouped, turning, hidden before a
choice) and the Toll page (filled, offline with Try again, no choice).
`RemoteConfigTests` (unit and title suites, `FakeBoardBackend.config`): the allow-list's data,
the game's own values offline, before a choice and without a key, out-of-bounds values, unknown
keys and ids ignored (not clamped), values applied only at safe points, a run keeping its values
(saved, resumed after a change), `FloorRules` scaling with them, the version gate, both kill
switches (applied mid-run, lifted), the omen on that day's Dawn Knell only (every way down, the
rest of the offer unchanged), an event (its bonus, its boosted floor event, its end), the file;
the title's event plaque and message of the day in French, the English fallback, nothing before a
choice. The real config was read on 24 October 2026 with the game key (`GET /v1/game-config`, 23
keys, all neutral; through `TaloBackend.fetch_config()` too: 13 valid values, the empty ones unset,
nothing ignored).
A real call to Talo can only be checked by hand (a probe under `_tool/`, with the key): done on
23 October 2026 (an identify and a `run_end` event as dev data).
