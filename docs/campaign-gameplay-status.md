# Campaign prototype

Q1/Q2 exits, supported buttons/doors/platforms, keys, counters and pickups connect
through the shared activation graph. Q1 key doors require and consume silver or
gold keys, including linked doors. Q2 trigger_key consumes the required key and
unlocks its target once. Counters retain partial progress. Pickups and supported
opponent deaths can activate targets. Key inventory and gate/objective feedback
appear in the HUD.

Q2 hub transitions retain visited world snapshots (items, opponents, movers,
triggers and signals), while carrying current player health/armor/inventory and
using the destination's authored arrival. A `*` unit transition clears hub history
and cross-level trigger flags but keeps keys (the original strips them only in
coop). Q1 map transitions clear keys. Selecting a map from the menu starts a
fresh session. Failed asset loads leave the current level and hub intact.
Restart after death reloads the autosave taken on level entry: the player's
health, armor, inventory, weapons, keys and unit flags as they entered, with the
Q2 hub as it was then. Q1 exits show the intermission stats and Q2 unit exits a
unit summary; see [level flow](level-flow-status.md).

F5 saves; F9 loads the active map and Q2 hub together. Saves use a data-only
campaign envelope and snapshot version 5. Older snapshots are rejected:
expanding the enemy roster changes positional entity records, so
silently reading old snapshots would risk restoring state to the wrong entities.
Settings persist separately; menu reset restores defaults.

## Validation

Synthetic fixtures exercise key rejection/consumption, linked activation,
counter state, door unlock restoration and campaign-envelope validation.
`scripts/campaign_smoke.jac` exercises actual Q1 e1m2 key pickup/unlock and e1m3
loading; Q2 base1/base2 returns restore an enemy and consumed pickup, carry current
inventory, survive cross-game save/load, roll back failed loads and reset a unit.
The harness positions the player at contacts; it does not claim a human traversal
of every intervening room. Existing exit checks cover authored destinations and
named spawn points. Persistence and input harnesses cover all three games.

Run `jac run scripts/validate_gameplay.jac` with original assets and the compiler
setup in the README. Captures/logs go to `.jac/screenshots/gameplay`.

## Deliberate limits

This is the smaller-roster playable prototype. Full campaign branches and endings,
boss/rune logic, original weapon/enemy behaviors, all special trigger flags,
remaining rotating/crushing mover behavior is incomplete. Shared trains are now
implemented; see [authored events](authored-events-status.md). Remaining original
shader directives, water ledge jumps, fall damage, protection powerups and precise
per-item placement/respawn behavior are further fidelity work. Activation chains
skip recipients without a use, as the originals do; `scripts/chain_audit.jac`
checks that every exit, mover, trigger and train of the Q1 and Q2 campaigns
loads. Automated route checks do not certify a human traversal of every map.
