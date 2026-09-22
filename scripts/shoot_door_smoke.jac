"""Exercise authored Q1/Q2 shootable door groups with original BSP assets."""
import os;
import from engine.assets.library { AssetLibrary }
import from engine.formats.bsp { i32_at, parse_entities }
import from engine.world.level { load_level }
import from engine.world.world { World }
import from engine.world.doors { Door, HasDoor, DoorMember, DoorTick }
import from engine.world.trains { ShootMover }
import from engine.math.vec3 { Vec3 }

with entry {
    for game in ["q1", "q2"] {
        directory = os.getenv("HOME", "")
            + "/quake-assets/"
            + ("id1" if game == "q1" else "baseq2");
        library = AssetLibrary(game=game);
        library.open(directory);
        maps: set[str] = set();
        for pak in library.paks {
            for name in pak.names() {
                if name.startswith("maps/") and name.endswith(".bsp") {
                    data = library.read(name);
                    base = 4 if game == "q1" else 8;
                    offset = i32_at(data, base);
                    size = i32_at(data, base + 4);
                    for entity in parse_entities(
                        data[offset:offset + size].decode("utf-8", errors="replace")
                    ) {
                        if entity.fields.get("classname", "") == "func_door"
                            and int(float(entity.fields.get("health", "0"))) > 0
                            and int(entity.fields.get("spawnflags", "0")) & 512 == 0 {
                            maps.add(name[5:-4]);
                        }
                    }
                }
            }
        }
        library.close();
        tested = 0;
        for name in sorted(maps) {
            world = World();
            level = load_level(world, directory, name, game);
            for door in [world->:HasDoor:->][?:Door] {
                if not door.enabled or door.kind != "door" {
                    continue;
                }
                members = [door];
                members.extend([door->:DoorMember:->][?:Door]);
                for part in members {
                    health = door.max_health if door.shared_health else part.max_health;
                    if health <= 0 {
                        continue;
                    }
                    assert not door.automatic;
                    world spawn ShootMover(model=part.model, amount=health);
                    assert door.activation.pending == 1;
                    door spawn DoorTick(
                        bsp=level.bsp,
                        collision=level.collision,
                        player_origin=Vec3(x=1.0e6, y=1.0e6, z=1.0e6),
                        dt=door.travel.length() / door.speed + 0.01
                    );
                    assert door.state == "open" and door.position == 1.0;
                    for member in members {
                        motion = member.rest.add(member.travel);
                        for face in member.faces {
                            assert level.bsp.faces[face].motion.sub(motion).length()
                                < 0.00001;
                        }
                        for i in range(len(member.hulls)) {
                            assert level.collision.offsets[member.hulls[i]].sub(
                                member.origins[i]
                            ).sub(
                                motion
                            ).length()
                                < 0.00001;
                        }
                    }
                    tested += 1;
                    print("SHOOT DOOR PASS", game, name, door.model, len(members));
                    break;
                }
            }
        }
        assert tested > 0;
        print("SHOOT DOORS TOTAL", game, tested);
    }
}
