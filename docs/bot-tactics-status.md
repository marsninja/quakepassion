# Q3 bot tactics

Q3 arena bots now navigate, arm themselves and fight with the original bots'
own data. Maps provide their botlib AAS navigation files, and bots their botlib
character and weapon-weight files. Each bot's AI follows `ai_dmq3.c`.

## Map-wide navigation

- `maps/<map>.aas` is parsed by `engine/formats/aas.jac`. It supplies the areas,
  the reachabilities with their travel types and times, and the point-location
  tree.
- The AAS becomes a graph (`engine/world/bot_routes.jac`). Every area is a
  `NavArea` node and every reachability a `Passage` node, linked as
  `NavArea -Exits-> Passage -Enters-> NavArea`.
- A `TravelTimes` walker relaxes travel times outward from a goal area, and the
  results are cached per goal like botlib's routing cache. Bots descend those
  times one passage at a time.
- Bots execute walking, crouching, barrier jumps, jumps, walking off ledges,
  swimming, water jumps, teleporters and jump pads.
  - A passage is complete when the bot enters its target area.
  - Jumps launch from their takeoff point with the original 270 units/s jump.
  - Rocket jumps, ladders, elevators and bobbing platforms are not used.
- Bots follow routes every tick at Q3's 320 units/s. They pick long-term item
  goals anywhere on the map, skip goals the AAS cannot reach, and drop a goal
  they fail to route to.
- `scripts/aas_smoke.jac` plans a route between every pair of spawns and items:

  | Map | Routes found |
  | --- | --- |
  | q3dm1 | 420/420 |
  | q3dm7 | 2162/2162 |
  | q3tourney2 | 930/930 |
  | q3dm17 | 566/992; the rest need rocket jumps |

- `scripts/bot_travel_smoke.jac` compares area coverage over 40 s. A lone bot on
  q3dm1 visits 76 areas, against 13 with the old bounded local router.

## Characters

- `games/botfiles.jac` reads each bot's `aifile` (`botfiles/bots/*_c.c`).
  - It uses the exact skill block, or interpolates float characteristics between
    skills 1 and 4 (or 4 and 5), as `be_ai_char.c` does.
  - Missing characteristics come from `bots/default_c.c`.
  - Weapon weights come from the `W_*` defines in the character's `_w.c` file.
- The skill setting has five steps, Q3's five: Easy → I Can Win, Normal →
  Bring It On (`g_spSkill`'s default), Hard → Hurt Me Plenty, Nightmare →
  Hardcore, and a fifth step, Nightmare!, which Q1 and Q2 play as Nightmare.
  The settings menu shows both names and plays `sound/misc/nightmare.wav` on
  choosing Nightmare! in Q3 (`ui_spskill.c`).
  - Nightmare! bots use their characters' own skill 5 blocks, without a
    handicap. Q3 has no other skill 5 rule: bots respawn 1-2 s after death
    at every skill (`AIEnter_Respawn`).
- `G_AddBot`'s handicap applies: 50, 70 and 90 at skills 1-3. It is the bot's
  maximum health (it spawns with 25 more), caps its health pickups, and scales
  the damage it deals.
- Characteristics used: aim skill and accuracy (including per weapon), reaction
  time, fire throttle, view factor and maximum turn rate, attack skill, jumper,
  croucher and alertness.

## Combat (`engine/world/bot_tactics.jac`)

- **Arming:** bots spawn and respawn with a gauntlet, machine gun and 100
  bullets (`ClientSpawn`). They go after weapons they lack and ammo for guns
  they carry, and pick them up like players.
- **Weapon choice:** `BotChooseBestFightWeapon`. A bot takes the owned, loaded
  weapon with the highest character weight. The lightning gun counts a tenth
  beyond 768 units, and a switch takes the weapon drop and raise time.
- **Aim** (`BotAimAtEnemy`):
  - Projectiles lead the enemy's remembered motion when aim skill allows, and
    splash weapons aim at the floor under a grounded enemy.
  - Accuracy adds the original 20/20/10-unit random error to the aim point.
    The view then turns toward it with up to 0.3 of random error per axis
    below 0.8 accuracy. Instant-hit weapons lose accuracy within 150 units.
  - Aim is worse at an enemy that just changed direction.
- **Turning:** `BotChangeViewAngles`'s "over reaction" model, stepped every
  50 ms server frame and drawn smoothly between frames. Against an enemy it
  uses the character's view factor and maximum turn rate; otherwise a slow
  0.05 and 360 degrees a second.
- **Looking:** in battle, at the aim point. Otherwise, at the point 300 units
  along the route (`BotMovementViewTarget`), so roaming bots face where they
  go.
- **Firing** (`BotCheckAttack`): a bot waits out its reaction time and the fire
  throttle, fires only when the target is within its field of fire (50°, or
  120° up close), and uses the gauntlet only within 60 units.
- **Shots:** real weapon rules.
  - Hitscan pellets are summed per victim, and rails and lightning draw their
    beams.
  - Rockets, grenades, plasma and BFG shots are owned projectiles, so a bot's
    splash can hurt itself and cost a frag.
- **Battle nodes** (`ai_dmnet.c`, simplified), from `BotAggression`:
  - **Fight** when well armed. Movement is `BotAttackMove`.
  - **Retreat** when outgunned (`BotWantsToRetreat`), for example holding only
    the machine gun or hurt without armor. The bot follows its item route,
    aiming and shooting back at a visible enemy. Q3 only aims back above 0.3
    attack skill, but with `G_AddBot`'s handicap a skill 1-2 bot's health stays
    under `BotAggression`'s 60/80 marks, so it would retreat for good and
    never shoot (Ranger on q3dm1 at Normal did not). Every skill aims back
    here.
  - **Nearby goal** (`Battle_NBG`): every second a retreating bot looks for a
    wanted item within 1.5 s of travel and grabs it.
  - **Chase**: an enemy lost from sight is chased to its last position for up
    to 10 s when the bot is keen (`BotWantsToChase`). Otherwise the bot
    returns to its goals.
- **Movement** (`BotAttackMove`):
  - Bots below 0.2 attack skill stand. Up to 0.4 they only close or open the
    distance.
  - Better bots strafe. The direction flips with a 6.5% chance per think after
    0.4-0.6 s, and whenever the way is blocked (a wall or a ledge). They back
    off one think in ten and keep the ideal distance.
  - They jump when `random() < jumper`, at most once a second. They crouch for
    `croucher × 5` s, moving at a quarter speed.
- **Finding enemies** (`BotFindEnemy`):
  - The search range grows with alertness.
  - A new enemy must be inside a view that widens from 90° up close to 180°
    at 810 units. The view is all round when the bot was just hurt or the
    enemy is firing.
  - Only a closer enemy replaces the current one. The bot keeps its enemy
    while a battle node (fight, retreat, nearby goal, chase) has it in
    mind.
  - Sight (`BotEntityVisible`) tests the middle, bottom and top of the
    enemy's box.
- **Reaction** (`enemysight_time`): the reaction time runs from when the
  enemy was found, not from each glimpse. An enemy that replaces a living
  one counts as seen two seconds ago. One found again after the bot went
  back to its goals starts afresh.

## Awards

- **Excellent:** two frags within 3 s.
- **Impressive:** two railgun hits in a row.
- **Humiliation:** a gauntlet frag.
- **Perfect:** a win without dying.

Each plays the original announcer sound, and counts are kept on the
competitor's `Competes` edge.

Saves keep each bot's weapon, ammo and holdables (`BOTARM`/`BOTITEM`).

## Items

- **Drops** (`engine/world/drops.jac`, `TossClientItems`): a dying bot or
  player throws down the weapon it held and every powerup it carried. The
  gauntlet, the machine gun and weapons without ammo stay. A powerup keeps the
  seconds that were left. Dropped items never respawn and are removed after
  30 s. Bots see them as goals.
  - `Drop_Item` throws each item from the body's origin at 150 units/s along
    its angle (the weapon ahead, powerups 45° apart), rising 200 ± 50 units/s.
  - A `Flight` node carries the item under gravity (`TossTick`, `G_RunItem`)
    until it lands a unit above the floor. `LaunchItem` gives dropped items
    no bounce, so one that hits a wall stops there and falls.
- **Item teams** (`G_FindTeams`, `RespawnItem`): items sharing a `team` key
  show one member at a time, and each respawn brings back a random one. This
  covers the teamed armor, powerups and weapons of q3dm3, q3dm8, q3dm10,
  q3dm18, q3tourney1 and q3tourney6.
- The `random` key spreads each respawn by up to that many seconds either way,
  never under one second.
- Saves keep which team member is out. Dropped items are not saved.

## Validation

- `tests/bot_tactics_tests.jac`: character parsing and interpolation, skill
  and handicap, weapon choice, view turning, aggression, battle nodes, attack
  moves, reaction and fire (a retreating bot of every skill 1-5 turns on a
  visible enemy and fires within 3 s), projectiles.
- `scripts/bot_fire_probe.jac` traces each bot's battle node, sight, weapon,
  aim error and shots per half second on q3dm1 (Ranger against the player)
  and q3dm7.
- `tests/item_drop_tests.jac`: item teams, respawn spread, drops and powerup
  shaders.
- `tests/arena_match_tests.jac`: awards.
- `tests/savegame_tags_tests.jac`: bot inventories.
- `scripts/bot_combat_smoke.jac`: bots on q3dm7, q3dm6 and q3tourney2 load their
  characters, collect railguns, plasma guns and rocket launchers, and frag each
  other. Doors tick, so bots open them.
- `scripts/bot_frag_run.jac` plays three minutes of bots against each other
  (`QP_SKILL`, `QP_SECONDS`, `QP_SEED`, `QP_MAPS`). For each bot it prints its
  frags, deaths, shots, areas covered, time in each battle node and time with
  its enemy in sight, and how the frags were made. Average frags per three
  minutes, before and after the `BotFindEnemy` and reaction-time changes:

  | Skill | Seeds | q3dm7 | q3dm6 | q3dm12 | Total |
  | --- | ---: | --- | --- | --- | --- |
  | Bring It On (Normal) | 4 | 13.0 → 16.3 | 10.8 → 14.0 | 9.8 → 14.3 | 33.5 → 44.5 |
  | Hurt Me Plenty (Hard) | 7 | 15.4 → 18.1 | 17.0 → 20.9 | 13.7 → 12.4 | 46.1 → 51.4 |

  Single runs vary widely (q3dm6 at Hurt Me Plenty ranged from 3 to 28).
  Without doors ticking, q3dm12's bots had been shut in behind closed doors.
  At the lower skills most of that time is spent retreating: `G_AddBot`'s
  handicap keeps their health under `BotAggression`'s marks, as in Q3.

## Limits

- Bodies are covered in [Q3 player bodies](player-bodies-status.md).
- Rocket jumps, team chat and taunts, and item weights beyond simple needs
  remain open.
- Dropped items fly as `Drop_Item` throws them (see Items).
