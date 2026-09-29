# Q3 bot tactics

Q3 arena bots navigate, choose goals and weapons, fight and chat from the
original bots' own data: each map's botlib AAS file, and each bot's botlib
character, fuzzy item and weapon weights and chat file. The AI follows
`ai_dmnet.c` and `ai_dmq3.c`, travel follows `be_ai_move.c`, goals
`be_ai_goal.c` and chat `ai_chat.c`. Bots move by Q3's own pmove profile
(`movement_profile("q3")`, `CombatTick.bot_profile` in
`engine/world/combat.jac`).

Match rules, scoring, awards and item drops are in
[Q3 arena matches](arena-match-status.md); bodies are in
[Q3 player bodies](player-bodies-status.md).

## Routing (`engine/formats/aas.jac`, `engine/world/bot_routes.jac`)

- `maps/<map>.aas` supplies the areas, reachabilities (travel type and time,
  a mover's model, a bobbing platform's two ends) and the point-location tree.
- The AAS becomes a graph: every area is a `NavArea` node and every
  reachability a `Passage` node, linked `NavArea -Exits-> Passage -Enters->
  NavArea`.
- A `TravelTimes` walker relaxes travel times outward from a goal area. Tables
  are cached per goal and per travel-flag set (`be_aas.h` `TFL_*`,
  `AAS_UpdateAreaRoutingCache`) and built a budget at a time in the
  background; until a flagged table is ready the `TFL_DEFAULT` one is used.
  A passage needs its travel type's flag and the contents flag of the area it
  enters (air, water, lava, slime, do-not-enter).
- Travel flags per think (`bot_travel_flags`, `engine/world/bot_character.jac`):
  `TFL_DEFAULT`, plus lava and slime while in them (`BotInLavaOrSlime`), plus
  rocket jumps when `BotCanAndWantsToRocketJump` holds (rocket launcher and 3
  rockets, no quad, 60 health and either 90 health or 40 armor, weapon
  jumping at least 0.5). Bots never set `TFL_BFGJUMP`, as in Q3.
- A map without an `.aas` file falls back to the shared bounded local
  navigation (`engine/world/navigation.jac`).

## Travel (`engine/world/bot_travel.jac`)

Each frame a bot follows its route (`BotMoveToGoal`) and gets a
`bot_moveresult_t` (`TravelResult`): direction and speed, jump, attack, the
weapon the movement needs, a movement view, waiting and failure.

- Walk, crouch, barrier jump, jump, walk off ledge, teleport and jump pad head
  for the passage's points; a jump launches from its takeoff at 270 units/s.
- Swim (`BotTravel_Swim`): with the waist under, straight for the waypoint in
  three dimensions, looking where it swims (`MOVERESULT_SWIMVIEW`).
- Water jump (`BotTravel_WaterJump`): swim for the far end looking 15 units
  above it; `PM_CheckWaterJump` lifts the bot out.
- Rocket and BFG jump (`BotTravel_RocketJump`, `BotFinishTravel_WeaponJump`,
  `BotAirControl`): select the weapon, walk to the start looking straight
  down, and within 5 units and 5 degrees jump and fire; the bot's own splash
  throws it and it steers for the landing.
- Elevator (`BotTravel_Elevator`): wait until the plat is down, step to its
  middle, ride, and step off within a step (32 units) of the far end.
- Bobbing platform (`BotTravel_FuncBobbing`): wait until its centre is within
  16 units of the near end, board and stand on its middle, and walk off within
  24 units of the far end. A bot on a mover keeps its passage.
- Ladder (`BotTravel_Ladder`): face up or down the ladder and move.
- A passage fails after `BotReachabilityTime` (5 s; 6 for ladders and weapon
  jumps; 10 for elevators, jump pads and bobbing platforms) and the route is
  replanned.

## Bot files (`engine/formats/botscript.jac`, `engine/formats/botconfig.jac`, `engine/world/bot_weights.jac`, `games/botfiles.jac`)

- Every bot file goes through botlib's precompiler (`l_script.c`,
  `l_precomp.c`): includes, parameterised `#define`, `#if`/`#ifdef`/`#else`,
  and `$evalint`/`$evalfloat` as `PC_EvaluateTokens` computes them (so
  `fw_weap.c`'s `$evalint(W_LIGHTNING*0.1)` makes the lightning gun weigh 0
  beyond 768 units).
- `be_ai_weight.c` fuzzy weights: `switch`/`case` trees over inventory values
  and `balance(w, min, max)`. `FuzzyWeight` takes the case above the value;
  `FuzzyWeightUndecided` draws a balanced weight within its range.
- `items.c`, `weapons.c`, each character's `_i.c`, `_w.c` and `_t.c`, and
  `rnd.c` load from the game's pk3s.

## Characters (`games/botfiles.jac`, `engine/world/bot_character.jac`)

- Each bot's `aifile` is read with its exact skill block, or with float
  characteristics interpolated between skills 1 and 4 (or 4 and 5) as
  `be_ai_char.c` does; missing ones come from `bots/default_c.c`.
- Skill has Q3's five steps (I Can Win, Bring It On, Hurt Me Plenty,
  Hardcore, Nightmare!); Q1 and Q2 play the fifth as Nightmare. The menu shows
  both names and plays `sound/misc/nightmare.wav` for Nightmare! in Q3.
- `G_AddBot`'s handicap (50, 70, 90 at skills 1-3) is the bot's maximum
  health (it spawns with 25 more), caps its health pickups and scales its
  damage.
- Characteristics used: aim skill and accuracy (also per weapon), reaction
  time (clamped to 1 s), fire throttle, view factor and maximum turn rate,
  attack skill, jumper, croucher, weapon jumping, alertness and the chat
  tendencies.

## Goals (`engine/world/bot_goals.jac`)

- `BotInitLevelItems`: every map item `items.c` knows is a `LevelItem` node
  under the world's `BotItems`, with the AAS area a bot goes to: the area
  under the item or, for an item floating clear of the ground, the jump pad
  whose throw carries a bot through it (`AAS_BestReachableFromJumpPadArea`).
  A floating item no pad reaches is no goal.
- An item is a goal once seen (a powerup not before it first appears). Bots
  do not know when an item was taken; they give up on seeing its spot empty
  (`BotItemGoalInVisButNotVisible`). Dropped items become goals once at rest,
  for 30 s, unless on a jump pad (`BotUpdateEntityItems`).
- `BotChooseLTGItem` / `BotChooseNBGItem` are `ChooseItemGoal` walks: fuzzy
  item weight over the bot's inventory (plus 1000 for a dropped item) divided
  by travel time × 0.01, skipping items still avoided. A chosen or touched item
  is avoided for its respawn time (at least 10 s; 30 s without one).
- Nearby goals must be within 150 hundredths of a second of travel and leave
  the long-term goal no further away. The long-term goal is renewed every
  20 s, when reached, or when there is none.

## AI nodes (`engine/world/bot_ai.jac`)

- The `ai_dmnet.c` states are nodes under the world's `BotBrain`, linked by
  `Leads` edges wherever the original switches: Seek_LTG, Seek_NBG,
  Battle_Fight, Battle_Chase, Battle_Retreat, Battle_NBG, Stand, Respawn and
  Intermission.
- Each think (`bot_thinktime` 0.1 s) a `BotThink` walker enters the bot's node
  and runs it; a switch walks on and runs the next node at once, up to
  `MAX_NODESWITCHES` (50). Each bot keeps its own think phase, so thinks are
  staggered across frames.
- Before the nodes: `BotUpdateInventory` (with enemy distance and height in
  battle), `BotCheckSnapshot` (the obituaries every client hears) and
  `BotCheckAir`.
- Seek_LTG: random chats, occasional taunts after a kill (`EA_Gesture`), a
  visible enemy (fight, or retreat if `BotWantsToRetreat`), the long-term
  goal, and a nearby goal every half second.
- Seek_NBG: the nearby goal for 4 + 1.5 s, then back to the long-term goal.
- Battle_Fight: a better enemy, the enemy's death (kill chat), hit chats,
  lost sight (chase or seek), `BotChooseWeapon`, `BotAttackMove`,
  `BotAimAtEnemy`, `BotCheckAttack`, and retreat when outgunned; with no goal
  to retreat to, `AIEnter_Battle_SuicidalFight`.
- Battle_Chase: to where the enemy was last seen, for up to 10 s.
- Battle_Retreat: along the long-term goal, aiming back above 0.3 attack
  skill, giving up after 4 s out of sight.
- Battle_NBG: the nearby goal while keeping the enemy in sight.
- Stand: typing a chat line. Respawn: the death chat, then respawn (1.7 s
  after death at the soonest).
- Intermission (`BotIntermission`): at the match's end the bot forgets goals
  and enemy and may say its end-of-level line. Bots think on over the podium
  but do not move or act (`ClientIntermissionThink`). A new level or the
  warmup's `map_restart` sets bots up afresh (`BotAISetupClient`,
  `BotResetState`), so they start seeking at FIGHT!.

## Liquids and air (`engine/world/wading.jac`)

- `ImmerseBots` samples each bot's immersion every tick through
  `Level.immersion` (`PM_SetWaterLevel`): water level, worst liquid and
  current. Bots swim by it, and drown and burn in lava and slime as the player
  does (`P_WorldEffects`).
- `BotGoForAir` (first in `BotNearbyGoal`): after 6 s without air a bot heads
  for the surface above it (`BotGetAirGoal`, using `TraceLiquid`), or else the
  nearby item out of the liquid.
- `BotValidChatPosition`: no chatting with lava or slime at the feet or liquid
  over the head.

## Chat (`engine/world/bot_chat.jac`)

- Lines from the character's chat file: `game_enter` (within 8 s),
  `kill_*`, `death_*`, `enemy_suicide`, `hit_talking`, `hit_nodeath`,
  `hit_nokill`, `random_insult`/`random_misc`, and `level_end_victory`,
  `level_end_lose` and `level_end` at the match's end (`BotChat_EndLevel`).
  `level_start` fires only when an intermission ends within a level.
- Each chat needs the characteristic's tendency, 25 s since the bot last
  chatted (`TIME_BETWEENCHATTING`), a listener and usually a valid chat
  position. Names are written as `EasyClientName` does; `rnd.c` strings
  expand up to ten deep; a line said in the last 20 s is avoided.
- A bot types for 2 s (`BotChatTime`), holding `BUTTON_TALK`, with the talk
  balloon (`EF_TALK`, `sprites/balloon3`) over it; then "Name: text" is said
  with `sound/player/talk.wav`. End-of-level lines go out at once and show in
  the notify lines over the podium.

## Combat (`engine/world/bot_tactics.jac`, `engine/world/combat.jac`)

- Bots spawn with gauntlet, machine gun and 100 bullets (`ClientSpawn`) and
  pick up items as players do.
- Weapon: `BotChooseBestFightWeapon` over the fuzzy weapon weights; ties go to
  the lower weapon number; no switch while raising or lowering.
- Aim (`BotAimAtEnemy`): projectiles lead the enemy when aim skill allows,
  splash weapons aim at a grounded enemy's feet, the 20/20/10-unit random
  error scales with accuracy, and aim is worse just after the enemy changes
  direction.
- View (`BotChangeViewAngles`): stepped every 50 ms and interpolated between;
  the character's view factor and turn rate in battle, 0.05 and 360°/s
  otherwise. Roaming bots look 300 units along the route
  (`BotMovementViewTarget`).
- Firing (`BotCheckAttack`): after the reaction time and fire throttle, within
  the field of fire (50°, or 120° within 100 units), the gauntlet only within
  60 units, and never when a splash shot would burst within its radius.
- Movement (`BotAttackMove`): below 0.2 attack skill, stand; below 0.4, only
  close or open the distance; above, strafe (flipping after 0.4-0.6 s at 6.5%
  per think, or when blocked), jump by `jumper` at most once a second, and
  crouch by `croucher` at a quarter speed.
- Enemies (`BotFindEnemy`): range 900 + 4000 × alertness; a new enemy must be
  inside a view widening from 90° to 180° unless the bot was hurt or the enemy
  is firing; only a closer enemy replaces the current one; sight tests the
  middle, bottom and top of the box. The reaction time runs from finding the
  enemy (`enemysight_time`), not from each glimpse.

## Validation

Tests:
- `tests/bot_tactics_tests.jac`: characters and interpolation, weapon choice,
  view turning, retreat, reaction and fire, projectiles, attack moves,
  `BotFindEnemy`.
- `tests/bot_script_tests.jac`: precompiler, fuzzy weights, item and weapon
  configs, chat construction, character loading.
- `tests/bot_travel_tests.jac`: travel flags, rocket jumps, bobbing
  platforms, swimming and water jumps.
- `tests/travel_table_tests.jac`: budgeted tables, one-way passages.
- `tests/bot_ai_tests.jac`: goal choice and avoid times, the node graph,
  fighting, suicidal fights, retreat, chase, kill/death/end-of-level chats,
  seeking after the warmup, intermission lines, going for air.
- `tests/liquid_tests.jac` (bot immersion, `TraceLiquid`),
  `tests/effect_quads_tests.jac` (talk balloon),
  `tests/arena_navigation_tests.jac` (pickups, teleports, jump pad goals),
  `tests/bot_spawn_area_tests.jac`, and `tests/savegame_tags_tests.jac` (bot
  inventories, `BOTARM`/`BOTITEM`).

Scripts (native, need the Q3 assets):
- `scripts/bot_files_smoke.jac`: loads every bot's files.
- `scripts/aas_smoke.jac`: plans a route from every spawn point and resting
  item to every spawn point and item goal, with `TFL_DEFAULT` and with rocket
  jumps. Run of 2026-09-28:

  | Map | Routes | With rocket jumps | Taking a rocket jump | Riding a mover |
  | --- | --- | --- | --- | --- |
  | q3dm1 | 536/536 | 536/536 | 0 | 0 |
  | q3dm7 | 4490/4490 | 4490/4490 | 236 | 0 |
  | q3dm17 | 1204/1236 | 1236/1236 | 30 | 0 |
  | q3tourney2 | 1362/1362 | 1362/1362 | 0 | 0 |
  | q3dm19 | 1064/1064 | 1064/1064 | 0 | 644 |
  | q3dm14 | 5498/5498 | 5498/5498 | 388 | 202 |
  | q3tourney6 | 759/759 | 759/759 | 6 | 262 |

  The 32 q3dm17 routes that need a rocket jump go to floating items. The
  q3tourney6 mega health lies in an AAS area nothing reaches, so bots never
  choose it, as in Q3.
- `scripts/bot_travel_types_smoke.jac`: counts mover rides and rocket jumps
  started and finished on q3dm19, q3tourney6 and q3dm17.
- `scripts/bot_rocket_jump_smoke.jac`: a bot on q3dm17 rocket-jumps to the
  mega health.
- `scripts/bot_travel_smoke.jac`: map coverage with AAS (`QP_NO_AAS=1`
  compares local routing).
- `scripts/bot_combat_smoke.jac`, `scripts/bot_fire_probe.jac`: bots arm,
  fight and frag; per-bot battle node, sight, aim and shots.
- `scripts/bot_frag_run.jac` (`QP_SKILL`, `QP_SECONDS`, `QP_SEED`,
  `QP_MAPS`): frags, deaths, shots, areas covered and time per battle node.
  One run on 2026-09-28 at Hurt Me Plenty: 19 frags on q3dm7, 29 on q3dm6 and
  20 on q3dm12, with 36 chat lines. Bots spent about half their time seeking,
  a fifth to a third retreating (the handicap keeps their health under
  `BotAggression`'s marks), and the rest fighting and chasing. Single runs
  vary widely.
- `scripts/bot_think_profile.jac`: the bots' share of a 120 Hz tick, 30 s at
  Hurt Me Plenty, ms per tick (2026-09-28):

  | Map | Bots | Navigation | Doors | Combat (moves, routes, enemy looks) | Bots (AI, view, trigger) | Worst tick |
  | --- | ---: | ---: | ---: | ---: | ---: | ---: |
  | q3dm12 | 6 | 0.18 | 0.30 | 11.6 | 3.0 | 57 |
  | q3dm7 | 4 | 0.62 | 0.12 | 6.7 | 1.2 | 36 |
- `scripts/q3dm12_live_player_crash_repro.jac` (`QP_MAPS`, `QP_SECONDS`):
  a headless soak of arenas with bots and a live player, timing the walkers.
  It is the repro for the intermittent native SIGBUS/SIGSEGV once seen in
  arenas with bots (q3dm12, q3dm7, q3dm1, q3dm17). The crash was two jac
  runtime defects: the item pickup walker's suffix string views stored in a
  list, which the cycle collector then wrote into (jaseci-labs/jac#9634), and
  a collection started inside a destructor when the asset library closed
  (#9639); see [jac-native-fixes.md](jac-native-fixes.md). With the pinned
  compiler (2026-09-29) q3dm12 ran to frame 3000 clean 3 times out of 3,
  q3dm7, q3dm1 and q3dm17 to frame 1500 clean, and the soak ran q3dm12 for
  5400 ticks clean 3 times out of 3.

## Limitations

- Not modelled: team play (team goals, team and voice chat), camping
  (`BotWantsToCamp`), reply chats (`BotReplyChat`), the avoid-reachability
  list (`BotAddToAvoidReach`), and obstacle handling
  (`BotAIPredictObstacles`, `BotAIBlocked`).
- Every arena is free-for-all, so bots chat in the tier finals too; Q3 keeps
  them quiet in `GT_TOURNAMENT`.
- `BotTravel_WaterJump` looks a fixed 15 units above the far end; Q3 adds up
  to ±40 units at random.
