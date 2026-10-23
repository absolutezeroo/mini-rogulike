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
even to read a board, and makes no id. The tests check it (`LeaderboardTests`, `PrivacyTests`:
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
   Stats, Game Feedback and Game Config scopes for later features).
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
- **Not followed**: a run abandoned for the title (no end); a resumed run's tracker starts at the
  resume (`resumed = 1`, the counts miss what came before).

| Event | When | Fields |
|---|---|---|
| `run_end` | a death or a win (again at the real end after the endless floors) | version, run id, OS, screen, input device(s), difficulty, ascension, daily/official, oath, depth, result, cause, killer, death floor, time, level, kills, bosses; the build (weapon id, rarity, element, runes, affixes; head, body, armor runes; awakened families, relics, perks with levels, skills); per skill uses and damage; potions drunk (in a boss fight, the average Health ratio when drunk, per potion), consumables left; rolls, hits dodged by rolling, dodge rate, hits taken; damage dealt and taken in total, by element and by source; biggest hit, crits, charged blows; time per floor; secrets, trap hits, falls into the Deeps (escaped), Threshold trials (won); gold earned and spent, souls, items dismantled and dropped |
| `boss` | a boss fight ends | boss, time, damage taken, hits taken, last phase, outcome (won, died, left, next_form), potions |
| `perk_offered` / `perk_picked` / `perk_banished` | a choice dealt (or rerolled) / taken / a banish | the perks, the perk (and its level) |
| `purchase` | bought from the merchant | item, rarity, price |
| `pact` | a pact ends | pact, outcome (kept, broken) |

Every event also carries `v` (the game's version), `run` (a random id per run) and `depth`.

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

## Privacy

Leaderboards: a random id made on the device, the pseudonym, the scores and their run summary.
Statistics: the events above, linked to the same id; with them, the player's shares of the world
counters (their totals per counter, and Talo's snapshot of each update). No email, no account, no hardware device id
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
queued or sent without consent or from a debug run, what a run's end sends and its sizes, the
queue's bound, deleting one's data, the files, and the questions, Options > Privacy, the policy
and the credits on screen.
`WorldStatsTests` (unit and title suites, `FakeBoardBackend`'s game stats): the data (unique
internal names, translated names and lines, the endings), numbers per language, nothing counted,
sent or read without a choice or in a debug run or build, published scores read the world without
counting the player, one update per counter at a run's end and the cap, the queue offline (and in
the file) sent once when the network is back, endings and offerings, withdrawing and deleting,
reads cached and hidden offline; the title's line (French, grouped, turning, hidden before a
choice) and the Toll page (filled, offline with Try again, no choice).
A real call to Talo can only be checked by hand (a probe under `_tool/`, with the key): done on
23 October 2026 (an identify and a `run_end` event as dev data).
