"""Find a clear submerged standing hull in an asset level for validation."""
import from engine.world.level { Level }
import from engine.world.liquids { LiquidVolume, HasLiquid }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }

def swim_points(level: Level) -> list[Vec3] {
    bounds: list[AABB] = [];
    if level.bsp.game == "q1" {
        for leaf in level.bsp.leaves {
            if leaf.contents >= -5 and leaf.contents <= -3 {
                bounds.append(AABB(mins=leaf.mins, maxs=leaf.maxs));
            }
        }
    } else {
        for fluid in [level.liquids->:HasLiquid:->][?:LiquidVolume] {
            bounds.extend(fluid.volume.bounds);
        }
    }
    for box in bounds {
        for x in [0.5, 0.25, 0.75] {
            for y in [0.5, 0.25, 0.75] {
                for z in [0.5, 0.25, 0.75] {
                    origin = box.mins.add(
                        Vec3(x=box.size().x * x, y=box.size().y * y, z=box.size().z * z)
                    );
                    eye = origin.add(Vec3(z=level.collision.eye_height));
                    if level.immersion(eye).depth >= 2
                        and not level.collision.trace(origin, origin).start_solid {
                        return [eye];
                    }
                }
            }
        }
    }
    return [];
}
