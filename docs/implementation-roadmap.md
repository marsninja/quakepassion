# Campaign and local arena prototype

The agreed target is a playable prototype using original Q1/Q2 maps and a local
Q3 arena, with a smaller combat roster. It does not include full original-game
behavior, network multiplayer, original mods, or an editor.

## Implemented

- One shared spatial graph, renderer, collision/movement system and application
  loop across all three game formats. Walking, crouching, swimming, jump pads,
  teleporters, buttons, translating platforms and supported doors are connected.
- Two hitscan weapons, health/armor/ammunition pickups, damage, death/restart,
  original sounds and a HUD. Q1 soldiers, Q2 soldiers/infantry, and Q3 Sarge bots
  use shared combat behavior with sight memory, local obstacle steering and
  idle/run/attack animation. Q3 body/head/weapon parts use original MD3 tags.
- Q1 silver/gold key doors, Q2 key gates, objective counters, pickup/death target
  activation, key inventory feedback and supported map exits.
- Q2 visited-map state retained across hub returns and save/load. Unit transitions
  clear keys and hub history. Map selection starts fresh; failed loads preserve
  the current world. Save format 2 rejects older snapshots explicitly.
- Escape level/settings menu, persistent settings, F5/F9 save/load, and a local
  ten-frag arena with bot respawn, victory banner and Enter rematch.

## Acceptance and delivery

`jac run scripts/validate_gameplay.jac` builds native persistence, input,
campaign and combat harnesses using a disposable HOME linked to original assets.
It checks all three games, Q1 e1m2 key collection/unlock and onward loading,
Q2 base1/base2 return state, save/load and rollback, and repeated arena kills.
The separate menu runner covers settings, game selection and quitting. Unit
fixtures cover synthetic collision, gameplay and serialization edge cases.

These are controlled automated scenarios, not uninterrupted human campaign
playthroughs. Listening to audio, judging combat feel and exploring authored maps
remain useful manual acceptance. See [campaign details](campaign-gameplay-status.md)
and [combat details](combat-prototype-status.md).

The current native validation compiler is upstream Jac main at `51584156a2`
plus [Jac #9388](https://github.com/jaseci-labs/jac/pull/9388). The released-binary
check remains blocked until a release includes the necessary upstream fixes.
Do not substitute source-compiler results for released-binary acceptance.

## Beyond this prototype

Full original campaign branches, boss/rune endings, complete enemies/weapons,
projectiles and original behavior; trains/rotating/crushing movers and remaining
trigger/material directives; global bot pathfinding and actor separation;
network multiplayer, original-mod compatibility, and editing tools.
