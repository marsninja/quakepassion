"""Original maps: Q3 mirrors and portals render the view through them."""
import math;
import from engine.core.menu { game_directory }
import from engine.world.level { Level, load_level }
import from engine.world.world { World }
import from engine.world.portals { PortalSurface, HasPortal }
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
        seen: list[int] = [];
        for index in range(len(level.bsp.faces)) {
            face = level.bsp.faces[index];
            if face.texture not in level.portal_ranges or face.hidden or not face.vertices or face.texture in seen {
                continue;
            }
            middle = Vec3();
            for v in face.vertices {
                middle = middle.add(v);
            }
            middle = middle.scale(1.0 / float(len(face.vertices)));
            eye = middle.add(face.normal.scale(120.0));
            if level.collision.trace_point(eye, eye).start_solid {
                continue;
            }
            seen.append(face.texture);
            toward = middle.sub(eye);
            yaw = math.atan2(toward.y, toward.x);
            pitch = math.atan2(toward.z, math.sqrt(toward.x * toward.x + toward.y * toward.y));
            rendered = False;
            for frame in range(3) {
                faces = level.visible(world, eye, False);
                rendered = draw_portal_view(target, level, world, drawing, models, effects, faces, eye, yaw, pitch, renderer.fov, float(frame) * 0.1);
                renderer.begin_frame(eye, yaw, pitch);
                drawing.view_forward = forward_from(yaw, pitch);
                drawing.draw(level, faces, eye);
                renderer.end_scene();
                renderer.end_frame();
            }
            shot = "portal_" + name + "_" + str(shots) + ".png";
            renderer.screenshot(shot);
            print("PORTAL", name, level.bsp.textures[face.texture].name, "rendered", rendered, "->", shot);
            assert rendered;
            shots += 1;
        }
        assert shots > 0;
        drawing.close();
        print("PORTAL PASS", name);
    }
    target.release();
    renderer.close();
}
