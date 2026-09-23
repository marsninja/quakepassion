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
- The game's four skills map onto Q3's five: Easy → Bring It On, Normal → Hurt
  Me Plenty, Hard → Hardcore, Nightmare → Nightmare!
- Characteristics used: aim skill and accuracy (including per weapon), reaction
  time, fire throttle, view factor and maximum turn rate, attack skill, jumper
  and alertness.

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
  - Accuracy adds the original 20/20/10-unit random error.
  - Aim is worse at an enemy that just changed direction.
- **Turning:** `BotChangeViewAngles`. The view turns by the remaining angle
  times the view factor, capped at the character's maximum turn rate.
- **Firing** (`BotCheckAttack`): a bot waits out its reaction time and the fire
  throttle, fires only when the target is within its field of fire (50°, or
  120° up close), and uses the gauntlet only within 60 units.
- **Shots:** real weapon rules.
  - Hitscan pellets are summed per victim, and rails and lightning draw their
    beams.
  - Rockets, grenades, plasma and BFG shots are owned projectiles, so a bot's
    splash can hurt itself and cost a frag.
- **Movement** (`BotAttackMove`): bots keep the ideal attack distance, strafe
  with attack skill (never off a ledge), and jump as their jumper
  characteristic likes.
- **Finding enemies** (`BotFindEnemy`): the search range grows with alertness.
  A new enemy must be inside a 90° view unless it is close or firing.

## Awards

- **Excellent:** two frags within 3 s.
- **Impressive:** two railgun hits in a row.
- **Humiliation:** a gauntlet frag.
- **Perfect:** a win without dying.

Each plays the original announcer sound, and counts are kept on the
competitor's `Competes` edge.

Saves keep each bot's weapon, ammo and holdables (`BOTARM`/`BOTITEM`).

## Validation

- `tests/bot_tactics_tests.jac`: character parsing and interpolation, weapon
  choice, turn limits, reaction and fire, projectiles.
- `tests/arena_match_tests.jac`: awards.
- `tests/savegame_tags_tests.jac`: bot inventories.
- `scripts/bot_combat_smoke.jac`: bots on q3dm7, q3dm6 and q3tourney2 load their
  characters, collect railguns, plasma guns and rocket launchers, and frag each
  other.

## Limits

- Bots always show the machine gun model; the held weapon is not swapped yet.
- Rocket jumps, the team chat and taunts, item weights beyond simple needs, and
  the podium intermission remain open.
