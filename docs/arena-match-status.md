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
- **F1** shows the scoreboard, which also appears during the countdown, while
  dead and at match end. At the end, **Enter** advances a winner to the next
  ladder arena, or starts a rematch otherwise.
- The level menu lists Q3's ladder first (training, tiers, final), with arena
  names and the best finish from `~/.quakepassion-arena.txt`.
- Bot characters are baked from their own models and skins and now include
  `BOTH_DEATH1`, so fallen bots play their death sequence.

Snapshot format **19** stores the match clock, countdown, lead state and every
competitor's frags and deaths.

## Jac fixes found on the way

The Competes edge names exposed a native Jac defect: attributes given in a typed
connect (`a +>:Competes:name=n:+> b`) were dropped. It is fixed upstream; see
[native compiler dependencies](native-lighting-validation-blockers.md).

## Limits

Bots still use the prototype machine-gun attack and simple item goals. Weapon
choice, per-bot characteristics from `botfiles/bots/*_c.c`, skill levels,
awards (Excellent, Impressive, Humiliation), the podium intermission, time limits,
tournament rules and team modes (including CTF) remain open.
