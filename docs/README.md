# QuakePassion docs

Each status doc describes what the engine does in one area, how it is
validated, and what remains. Start with the [roadmap](implementation-roadmap.md)
for the scope and the list of remaining gaps; the project [README](../README.md)
covers building, running and the architecture.

## Overview
- [implementation-roadmap.md](implementation-roadmap.md): scope, where each game stands, open issues and remaining gaps
- [jac-native-fixes.md](jac-native-fixes.md): the jac compiler pin and the native defects fixed upstream

## Player
- [player-movement-status.md](player-movement-status.md): per-game movement profiles, collision, ladders, crouching
- [swimming-status.md](swimming-status.md): liquids, swimming, drowning and currents
- [traversal-status.md](traversal-status.md): teleporters and jump pads
- [player-feedback-status.md](player-feedback-status.md): knockback, view kicks, damage and view feedback

## World and campaigns
- [level-flow-status.md](level-flow-status.md): exits, units and hubs, saves, intermissions, runes, finales
- [map-mechanics-status.md](map-mechanics-status.md): the activation graph, triggers, trains, rotators, the shared pusher, traps and fixtures
- [doors-status.md](doors-status.md): doors, buttons and plats
- [platforms-status.md](platforms-status.md): translating platforms and carrying
- [spawn-rules-status.md](spawn-rules-status.md): skill and mode spawn filtering

## Combat
- [weapons-status.md](weapons-status.md): weapons and items for each game
- [viewweapons-status.md](viewweapons-status.md): first-person weapon models and animation
- [powerups-status.md](powerups-status.md): powerups and holdables
- [combat-feedback-status.md](combat-feedback-status.md): impacts, particles, trails, beams, marks and dynamic lights

## Monsters
- [monster-behaviour-status.md](monster-behaviour-status.md): noticing, skill, patrols, infighting and gibs
- [q1-roster-status.md](q1-roster-status.md): the Quake roster, Chthon and Shub-Niggurath
- [q2-roster-status.md](q2-roster-status.md): the Quake II roster through Jorg and Makron
- [enemies-status.md](enemies-status.md): the original campaign enemy expansion notes
- [navigation-status.md](navigation-status.md): monster movement, bodies, navigation and movers
- [navigation-performance.md](navigation-performance.md): navigation cost and frame pacing measurements

## Quake III arena
- [arena-match-status.md](arena-match-status.md): matches, the ladder, scoring, awards and the podium
- [bot-tactics-status.md](bot-tactics-status.md): botlib navigation, goals, combat and chat
- [player-bodies-status.md](player-bodies-status.md): Q3 player models, animation and corpses

## Presentation
- [rendering-status.md](rendering-status.md): per-game level loading, visibility, the GPU renderer and its limits
- [presentation-status.md](presentation-status.md): status bars, light styles, skies, liquids and Q3 shaders
- [models-status.md](models-status.md): MDL/MD2/MD3 loading, animation and lighting
- [menu-console-status.md](menu-console-status.md): the menu, console, cvars, bindings and configuration files

## Tooling and performance
- [validation-tooling-status.md](validation-tooling-status.md): tests, validators, the map sweep and walkthroughs
- [performance-status.md](performance-status.md): profiling harnesses and dated measurements

## Passion
- [passion.md](passion.md): the generated fourth mode
