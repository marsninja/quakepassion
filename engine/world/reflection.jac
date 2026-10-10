"""The player's own body, which Q3 draws only where the player can see
themselves: in mirrors and portals (RF_THIRD_PERSON), and in the death view
(cg.renderingThirdPerson), where it is seen dying and lying dead. It follows
the player each frame on the same rig as every other Q3 body, holding the
current weapon."""
import from .world { World, Entity, Player, Area, move_to_area }
import from .models { HasVisual, PlayerRig, WeaponKit }
import from .player_rig { PoseRig, hold_kit, rig_sound }
import from .vitals { q3_gibbed }
import from ..math.vec3 { Vec3 }

"""`cues` are the sounds its poses have cued that nobody has played yet."""
node PlayerBody(Entity) {
    has body: PlayerRig = PlayerRig(),
        seconds: float = -1.0,
        shots: int = 0,
        cues: list[str] = [];
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

"""Put the body where the player is, with the weapon they hold, and pose its
rig from their movement. The sounds the pose cues wait on the body. The dead
hold nothing (player_die: WP_NONE), and a body gibbed at its death makes no
death cry (EV_GIB_PLAYER)."""
def pose_player_body(
    body: PlayerBody,
    player: Player,
    eye_height: float,
    weapon: str,
    seconds: float,
    hurt: bool = False,
    shots: int = -1
) {
    rig = body.body;
    body.pos = player.pos.sub(Vec3(z=eye_height));
    body.yaw = player.yaw;
    held = weapon if player.health > 0 else "";
    if held != rig.weapon {
        links = [edge body->:Carries:->];
        arms = [body->:Carries:->][?:WeaponKit];
        chosen: WeaponKit | None = None;
        for i in range(min(len(links), len(arms))) {
            if links[i].key == held {
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
        gibbed=q3_gibbed(player)
    );
    body.cues.extend([rig_sound(rig, cue) for cue in posed.sounds]);
}

"""Keep the body on the player (pose_player_body) and return the sounds its
poses have cued since they were last played (cg_event.c: pain, death, jumps,
landings and footsteps). `shots` counts the player's shots so the torso
plays its attacks."""
def follow_body(world: World, player: Player, eye_height: float, weapon: str, seconds: float, hurt: bool = False, shots: int = -1) -> list[str] {
    bodies = [world->:HasBody:->][?:PlayerBody];
    if not bodies {
        return [];
    }
    body = bodies[0];
    pose_player_body(body, player, eye_height, weapon, seconds, hurt, shots);
    heard = body.cues;
    body.cues = [];
    return heard;
}

"""Pose the body where the player is and show it, or hide it again. A body
that has gibbed is not there to show (GibEntity: ET_INVISIBLE)."""
def show_body(world: World, player: Player, eye_height: float, weapon: str, seconds: float, shown: bool, area: Area | None = None, shots: int = -1) -> PlayerBody | None {
    bodies = [world->:HasBody:->][?:PlayerBody];
    if not bodies {
        return None;
    }
    body = bodies[0];
    rig = body.body;
    rig.visible = shown and not q3_gibbed(player);
    if not shown {
        return body;
    }
    if area is not None {
        move_to_area(body, area);
    }
    pose_player_body(body, player, eye_height, weapon, seconds, shots=shots);
    return body;
}
