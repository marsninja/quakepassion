# Every-map sweep

`scripts/map_sweep.jac` drives every original Q1, Q2 and Q3 map through the
game, which catches loader, spawn and simulation failures that single-map
tests miss:
- Each map loads through the `App` as the menu does.
- It simulates two seconds with its monsters, bots, movers and effects.
- It renders one frame, captured to `.jac/screenshots/sweep/<game>_<map>.png`.

Any failure is reported per map, so the sweep never stops at the first one.
Build and run it natively:

```
jac build scripts/map_sweep.jac --native -o .jac/map-sweep
DYLD_LIBRARY_PATH=vendor .jac/map-sweep          # QP_SWEEP_GAMES=q3 limits the games
```

## Latest result

All 121 maps pass: every Quake and Quake II map, and all 36 Quake III maps
including the CTF and test maps.

The sweep found two real defects, both now fixed:
- q3tourney6 has surfaces whose fog index runs past its fog list. Q3's own
  loader never checks it, so such surfaces are now treated as unfogged.
- q3dm19 ships its bot navigation in the older AAS version 4, which
  `be_aas_file.c` accepts, with the header stored unhidden.
