"""The player's own body, which Q3 draws only where the player can see
themselves: in mirrors and portals (RF_THIRD_PERSON). It follows the player
each frame on the same rig as every other Q3 body, holding the current
weapon."""
import from .world { World, Entity, Player, Area, move_to_area }
import from .models { HasVisual, PlayerRig, WeaponKit }
import from .player_rig { PoseRig, hold_kit, rig_sound }
import from ..math.vec3 { Vec3 }

node PlayerBody(Entity) {
    has body: PlayerRig = PlayerRig(),
        seconds: float = -1.0,
        shots: int = 0;
}

edge HasBody: World --> PlayerBody {}
edge Carries: PlayerBody --> WeaponKit {
    has key: str = "";
}

"""A body wearing `rig`, hidden until a portal view shows it."""
def player_body(rig: PlayerRig) -> PlayerBody {
    body = PlayerBody(body=rig);
    body +>:HasVisual:+> rig;
    rig.visible = False;
    return body;
}

"""Keep the body on the player: where they stand, the weapon they hold, and
the rig posed from their movement. Returns the sounds its cues play
(cg_event.c: pain, death, jumps, landings and footsteps). `shots` counts the
player's shots so the torso plays its attacks."""
def follow_body(world: World, player: Player, eye_height: float, weapon: str, seconds: float, hurt: bool = False, shots: int = -1, gibbed: bool = False) -> list[str] {
    bodies = [world->:HasBody:->][?:PlayerBody];
    if not bodies {
        return [];
    }
    body = bodies[0];
    rig = body.body;
    body.pos = player.pos.sub(Vec3(z=eye_height));
    body.yaw = player.yaw;
    if weapon != rig.weapon {
        links = [edge body->:Carries:->];
        arms = [body->:Carries:->][?:WeaponKit];
        chosen: WeaponKit | None = None;
        for i in range(min(len(links), len(arms))) {
            if links[i].key == weapon {
                chosen = arms[i];
            }
        }
        hold_kit(rig, chosen);
    }
    dt = seconds - body.seconds if body.seconds >= 0.0 else 0.0;
    body.seconds = seconds;
    flat = Vec3(x=player.velocity.x, y=player.velocity.y);
    posed = rig spawn PoseRig(
        dt=max(0.0, min(0.25, dt)),
        grounded=player.grounded,
        velocity=player.velocity,
        wish=flat.normalized() if flat.length() > 10.0 else Vec3(),
        yaw=player.yaw,
        pitch=player.pitch,
        water_depth=player.water_depth,
        crouched=player.crouched,
        alive=player.health > 0,
        health=player.health,
        hurt=hurt,
        shots=shots,
        gibbed=gibbed
    );
    return [rig_sound(rig, cue) for cue in posed.sounds];
}

"""Pose the body where the player stands and show it, or hide it again."""
def show_body(world: World, player: Player, eye_height: float, weapon: str, seconds: float, shown: bool, area: Area | None = None, shots: int = -1) -> PlayerBody | None {
    bodies = [world->:HasBody:->][?:PlayerBody];
    if not bodies {
        return None;
    }
    body = bodies[0];
    rig = body.body;
    rig.visible = shown and player.health > 0;
    if not shown {
        return body;
    }
    if area is not None {
        move_to_area(body, area);
    }
    follow_body(world, player, eye_height, weapon, seconds, shots=shots);
    return body;
}
