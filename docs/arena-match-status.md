# Q3 arena matches and the single-player ladder

Q3 levels now run as local free-for-all matches using the original ladder data.
The `ArenaMatch` node links each competitor, human or bot, through a `Competes`
edge. Each edge carries that competitor's name, frags and deaths. Spawn points
are `SpawnPoint` nodes. Walkers credit frags, make announcements and choose
spawns.

## Match rules

- `scripts/arenas.txt` supplies each arena's bots, frag limit and name.
  `scripts/bots.txt` maps each bot to its player model and skin (for example
  Hossman is `biker/hossman`). Maps outside the ladder get a three-bot, 20-frag
  skirmish.
- Bots spawn at `SelectRandomFurthestSpawnPoint`-style positions: a random pick
  among the furthest half of the spawn points from other competitors.
  Competitors spawn with 125 health, which decays to 100.
- Bots fight every competitor, not just the player: each keeps a visible living
  enemy, otherwise targets the nearest visible competitor within 1500 units.
  Bot hits on other bots go through the full opponent damage path, so victims
  die, animate and respawn.
- Every fatal hit records its attacker. A frag credits the killer; suicides and
  world deaths cost the victim a frag (`g_combat.c`).
- Matches start with *Prepare to fight*, a three-two-one countdown and
  *Fight!*, during which nobody attacks. The announcer calls lead changes (taken,
  tied, lost) and the last three frags, then *You win* or `<bot>_wins`.
- The player respawns with fire or jump after 1.7 s, and automatically after
  20 s, at the furthest spawn with the standard loadout. The match keeps running
  meanwhile.
- **Tab** (or **F1**) shows the scoreboard, which also appears during the
  countdown and while dead (see [Scoreboard](#scoreboard)).
- The level menu lists Q3's ladder first (training, tiers, final), with arena
  names and the best finish from `~/.quakepassion-arena.txt`.
- Bots use their own models and skins as three-part animated bodies (see
  [Q3 player bodies](player-bodies-status.md)).
- `ClientSpawn`'s `G_KillBox` telefrags anyone on the spawn spot when a bot
  or the player respawns.

Snapshot format **19** stores the match clock, countdown, lead state and every
competitor's frags and deaths.

## Jac fixes found on the way

The Competes edge names exposed a native Jac defect: attributes given in a typed
connect (`a +>:Competes:name=n:+> b`) were dropped. It is fixed upstream; see
[native compiler dependencies](native-lighting-validation-blockers.md).

## Podium

When a single-player match ends, the view moves to the map's intermission point
and the top three finishers take the podium (`g_arenas.c`,
`engine/world/podium.jac`):
- The view is `info_player_intermission`, aimed at its target.
- The podium model stands 80 units ahead of the view and 70 below it, turned
  toward it.
- Stand-ins of the first three finishers take the pads at the original offsets,
  each holding the weapon it held at the end. The player's stand-in is Sarge.
- Two seconds later the winner plays its torso gesture and taunt, then stands
  again when the gesture timer runs out.

`tests/podium_tests.jac` covers the placement and the celebration.

## Scoreboard

The scoreboard follows `cg_scoreboard.c` `CG_DrawOldScoreboard`
(`engine/render/arena_screens.jac`), in Q3's own art:
- "Fragged by" the killer while dead, and the player's place ("Tied for
  2nd place with 4", the place in its colour).
- The score, time and name tabs from `menu/tab`.
- A 40-unit line per competitor, highest score first, with:
  - the bot's skill mark (`menu/art/skill1-5`);
  - its head: the 3D head model facing the viewer (`cg_draw3dIcons`, with
    the model's `headoffset`), or `icon_<skin>.tga` without 3D icons;
  - score, minutes played and name;
  - the player's own line highlighted by rank (blue, red, yellow, grey).
- A local game has no ping column. Instead, each line lists that competitor's
  excellent, impressive and gauntlet awards under the name, as counted on
  its `Competes` edge.

Ranks come from the `RankScores` walker over the `Competes` edges
(`CalculateRanks`: ranked by how many score higher, ties marked).

## Postgame

After the podium, the single-player postgame menu (`q3_ui/ui_sppostgame.c`)
plays over it:
1. The top three names stand over their pads in the proportional font
   (`menu/art/font1_prop`) for five seconds.
2. Each award takes the stage for two seconds with its medal
   (`menu/medals`) and announcer line. The awards stay up for at least five
   seconds.
3. The earned medals stay along the top with their counts. The menu, replay
   and next buttons appear below.

Other details:
- The score lines roll along the top right every 1.5 s when there are more
  than three players.
- Keys are ignored for 1.5 s. Then any key skips the podium, then the
  awards.
- Left and Right choose a button, and Enter presses it:
  - **Next** (the default for a winner) goes to the next ladder arena.
  - **Replay** (the default otherwise) restarts the arena.
  - **Menu** opens the level menu.
- The win or loss music plays when the podium starts.
- The status bar, view weapon and frag line are hidden.

Awards (`UI_SPPostgameMenu_f`):
- Accuracy of 50% or better. Shots and hits are counted as `FireWeapon` and
  `LogAccuracyHit` count them: every shot but the gauntlet's, one hit per
  shot that strikes a living opponent, and one each for a missile's direct
  hit and its splash.
- Impressives, excellents and gauntlet frags.
- A frags medal each time the career total passes another hundred.
- Perfect: first place alone without a death.

As `UI_LogAwardData` does, the totals are kept across matches in
`~/.quakepassion-awards.txt`. Accuracy is not saved in snapshots.

`tests/arena_match_tests.jac` covers the ranking, the award rules and the
menu's phases and buttons. `scripts/arena_screens_smoke.jac` captures the
scoreboard and the three postgame phases on q3dm7.

## Limits

Map-wide routing, weapons, per-bot characters, skill levels and awards are
covered in [Q3 bot tactics](bot-tactics-status.md). Tournament rules and team
modes (including CTF) remain open. The original
single-player arenas set no time limit.
