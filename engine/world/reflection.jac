"""The player's own body, which Q3 draws only where the player can see
themselves: in mirrors and portals (RF_THIRD_PERSON). It follows the player
each frame, standing or running on the leg cycle, holding the current weapon."""
import from .world { World, Entity, Player, Area, move_to_area }
import from .models { Visual, ModelResource, UsesModel, HasVisual }
import from ..math.vec3 { Vec3 }

node PlayerBody(Entity) {
    has body: Visual = Visual(),
        weapon: Visual = Visual(),
        stand_frame: int = 0,
        run_frames: list[int] = [],
        run_rate: float = 15.0,
        shown_weapon: str = "";
}

edge HasBody: World --> PlayerBody {}
edge Carries: PlayerBody --> ModelResource {
    has key: str = "";
}

"""A body drawn with `model`, hidden until a portal view shows it."""
def player_body(model: ModelResource, run_rate: float) -> PlayerBody {
    body = PlayerBody(run_rate=run_rate);
    body +>:HasVisual:+> body.body;
    body.body +>:UsesModel:+> model;
    body +>:HasVisual:+> body.weapon;
    frames = model.model.surfaces[0].frames if model.model.surfaces else [];
    for i in range(len(frames)) {
        if frames[i].name == "stand0" {
            body.stand_frame = i;
        }
        if frames[i].name.startswith("run") {
            body.run_frames.append(i);
        }
    }
    body.body.visible = False;
    body.weapon.visible = False;
    return body;
}

"""Pose the body where the player stands and show it, or hide it again."""
def show_body(world: World, player: Player, eye_height: float, weapon: str, seconds: float, shown: bool, area: Area | None = None) -> PlayerBody | None {
    bodies = [world->:HasBody:->][?:PlayerBody];
    if not bodies {
        return None;
    }
    body = bodies[0];
    body.body.visible = shown and player.health > 0;
    body.weapon.visible = body.body.visible and bool([edge body.weapon->:UsesModel:->]);
    if not shown {
        return body;
    }
    body.pos = player.pos.sub(Vec3(z=eye_height));
    body.yaw = player.yaw;
    if area is not None {
        move_to_area(body, area);
    }
    if weapon != body.shown_weapon {
        body.shown_weapon = weapon;
        for old in [edge body.weapon->:UsesModel:->] {
            del old;
        }
        links = [edge body->:Carries:->];
        arms = [body->:Carries:->][?:ModelResource];
        for i in range(min(len(links), len(arms))) {
            if links[i].key == weapon {
                body.weapon +>:UsesModel:+> arms[i];
            }
        }
        body.weapon.visible = body.body.visible and bool([edge body.weapon->:UsesModel:->]);
    }
    speed = Vec3(x=player.velocity.x, y=player.velocity.y).length();
    frame = body.stand_frame;
    blend = 0.0;
    following = frame;
    if speed > 10.0 and body.run_frames {
        position = seconds * body.run_rate;
        index = int(position) % len(body.run_frames);
        frame = body.run_frames[index];
        following = body.run_frames[(index + 1) % len(body.run_frames)];
        blend = position - float(int(position));
    }
    for visual in [body.body, body.weapon] {
        visual.first = frame;
        visual.second = following;
        visual.blend = blend;
    }
    return body;
}
