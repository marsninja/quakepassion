"""Original maps: Q3 mirrors and portals render the view through them."""
import math;
import from engine.core.menu { game_directory }
import from engine.world.level { Level, load_level }
import from engine.world.world { World }
import from engine.world.portals { PortalSurface, HasPortal, surface_plane }
import from engine.render.quake { QuakeRenderer }
import from engine.render.models { ModelScene }
import from engine.render.effects { EffectScene }
import from engine.render.portal { PortalTarget, draw_portal_view }
import from engine.render.renderer { Renderer }
import from engine.math.vec3 { Vec3, forward_from }

with entry {
    renderer = Renderer();
    renderer.open_window();
    target = PortalTarget();
    for name in ["q3tourney6", "q3dm0", "q3dm7"] {
        world = World();
        level = load_level(world, game_directory("q3"), name, "q3");
        drawing = QuakeRenderer();
        drawing.upload(level);
        models = ModelScene();
        models.upload(world);
        effects = EffectScene();
        portals = [world->:HasPortal:->][?:PortalSurface];
        print("PORTAL", name, "entities", len(portals), "mirrors", len([p for p in portals if p.mirror]), "portal shaders", len(level.portal_ranges));
        assert portals and level.portal_ranges;
        shots = 0;
        for texture in level.portal_ranges.keys() {
            rendered = False;
            shot = "";
            for index in range(len(level.bsp.faces)) {
                face = level.bsp.faces[index];
                if face.texture != texture or face.hidden or not face.vertices or rendered {
                    continue;
                }
                middle = Vec3();
                for v in face.vertices {
                    middle = middle.add(v);
                }
                middle = middle.scale(1.0 / float(len(face.vertices)));
                facing = surface_plane(face)[0];
                for reach in [96.0, 160.0, 64.0, 220.0] {
                    eye = middle.add(facing.scale(reach));
                    # A floor or ceiling mirror is viewed at an angle: a camera
                    # pointing straight up or down has no usable up vector.
                    if abs(facing.z) > 0.9 {
                        eye = eye.add(Vec3(x=reach * 0.8));
                    }
                    if rendered or level.collision.trace_point(eye, eye).start_solid {
                        continue;
                    }
                    faces = level.visible(world, eye, True);
                    if index not in faces {
                        continue;
                    }
                    toward = middle.sub(eye);
                    yaw = math.atan2(toward.y, toward.x);
                    pitch = math.atan2(toward.z, math.sqrt(toward.x * toward.x + toward.y * toward.y));
                    for frame in range(3) {
                        rendered = draw_portal_view(target, level, world, drawing, models, effects, faces, eye, yaw, pitch, renderer.fov, float(frame) * 0.1);
                        renderer.begin_frame(eye, yaw, pitch);
                        drawing.view_forward = forward_from(yaw, pitch);
                        drawing.draw(level, faces, eye);
                        renderer.end_scene();
                        renderer.end_frame();
                    }
                    if rendered {
                        shot = "portal_" + name + "_" + str(shots) + ".png";
                        renderer.screenshot(shot);
                    }
                }
            }
            print("PORTAL", name, level.bsp.textures[texture].name, "rendered", rendered, "->", shot);
            if rendered {
                shots += 1;
            }
        }
        assert shots > 0;
        drawing.close();
        print("PORTAL PASS", name);
    }
    target.release();
    renderer.close();
}
