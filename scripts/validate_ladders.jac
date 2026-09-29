"""Asset-backed Q2 ladder and current checks: every CONTENTS_LADDER brush in
the listed maps (QP_MAPS, comma separated) is climbed from the lowest open
spot in front of it, looking up and pressing forward, until the climber
tops it out; then the water currents of each current volume are felt by a
swimmer in it."""
import os;
import math;
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.liquids { LiquidVolume, HasLiquid }
import from engine.physics.movement { MovePlayer, movement_profile }
import from engine.math.vec3 { Vec3 }

with entry {
    directory = os.getenv(
        "QP_ASSETS", os.getenv("HOME", "") + "/quake-assets/baseq2"
    );
    names = os.getenv("QP_MAPS", "base1,city2,ware2,cool1").split(",");
    rules = movement_profile("q2");
    for name in names {
        level = load_level(World(), directory, name, "q2");
        collision = level.collision;
        ladders = [i for i in range(len(collision.hulls)) if collision.hulls[i].climbable];
        climbed = 0;
        for index in ladders {
            box = collision.bounds[index];
            center = box.center();
            best = 0.0;
            topped = False;
            for side in [Vec3(x=1.0), Vec3(x=-1.0), Vec3(y=1.0), Vec3(y=-1.0)] {
                # Hang on the lowest open spot of this face where the ladder
                # is within reach, dropping to a floor within a step below.
                start: Vec3 | None = None;
                height = box.mins.z + 32.0;
                while height < box.maxs.z - 24.0 and start is None {
                    spot = Vec3(
                        x=box.maxs.x + 0.5 if side.x > 0.0 else (box.mins.x - 0.5 if side.x < 0.0 else center.x),
                        y=box.maxs.y + 0.5 if side.y > 0.0 else (box.mins.y - 0.5 if side.y < 0.0 else center.y),
                        z=height
                    );
                    reach = collision.trace(spot, spot.sub(side));
                    if not collision.trace(spot, spot).start_solid
                        and reach.climbable
                        and reach.hull == index {
                        start = collision.trace(spot, spot.sub(Vec3(z=18.0))).end;
                    }
                    height += 8.0;
                }
                if start is None {
                    continue;
                }
                player = Player(
                    pos=start.add(Vec3(z=collision.eye_height)),
                    yaw=math.atan2(-side.y, -side.x),
                    pitch=0.5,
                    walk_speed=rules.max_speed
                );
                on_ladder = False;
                for tick in range(1200) {
                    moved = player spawn MovePlayer(
                        collision=collision, wish=side.scale(-1.0), profile=rules
                    );
                    on_ladder = on_ladder or moved.climbing;
                    if on_ladder and not moved.climbing and player.grounded {
                        topped = True;
                        break;
                    }
                }
                if on_ladder {
                    rise = player.pos.z - collision.eye_height - start.z;
                    best = max(best, rise);
                    if topped {
                        break;
                    }
                }
            }
            if best > 32.0 {
                climbed += 1;
            }
            print(
                name,
                "ladder",
                index,
                "model",
                collision.models[index],
                "height",
                round(box.maxs.z - box.mins.z - 56.0),
                "climbed",
                round(best),
                "topped" if topped else ""
            );
        }
        print(name, climbed, "of", len(ladders), "ladder brushes climbed");
        for volume in [level.liquids->:HasLiquid:->][?:LiquidVolume] {
            if volume.currents == 0 {
                continue;
            }
            # A free spot in the volume where a swimmer is under and feels it.
            spot: Vec3 | None = None;
            for bounds in volume.volume.bounds {
                for fx in [0.25, 0.5, 0.75] {
                    for fy in [0.25, 0.5, 0.75] {
                        z = bounds.mins.z + 24.0;
                        while spot is None and z < bounds.maxs.z - 24.0 {
                            probe = Vec3(
                                x=bounds.mins.x + (bounds.maxs.x - bounds.mins.x) * fx,
                                y=bounds.mins.y + (bounds.maxs.y - bounds.mins.y) * fy,
                                z=z
                            );
                            felt = level.immersion(probe.add(Vec3(z=collision.eye_height)));
                            if not collision.trace(probe, probe).start_solid
                                and felt.depth >= 1
                                and felt.current.length() > 0.0 {
                                spot = probe;
                            }
                            z += 16.0;
                        }
                    }
                }
            }
            if spot is None {
                print(name, "current volume with no free swimming spot");
                continue;
            }
            state = level.immersion(spot.add(Vec3(z=collision.eye_height)));
            swimmer = Player(pos=spot.add(Vec3(z=collision.eye_height)), walk_speed=rules.max_speed);
            for tick in range(12) {
                swimmer spawn MovePlayer(
                    collision=collision,
                    water_depth=state.depth,
                    current=state.current,
                    profile=rules
                );
            }
            print(
                name,
                "current",
                state.current.x,
                state.current.y,
                state.current.z,
                "depth",
                state.depth,
                "swimmer pushed to",
                round(swimmer.velocity.x),
                round(swimmer.velocity.y),
                round(swimmer.velocity.z)
            );
        }
    }
}
