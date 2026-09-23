# Ground navigation

Alerted opponents can now find bounded ground detours around obstacles instead
of relying solely on five local steering directions. This is shared by campaign
enemies and local arena bots.

The search builds a temporary graph of route points and parent edges; a walker
collects the chosen path. It samples a 48-unit lattice with separate height
layers and up to 96 expanded points. Each connection uses the actor collision
hull, the existing 18-unit step movement, and ground checks every 12 units.
Unsupported drops and blocked connections are rejected. Exhausting the search
budget returns no route rather than a partial path toward a dead end.

Routes are cached, checked against moving geometry while followed, and discarded
when the target moves materially, on respawn, or on save restoration. They are
transient movement hints and do not change snapshot format 14. Searches have a
world-wide allowance of eight per simulated second, with at most one accumulated
search credit. Existing last-seen information remains the destination: this does
not give enemies knowledge of a hidden player's new location.

Initial validation: five tests cover wall detours, pits, step height, search
limits, newly blocked connections, and pursuit through actual movement ticks.
The standalone native `scripts/navigation_smoke.jac` also completes the detour.
Two additional hull tests reject narrow passages and inadequate headroom.
The rebuilt viewer completes startup/render smoke runs for Q1 `e1m1`, Q2
`base1`, and Q3 `q3dm1`. These are startup checks, not campaign playthroughs.
Validation uses the documented local compiler, including the list-search fix.
The full regression run passed **298 tests**; the two subsequently added hull
tests also passed separately, for **300 passing tests across those runs**.

This is bounded local navigation, not global map routing. The lattice can miss
narrow or irregular passages. Long routes, door activation, elevator scheduling,
jump/swim links, full actor hull distinctions, Q3 item goals and tactical behavior
remain open. Navigation alone does not establish original-game AI parity.

Stair projection now distinguishes an unknown landing height from a known route
endpoint. Several valid risers can therefore form one search connection without
rejecting their combined rise; each individual step still uses the existing
18-unit movement limit. Explicit endpoints still reject a different floor.
Enemy interaction with [doors and platforms](enemy-movers-status.md) lets actors
open nearby automatic doors and ride lifts they reach.
