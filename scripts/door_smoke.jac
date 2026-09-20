"""Capture closed/open linked doors on an active graphical desktop."""
import math;
import os;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World }
import from engine.world.doors {
    Door,
    HasDoor,
    DoorMember,
    DoorTick,
    union_bounds,
    model_bounds
}
import from engine.world.signals { Signal }
import from engine.world.triggers { TouchTrigger, HasTrigger, Activates }
import from engine.physics.collision { Sweep }
import from engine.math.vec3 { Vec3 }

with entry {
    button_mode = os.getenv("QP_BUTTON_TEST", "0") == "1";
    trigger_mode = os.getenv("QP_TRIGGER_TEST", "0") == "1";
    prefix = "qp_trigger_" if trigger_mode else "qp_door_";
    if button_mode { prefix = "qp_button_"; }
    renderer = Renderer();
    renderer.open_window();
    for game in ["q1", "q2", "q3"] {
        name = "e1m1" if game == "q1" else ("base2" if game == "q2" else "q3dm2");
        if trigger_mode {
            name = "e1m1" if game == "q1" else ("ware1" if game == "q2" else "q3dm11");
        }
        if button_mode { name = "e1m1" if game == "q1" else ("base1" if game == "q2" else "q3dm7"); }
        world = World();
        level = load_level(world, game_directory(game), name, game);
        doors = [
            door
            for door in [world->:HasDoor:->][?:Door]
            if door.automatic and door.enabled and door.kind == "door"
        ];
        sensors = [world->:HasTrigger:->][?:TouchTrigger];
        if trigger_mode {
            assert len(sensors) > 0;
            signals = [sensors[0]->:Activates:->][?:Signal];
            doors = [door for door in [world->:HasDoor:->][?:Door] if door.activation in signals];
        }
        if button_mode {
            doors = [door for door in [world->:HasDoor:->][?:Door] if door.kind == "button" and door.enabled];
        }
        assert len(doors) > 0;
        door = doors[0];
        bounds = door.bounds;
        for part in [door->:DoorMember:->][?:Door] {
            bounds = union_bounds(bounds, part.bounds);
        }
        if trigger_mode {
            bounds = door.bounds;
        }
        center = bounds.center();
        size = bounds.size();
        axis = Vec3(x=1.0) if size.x < size.y else Vec3(y=1.0);
        camera = center;
        offset = Vec3();
        found = False;
        button_contact = Vec3();
        if button_mode {
            for height in [48.0, 96.0, 0.0] {
                for direction in [Vec3(x=160.0), Vec3(x=-160.0), Vec3(y=160.0), Vec3(y=-160.0), Vec3(x=64.0), Vec3(x=-64.0), Vec3(y=64.0), Vec3(y=-64.0)] {
                    candidate = center.add(direction).add(Vec3(z=height));
                    origin = candidate.sub(Vec3(z=level.collision.eye_height));
                    hit = level.collision.trace(origin, center);
                    if hit.start_solid or hit.fraction == 1.0 { continue; }
                    for hull in door.hulls {
                        local = hit.end.sub(level.collision.offsets[hull]);
                        probe = level.collision.hulls[hull] spawn Sweep(
                            start=local, finish=local.add(center.sub(origin).normalized().scale(0.125))
                        );
                        if probe.result.start_solid or probe.result.fraction < 1.0 {
                            camera = candidate;
                            offset = candidate.sub(center);
                            button_contact = hit.end;
                            found = True;
                            break;
                        }
                    }
                    if found { break; }
                }
                if found { break; }
            }
        } else {
            for distance in [160.0, -160.0, 100.0, -100.0] {
                candidate = center.add(axis.scale(distance));
                origin = candidate.sub(Vec3(z=level.collision.eye_height));
                if not level.collision.trace(origin, origin).start_solid {
                    camera = candidate;
                    offset = axis.scale(distance);
                    found = True;
                    break;
                }
            }
        }
        assert found;
        player = spawn_player(level);
        player.pos = camera;
        player.yaw = math.atan2(-offset.y, -offset.x);
        player.pitch = -math.atan2(offset.z, math.sqrt(offset.x * offset.x + offset.y * offset.y));
        app = App(
            world=world,
            player=player,
            renderer=renderer,
            clock=Clock(),
            level=level,
            overlay=False,
            culling=False,
            smoke=True
        );
        app.quake.upload(level);
        for i in range(3) {
            app.render_frame();
        }
        renderer.screenshot(prefix + game + "_closed.png");
        probe_start = center.add(axis.scale(48.0)).sub(
            Vec3(z=level.collision.eye_height)
        );
        probe_finish = center.sub(axis.scale(48.0)).sub(
            Vec3(z=level.collision.eye_height)
        );
        assert level.collision.trace(probe_start, probe_finish).fraction < 1.0;
        if button_mode {
            player.pos = button_contact.add(Vec3(z=level.collision.eye_height));
            app.walking = True;
            app.smoke = False;
        } elif trigger_mode {
            sensor = sensors[0];
            sensor_offset = Vec3();
            for entity in level.bsp.entities {
                if entity.fields.get("model", "") == "*" + str(sensor.model) {
                    coords = entity.fields.get("origin", "0 0 0").split();
                    sensor_offset = Vec3(
                        x=float(coords[0]), y=float(coords[1]), z=float(coords[2])
                    );
                }
            }
            contact = model_bounds(level.bsp, sensor.model).center().add(sensor_offset);
            candidates = [contact];
            for volume_bounds in sensor.volume.bounds {
                extent = volume_bounds.size();
                for fx in [0.1, 0.3, 0.5, 0.7, 0.9] {
                    for fy in [0.1, 0.3, 0.5, 0.7, 0.9] {
                        for fz in [0.1, 0.3, 0.5, 0.7, 0.9] {
                            candidates.append(
                                volume_bounds.mins.add(
                                    Vec3(
                                        x=extent.x * fx,
                                        y=extent.y * fy,
                                        z=extent.z * fz
                                    )
                                )
                            );
                        }
                    }
                }
            }
            contact_found = False;
            for candidate in candidates {
                if sensor.volume.trace(candidate, candidate).start_solid
                    and not level.collision.trace(candidate, candidate).start_solid {
                    contact = candidate;
                    contact_found = True;
                    break;
                }
            }
            assert contact_found;
            assert sensor.volume.trace(contact, contact).start_solid;
            assert not level.collision.trace(contact, contact).start_solid;
            player.pos = contact.add(Vec3(z=level.collision.eye_height));
            app.walking = True;
            app.smoke = False;
        } else {
            door.state = "opening";
        }
        app.menu.opened = True;
        app.physics_clock.accumulator = 0.05;
        app.skip_time = True;
        assert app.step();
        assert door.position == 0.0;
        if trigger_mode {
            assert sensors[0].activations == 0;
        }
        app.menu.opened = False;
        app.smoke = False;
        app.skip_time = True;
        assert app.step();
        assert door.position > 0.0;
        if trigger_mode {
            assert sensors[0].activations == 1;
        }
        player.pos = camera;
        player.yaw = math.atan2(-offset.y, -offset.x);
        player.pitch = -math.atan2(offset.z, math.sqrt(offset.x * offset.x + offset.y * offset.y));
        world spawn DoorTick(
            bsp=level.bsp,
            collision=level.collision,
            player_origin=door.trigger.mins.add(Vec3(x=1.0, y=1.0, z=1.0)),
            dt=0.001
        );
        door spawn DoorTick(
            bsp=level.bsp,
            collision=level.collision,
            player_origin=Vec3(x=1.0e6, y=1.0e6, z=1.0e6),
            dt=door.travel.length() / door.speed + 0.01
        );
        assert door.position == 1.0;

        for i in range(3) {
            app.render_frame();
        }
        renderer.screenshot(prefix + game + "_open.png");
        if not button_mode { assert level.collision.trace(probe_start, probe_finish).fraction == 1.0; }
        app.quake.close();
        print(
            "BUTTON RENDER PASS" if button_mode else ("TRIGGER RENDER PASS" if trigger_mode else "DOOR RENDER PASS"), game, name
        );
    }
    renderer.close();
}
