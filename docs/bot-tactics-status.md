# Q3 bot tactics

Q3 arena bots navigate, choose goals and weapons, fight and chat with the
original bots' own data: maps provide their botlib AAS navigation files, and
bots their botlib characters, fuzzy item and weapon weights and chats. The AI
follows `ai_dmnet.c` and `ai_dmq3.c`, travel `be_ai_move.c`, goals
`be_ai_goal.c` and chat `ai_chat.c`.

## Map-wide navigation

- `maps/<map>.aas` is parsed by `engine/formats/aas.jac`. It supplies the areas,
  the reachabilities with their travel types and times (and, for movers, the
  mover's model and a bobbing platform's two ends), and the point-location
  tree.
- The AAS becomes a graph (`engine/world/bot_routes.jac`). Every area is a
  `NavArea` node and every reachability a `Passage` node, linked as
  `NavArea -Exits-> Passage -Enters-> NavArea`.
- A `TravelTimes` walker relaxes travel times outward from a goal area, and the
  results are cached per goal and per set of travel flags, like botlib's
  routing caches (`be_aas.h` `TFL_*`, `AAS_UpdateAreaRoutingCache`). A passage
  needs its travel type's flag and the flag of the contents of the area it
  enters (air, water, lava, slime, do-not-enter).
  - Bots route with `TFL_DEFAULT`, adding rocket jumps when
    `BotCanAndWantsToRocketJump` holds (a rocket launcher and 3 rockets, no
    quad, 60 health, 90 or 40 armor, weapon jumping 0.5 or more; in the
    seek, fight, chase and nearby-goal nodes) and lava and slime when in it.
  - Tables for a new goal or flag set build in the background; until a
    rocket-jump table is ready a bot routes without rocket jumps.
- Bots travel their routes every frame (`engine/world/bot_travel.jac`, after
  `be_ai_move.c` `BotMoveToGoal`), returning a `bot_moveresult_t`:
  - Walking, crouching, barrier jumps, jumps, ledges, swimming, water jumps,
    teleporters and jump pads head for the passage's points; a jump launches
    from its takeoff with Q3's 270 units/s jump.
  - **Rocket jumps** (`BotTravel_RocketJump`): the bot selects the rocket
    launcher, walks to the start looking straight down (slowing within 80
    units), and within 5 units and 5 degrees of the view jumps, fires and runs
    for the far end at full speed. Its own rocket's splash throws it (Q3
    knockback before the halving), and it steers for its landing through the
    air (`BotFinishTravel_WeaponJump`, `BotAirControl`). BFG jumps work alike
    (never used: bots never set `TFL_BFGJUMP`, as in Q3).
  - **Elevators** (`BotTravel_Elevator`): wait at the start until the plat is
    down, step onto its middle, ride it, and step off once within a step of
    the far end.
  - **Bobbing platforms** (`BotTravel_FuncBobbing`): wait until the
    platform's centre is within 16 units of this passage's near end, board it,
    stand on its middle, and walk off once it is within 24 units of the far
    end. A bot on a mover keeps its passage (the special elevator case).
  - **Ladders** (`BotTravel_Ladder`): face up or down the ladder and move.
  - A passage is done once the bot enters its target area, and fails after
    `BotReachabilityTime` (5 s; 6 for ladders and weapon jumps; 10 for
    movers and jump pads), so the route is planned again.
- `scripts/aas_smoke.jac` sets up the level items as bots do and plans a
  route from every spawn point and resting item to every spawn point and item
  goal, with `TFL_DEFAULT` and with rocket jumps:

  | Map | Routes | With rocket jumps | Taking a rocket jump | Riding a mover |
  | --- | --- | --- | --- | --- |
  | q3dm1 | 536/536 | 536/536 | 0 | 0 |
  | q3dm7 | 4490/4490 | 4490/4490 | 236 | 0 |
  | q3dm17 | 1204/1236 | 1236/1236 | 30 | 0 |
  | q3tourney2 | 1362/1362 | 1362/1362 | 0 | 0 |
  | q3dm19 | 1064/1064 | 1064/1064 | 0 | 644 |
  | q3dm14 | 5498/5498 | 5498/5498 | 388 | 202 |
  | q3tourney6 | 759/759 | 759/759 | 6 | 262 |

  - The old count on q3dm17 (566/992) routed to the floating items over the
    void. Their goal is the jump pad whose throw carries a bot through them
    (`AAS_BestReachableFromJumpPadArea`), as for Q3's bots; 32 routes there
    still need a rocket jump.
  - q3tourney6's mega health lies in an AAS area nothing reaches, so bots
    never choose it (its travel time is 0), as in Q3.
- `scripts/bot_travel_types_smoke.jac` runs bots on q3dm19, q3tourney6 and
  q3dm17 (armed for rocket jumps there) with the movers ticking and counts the
  mover rides and rocket jumps they set out on and finish.

## Bot files (`engine/formats/botscript.jac`, `botconfig.jac`, `games/botfiles.jac`)

- Every bot file goes through botlib's precompiler (`l_script.c`,
  `l_precomp.c`): includes, `#define` with parameters, `#ifdef`/`#ifndef`/
  `#if`/`#else`, and `$evalint`/`$evalfloat`, evaluated as
  `PC_EvaluateTokens` does. A float's integer value is truncated first, so
  `fw_weap.c`'s `$evalint(W_LIGHTNING*0.1)` makes the lightning gun weigh 0
  beyond 768 units.
- `be_ai_weight.c` fuzzy weights: `weight "name" { switch(INVENTORY_X) {
  case N: ... default: ... } }` trees and `balance(w, min, max)` weights.
  `FuzzyWeight` takes the case above the inventory value (botlib's blend
  between cases scales by an integer that is always 0), and
  `FuzzyWeightUndecided` draws a balanced weight within its range.
- `items.c` (the items bots know, their respawn times and boxes), `weapons.c`
  (weapon names by number), each character's `_i.c` and `_w.c` weights,
  `_t.c` chats and `rnd.c`'s random strings.
- `scripts/bot_files_smoke.jac` loads every bot's files from the game's pk3s.

## Characters

- `games/botfiles.jac` reads each bot's `aifile` (`botfiles/bots/*_c.c`).
  - It uses the exact skill block, or interpolates float characteristics between
    skills 1 and 4 (or 4 and 5), as `be_ai_char.c` does.
  - Missing characteristics come from `bots/default_c.c`.
  - Each character loads its item and weapon weights and chat
    (`CHARACTERISTIC_ITEMWEIGHTS`, `_WEAPONWEIGHTS`, `_CHAT_FILE`, `_CHAT_NAME`).
- The skill setting has five steps, Q3's five: Easy → I Can Win, Normal →
  Bring It On (`g_spSkill`'s default), Hard → Hurt Me Plenty, Nightmare →
  Hardcore, and a fifth step, Nightmare!, which Q1 and Q2 play as Nightmare.
  The settings menu shows both names and plays `sound/misc/nightmare.wav` on
  choosing Nightmare! in Q3 (`ui_spskill.c`).
  - Nightmare! bots use their characters' own skill 5 blocks, without a
    handicap.
- `G_AddBot`'s handicap applies: 50, 70 and 90 at skills 1-3. It is the bot's
  maximum health (it spawns with 25 more), caps its health pickups, and scales
  the damage it deals.
- Characteristics used: aim skill and accuracy (including per weapon), reaction
  time (clamped to a second, as `BotCheckAttack` reads it), fire throttle,
  view factor and maximum turn rate, attack skill, jumper, croucher, weapon
  jumping, alertness and the chat tendencies.

## Goals (`engine/world/bot_goals.jac`)

- `be_ai_goal.c` `BotInitLevelItems`: every map item `items.c` knows is a
  `LevelItem` node under the world's `BotItems`, with the AAS area a bot goes
  to: the area of a player's box dropped from it, or for an item floating
  clear of the ground the jump pad that throws a bot through it. A floating
  item no pad reaches is no goal.
- An item is a goal once it has been seen (a powerup not before it first
  appears). Bots do not know when another player took an item: they go for
  it and give up on seeing its spot empty (`BotItemGoalInVisButNotVisible`).
- Items thrown by dying players become level items once they come to rest,
  for 30 seconds, unless they lie on a jump pad (`BotUpdateEntityItems`).
- `BotChooseLTGItem` and `BotChooseNBGItem` are `ChooseItemGoal` walks over the
  level items: each is rated by the character's fuzzy item weight over the
  bot's inventory (drawn within its balance range, `FuzzyWeightUndecided`,
  plus 1000 for a dropped item), divided by the travel time times 0.01. Items
  the bot still avoids longer than the trip takes are skipped.
  - A chosen item is avoided for its respawn time (at least 10 s, 30 s without
    one; 10 s if dropped). Touching an item goal avoids it likewise.
  - A nearby goal must be within its travel time (150 hundredths of a second)
    and leave the long-term goal no further than from here.
  - Goals are kept on the bot's goal stack; a long-term goal is renewed every
    20 s, when reached, or when there is none (with no goal left, the avoid
    times are reset).

## AI (`engine/world/bot_ai.jac`, `ai_dmnet.c`)

- The AI's states are nodes of a graph under the world's `BotBrain`, linked by
  `Leads` edges wherever `ai_dmnet.c` switches: Seek_LTG, Seek_NBG,
  Battle_Fight, Battle_Chase, Battle_Retreat, Battle_NBG, Stand and Respawn.
  Each think (10 Hz) a `BotThink` walker enters the bot's node and runs it; a
  node that switches walks on and runs the next at once, up to 50 switches.
- Before the nodes run, the think updates the bot's inventory for its fuzzy
  weights (`BotUpdateInventory`, and in battle the enemy's distance and
  height) and reads the obituaries every client hears (`BotCheckSnapshot`):
  what it killed and how, what killed it, and whether its enemy killed itself.
- **Seek_LTG**: random chats, a taunt now and then just after a kill
  (`EA_Gesture`: the torso gesture and the model's taunt sound), a visible
  enemy (fight, or retreat when `BotWantsToRetreat`), the long-term goal, and
  every half second a nearby goal within 150.
- **Seek_NBG**: the nearby goal for 4 + 1.5 s, then back to the long-term
  goal.
- **Battle_Fight**: a better (closer) enemy, the enemy's death (after a
  second, the kill chat or back to seeking), hit chats, out of sight → chase
  (`BotWantsToChase`) or seek, the weapon (`BotChooseWeapon` by fuzzy weights),
  `BotAttackMove`, `BotAimAtEnemy`, `BotCheckAttack`, and retreat when
  outgunned (not in a suicidal fight).
- **Battle_Chase**: to where the enemy was last seen (in an AAS area with
  reachabilities), aiming there for two seconds, for up to 10 s or until
  touched, with nearby goals within 150 (16 s to take one).
- **Battle_Retreat**: along the long-term goal, aiming back above 0.3 attack
  skill (below it the bot looks where it goes), shooting when it can, chasing
  once keen again, giving up after 4 s out of sight; with no goal to retreat
  to it fights it out (`AIEnter_Battle_SuicidalFight`). Nearby goals get 2.5 s.
- **Battle_NBG**: the nearby goal while keeping the enemy in its sights.
- **Stand**: standing still while typing a chat line, then saying it.
- **Respawn**: the death chat (typed while dead), then back in once the game
  lets the bot respawn (1.7 s after death at the soonest).
- Enemies are found by the combat tick's `BotFindEnemy` look (below), which
  the nodes take as their enemy.

## Chat (`engine/world/bot_chat.jac`, `ai_chat.c`)

- Bots say their characters' own lines: `game_enter` within 8 s of entering,
  `kill_*` (gauntlet, rail, telefrag, else insult or praise) a second after a
  kill, `death_*` (drown, lava, cratered, suicide, telefrag, gauntlet, rail,
  BFG, insult, praise) while dead, `enemy_suicide`, `hit_talking` (hurt while
  typing), `hit_nodeath`, `hit_nokill`, and `random_insult`/`random_misc`.
- Each chat needs the character's tendency (`CHARACTERISTIC_CHAT_*`, halved
  for the hit chats), 25 s since the bot last chatted, someone to hear it, and
  for most a position to type in: no powerup running, standing on the world,
  and no enemy in sight.
- Lines are built from text, their variables (names as `EasyClientName`
  writes them: lower case, no spaces, clan tags or "Mr") and `rnd.c`'s random
  strings, expanded up to ten deep; a line said in the last 20 s is not
  chosen again while others are fresh.
- A bot types for two seconds (`BotChatTime`), then the line is said:
  "Name: text" with the text in green (`G_Say`), shown in the notify lines
  with Q3's colour codes, with `sound/player/talk.wav`.

## Combat (`engine/world/bot_tactics.jac`)

- **Arming:** bots spawn and respawn with a gauntlet, machine gun and 100
  bullets (`ClientSpawn`). They pick weapons, ammo and everything else up like
  players, going for them by their item weights.
- **Weapon choice:** `BotChooseBestFightWeapon` over the character's fuzzy
  weapon weights (`fw_weap.c` and the character's `_w.c`: none without the
  weapon or its ammo; the lightning gun 0 beyond 768 units). The lowest weapon
  number wins a tie; no switch while a weapon is being raised or lowered.
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
- **Firing** (`BotCheckAttack`, in Battle_Fight, Battle_Retreat and
  Battle_NBG): a bot waits out its reaction time and the fire throttle, fires
  only when the target is within its field of fire (50°, or 120° up close)
  and in sight, uses the gauntlet only within 60 units, and holds a splash
  weapon whose shot would burst within its radius short of the enemy.
- **Shots:** real weapon rules.
  - Hitscan pellets are summed per victim, and rails and lightning draw their
    beams.
  - Rockets, grenades, plasma and BFG shots are owned projectiles, so a bot's
    splash can hurt itself and cost a frag.
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
  and handicap, fuzzy weapon choice, view turning, aggression, attack moves,
  reaction and fire, projectiles.
- `tests/bot_script_tests.jac`: the precompiler (macros, `$eval`, includes),
  fuzzy weights, item and weapon configs, chat construction and characters
  loading their bot files.
- `tests/bot_travel_tests.jac`: travel flags in the tables (rocket jumps,
  lava), rocket jump travel and air control, bobbing platforms waited for,
  boarded, ridden and left, and leg timeouts.
- `tests/bot_ai_tests.jac`: goals by fuzzy weight over travel time with avoid
  times and nearby goals, the node graph, fighting, suicidal fights,
  retreating (aiming back only above 0.3 attack skill), chasing, the kill
  chat after standing to type, and the death chat before respawning.
- `tests/arena_navigation_tests.jac`: item and teleporter contacts, and
  floating items' jump pad goals.
- `scripts/bot_files_smoke.jac`, `scripts/aas_smoke.jac` and
  `scripts/bot_travel_types_smoke.jac` (above).
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
- Team play (team goals, team chat and voice chat), camping (`BotWantsToCamp`:
  Q3's maps have no camp spots), air goals (`BotGoForAir`), reply chats
  (`BotReplyChat`), the avoid-reachability list (`BotAddToAvoidReach`) and
  obstacle handling (`BotAIPredictObstacles`, `BotAIBlocked`) are not
  modelled. Bots route around blocked doors as the combat tick steers.
- Bots do not know when they are in water, lava or slime (their liquid
  state is not sampled), so `BotInLavaOrSlime` and the chat position's
  liquid tests do not apply.
- The chat balloon over a typing bot (`EF_TALK`, `sprites/balloon3`) is not
  drawn.
- The end-of-match and level-start chats (`BotChat_EndLevel`,
  `BotChat_StartLevel`) are not said: the match ends into the podium.
- Dropped items fly as `Drop_Item` throws them (see Items).
