# Campaign and gameplay progress

The completion target is a playable Q1/Q2 campaign and local Q3 arena prototype
with a smaller combat roster first.
Network multiplayer and original-mod execution are outside that first target.
This remains an incomplete game implementation.

## Implemented

- Q2/Q3 crouching changes the collision hull, eye height and movement speed.
  Clearance prevents standing inside a ceiling. Movers, triggers and teleport
  destinations use the same stance. Q1 retains its original standing hull.
- Q1 touch exits and Q2 signal-driven level exits load their destination map.
  Q2 named arrival points (`map$spawn`) are resolved. Asset loading and GPU
  upload finish before the current scene is replaced; failures keep the scene
  usable and show an error in the menu.
- Actor health/armor and inventory slots are shared graph-based gameplay state.
  Campaign transitions carry this state; choosing a map in the menu starts fresh.
- Liquid exposure uses simulation time: twelve seconds of air, escalating
  drowning damage, and game-specific slime/lava intervals. Fly mode is exempt.
  The HUD shows health/armor; Enter restarts the current level after death.
- Health, armor and shell pickups are bound to original map entities and models
  in the normal application loop. Shared walkers handle swept contact, inventory
  limits and hiding consumed items. Q1 replaces armor by protection value, Q2
  salvages armor, and Q3 adds armor and respawns items on simulation time.
  The HUD also displays shells. Menu pause suspends collection and respawning.

The Q2 `train` entity parser now accepts literal backslashes inside quoted
values, including a backslash immediately before the closing quote, matching
original BSP entity tokenization.

## Validation

Crouching fixtures cover low ceilings, standing clearance, curved patch hulls,
overhead triggers, teleport arrivals and moving-platform riders. Native desktop
checks cover Q2 `base1` and Q3 `q3dm1`, including menu pause and stance release.

Exit fixtures cover swept contact, relay activation, paused/fly behavior and
malformed requests. `scripts/validate_exits.jac` resolves real Q1/Q2 destinations
and named spawns. `scripts/exits_smoke.jac` exercises Q1 `e1m1` → `e1m2`,
Q2 `base1` → `base2`, and a failed-load rollback through the native app.

Gameplay fixtures cover armor depletion, bypass damage, death, healing limits,
inventory isolation/capacity, drowning cadence, and liquid damage rates.
Pickup fixtures cover swept contact, crouched reach, full inventory, death/fly
exclusion, arena respawning and armor conversion. `scripts/pickups_app_smoke.jac`
passes real-map loading, paused contact, collection and failed-load rollback in
Q1 `e1m1`, Q2 `base1` and Q3 `q3dm1`.
`scripts/pickups_smoke.jac` also passes native spawning/rendering/collection checks;
its desktop captures were inspected for Q1 health boxes, Q2 stimpacks and Q3
environment-mapped health crosses. Q3 companion spheres are not yet rendered.

Build and run native harnesses with the compiler setup in
[native-cache-section-merge-blocker.md](native-cache-section-merge-blocker.md).

## Remaining before campaigns/local arenas are complete

- Remaining pickup types, weapons/projectiles, enemies and local arena opponents.
- Character/item/weapon entity binding, animation selection and sound playback.
  MDL/MD2/MD3 format and rendering foundations are [validated separately](models-status.md).
- Campaign keys, objectives, runes, intermissions and endings; Q2 hub state.
- Save/load, persistent settings, and campaign/arena start flows.
- Water ledge jumps, damage feedback, fall damage, protection powerups,
  rotating/crushing movers, trains and remaining trigger/relay behaviors.
- Remaining animated materials and Q3 shader effects.

The exit loader currently skips unsupported end-screen destinations and special
activation flags. Health carry is initial progression support, not complete
per-game inventory transfer rules. Restart reloads the current map from scratch.
The initial pickup roster uses generic contact bounds and authored positions;
floor placement, per-item respawn intervals, overheal decay, triggered/team items,
pickup sounds and Q3 companion sphere models remain. Shells are stored but cannot
be fired until weapon behavior is connected.

## Current combat/persistence work

Shared hitscan combat, a small campaign opponent roster and local Q3 training
bots are implemented locally. See [combat progress](combat-prototype-status.md)
for validation and limits. Save/load and settings persistence are drafted but
blocked by [native atomic replacement](native-os-replace-blocker.md); the complete
prototype acceptance run is still outstanding.
