"""Original Q2 destructibles and toggle-wall geometry/persistence acceptance."""
import os;
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.brushes { BrushObject, HasBrush, BrushTick, ShootBrush }
import from engine.world.combat { CombatState }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }

with entry {
    total = 0;
    for name in ["base1", "base2", "fact1", "ware1"] {
        world = World();
        level = load_level(
            world, os.getenv("HOME", "") + "/quake-assets/baseq2", name, "q2"
        );
        brushes = [world->:HasBrush:->][?:BrushObject];
        player = Player(pos=Vec3(x=1.0e6, y=1.0e6, z=1.0e6));
        state = CombatState();
        before = snapshot(world, level, player, state);
        for brush in brushes {
            if brush.kind == "func_wall" {
                old = brush.active;
                brush.activation.pending = 1;
                world spawn BrushTick(
                    bsp=level.bsp, collision=level.collision, player=player, state=state
                );
                assert brush.active != old;
            } else {
                if not brush.active {
                    brush.activation.pending = 1;
                    world spawn BrushTick(
                        bsp=level.bsp,
                        collision=level.collision,
                        player=player,
                        state=state
                    );
                }
                if brush.shootable {
                    world spawn ShootBrush(
                        model=brush.model,
                        amount=brush.health,
                        bsp=level.bsp,
                        collision=level.collision,
                        player=player,
                        state=state
                    );
                } else {
                    brush.activation.pending = 1;
                    world spawn BrushTick(
                        bsp=level.bsp,
                        collision=level.collision,
                        player=player,
                        state=state
                    );
                }
                assert brush.destroyed and not brush.active;
            }
            for h in brush.hulls {
                assert (h in level.collision.disabled) == (not brush.active);
            }
            for i in range(len(brush.faces)) {
                assert level.bsp.faces[brush.faces[i]].hidden
                    == (not brush.active or brush.hidden[i]);
            }
        }
        restore(world, level, player, state, before);
        assert snapshot(world, level, player, state) == before;
        total += len(brushes);
        print("BRUSH OBJECTS PASS", name, len(brushes), "state changes and snapshots");
    }
    assert total > 0;
}
