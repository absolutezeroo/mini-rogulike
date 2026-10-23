# Online leaderboards (Talo)

The game's only online feature: leaderboards on [Talo](https://trytalo.com), an open-source game
backend. What the player sees is in [design/progression.md](design/progression.md#online-leaderboards);
this page is how it is built, how to set it up and what it protects against.

## How it is built

- **REST, not the Talo plugin.** The game talks to Talo's HTTP API with `HTTPRequest`
  (`TaloBackend`, `src/online/talo_backend.gd`): four endpoints (identify a player, set its name,
  add an entry, list entries). The official Godot addon (MIT, `TaloDev/godot`) was read and left
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
- **Its own file**: `user://leaderboards.json` holds the device's random id (never shown), the
  pseudonym, "Show me in the leaderboards" and the queue. Never the player's save or the Profile.
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
   **Leaderboards: read and write** (`read:leaderboards`, `write:leaderboards`). Nothing else
   (done).
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

## Privacy

Sent: a random id made on the device, the pseudonym, the scores and their run summary. No email,
no account, no device identifier of the system, no location. The player can turn sending off in
the options. `docs/privacy.html` says so (the Play Store's data safety form must say it too:
"App activity: other user-generated content / in-game identifiers", not shared, not required).

## Tests

`LeaderboardTests` (unit and title suites) run on `FakeBoardBackend`, never the network: the data
is valid, the pseudonym filter, an official daily attempt is queued once with its score and props,
practice and debug runs and impossible runs are not, the queue and the device id survive a
restart, the queue empties when the network is back (and a past day's score is dropped), opting
out sends nothing, no key means offline; the page's unavailable, offline (Retry) and filled
states. The test runner gives the autoload an offline backend and no file before any suite runs.
A real call to Talo can only be checked by hand (a probe under `_tool/`, with the key).
