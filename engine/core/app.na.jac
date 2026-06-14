"""The game loop: input → fixed-timestep ticks → render. Each tick spawns
the pass walkers over the world graph; each frame floods visibility and
draws only what the flood found."""

import from .clock { Clock }
import from ..input.input { Intent, sample_intent, mouse_captured }
import from ..math.vec3 { Vec3, forward_from, right_from }
import from ..render.renderer { Renderer, RenderPass }
import from ..world.world {
    World, Area, Player, ThinkPass, VisPass,
    area_containing, area_of, move_to_area
}


glob FLY_SPEED: float = 240.0;
glob PITCH_LIMIT: float = 1.45;


obj App {
    has world: World,
        player: Player,
        renderer: Renderer,
        clock: Clock,
        culling: bool = True,
        overlay: bool = True,
        smoke: bool = False,
        last_think: int = 0,
        last_drawn: int = 0;

    def run() {
        self.renderer.open_window();
        frame = 0;
        while not self.renderer.should_close() {
            dt = self.renderer.frame_time();
            intent = sample_intent(dt);
            if intent.toggle_culling {
                self.culling = not self.culling;
            }
            if intent.toggle_overlay {
                self.overlay = not self.overlay;
            }

            ticks = self.clock.advance(dt);
            for i in range(ticks) {
                tp = self.world spawn ThinkPass(dt=self.clock.tick_rate);
                self.last_think = tp.entities_visited;
            }

            # phase-1 simplification: fly movement integrates per-frame for
            # smoothness; phase 3 moves real player physics into the ticks
            self.fly(intent, dt);
            self.render_frame();

            frame += 1;
            if self.smoke and self.smoke_step(frame) {
                break;
            }
        }
        self.renderer.close();
    }

    def fly(intent: Intent, dt: float) {
        p = self.player;
        p.yaw += intent.look_yaw;
        p.pitch += intent.look_pitch;
        if p.pitch > PITCH_LIMIT {
            p.pitch = PITCH_LIMIT;
        }
        if p.pitch < -PITCH_LIMIT {
            p.pitch = -PITCH_LIMIT;
        }

        fwd = forward_from(p.yaw, p.pitch);
        rgt = right_from(p.yaw);
        wish = fwd.scale(intent.move.y)
            .add(rgt.scale(intent.move.x))
            .add(Vec3(z=intent.move.z));
        if wish.length() > 0.001 {
            p.pos = p.pos.add(wish.normalized().scale(FLY_SPEED * dt));
        }

        # rewire the In edge when we cross into another area
        landed = area_containing(self.world, p.pos);
        if landed is not None and landed is not area_of(p) {
            move_to_area(p, landed);
        }
    }

    def render_frame() {
        p = self.player;
        facing = forward_from(p.yaw, p.pitch);
        cur = area_of(p);
        all_areas = [self.world -->[?:Area]];

        if self.culling and cur is not None {
            vis = cur spawn VisPass(eye=p.pos, facing=facing);
            targets = vis.visible;
        } else {
            targets = all_areas;
        }

        self.renderer.begin_frame(p.pos, p.yaw, p.pitch);
        rp = self.world spawn RenderPass(targets=targets, renderer=self.renderer);
        self.last_drawn = rp.drawn;
        self.renderer.end_scene();

        if self.overlay {
            cur_name = cur.name if cur is not None else "the void";
            culling_state = "ON" if self.culling else "OFF";
            mouse_state = "captured [Tab releases]" if mouse_captured() else "free - click or Tab to look";
            self.renderer.draw_overlay([
                "area: " + cur_name,
                "visible: " + str(len(targets)) + "/" + str(len(all_areas)) + " areas",
                "culling [C]: " + culling_state,
                "entities thinking: " + str(self.last_think),
                "mouse: " + mouse_state
            ]);
        }
        self.renderer.end_frame();
    }

    """Headless validation script: steer the camera through three known
    states and screenshot each, then quit. Drives the exact culling
    behavior a human would check by hand."""
    def smoke_step(frame: int) -> bool {
        if frame == 40 {
            # facing the doorway: both rooms should be visible
            self.renderer.screenshot("qp_smoke_door.png");
            self.player.yaw = 3.14159;
        } elif frame == 80 {
            # facing away: culling should leave only the current room
            self.renderer.screenshot("qp_smoke_away.png");
            self.culling = False;
        } elif frame == 120 {
            # culling off: everything draws regardless of facing
            self.renderer.screenshot("qp_smoke_off.png");
            return True;
        }
        return False;
    }
}
