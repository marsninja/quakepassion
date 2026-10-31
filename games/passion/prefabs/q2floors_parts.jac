"""How the mines', the factory's and the power plant's stretches break a big
floor up the way their originals do, drawn in a prefab's own cells through its
`Raising`: a bay of floor sunk a step or two below the rest, the bed of a
pool stepped in bands, so no great flat runs from wall to wall."""
import from ..prefab { Raising }
import from ..space { Space }

"""A bay of floor sunk `drop` lifts under lift `z` over the cells x0..x1,
y0..y1 (carve it before what stands on it). What is put over it falls to its
floor; a doorway in a wall of it keeps its own sill."""
def sunken(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int, drop: int = 1) {
    build.widen(space, x0, y0, z - drop, x1, y1, z);
}

"""A pool's bed at lift `z` stepped up a lift in every second band `every`
cells wide across x0..x1, y0..y1, as a flooded working's floor lies."""
def stepped_bed(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int, every: int) {
    for x in range(x0 + every, x1, 2 * every) {
        build.solid(x, y0, z, min(x + every, x1), y1, z + 1);
    }
}
