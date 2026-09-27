"""g_client.c's body queue. When a Q3 player respawns, CopyToBodyQue leaves a
copy of its body where it died, still finishing its death sequence; five
seconds later BodySink lowers it into the floor a unit every tenth of a second
and removes it after a second and a half. Eight bodies are kept at most. A body
still takes damage, and bursts into gibs once its health reaches GIB_HEALTH
(g_combat.c body_die)."""
import from .world { World, Entity, Area, In, move_to_area }
import from .models { PlayerRig, LerpFrame, ModelResource, Wears, HasVisual }
import from .player_rig { PoseRig }
import from .gibs { GibRule, GibsInto, throw_gibs, gibs_at }
import from .speakers { Speaker }
import from ..math.vec3 { Vec3 }

# g_local.h BODY_QUEUE_SIZE.
glob BODY_QUEUE_SIZE: int = 8;

"""A body left behind. `remains` is its health, below zero; `gibs` how it
comes apart (None once it cannot, as for a body already gibbed) and
`burst_sound` the speaker that voices it."""
node Corpse(Entity) {
    has body: PlayerRig = PlayerRig(),
        age: float = 0.0,
        order: int = 0,
        eye_height: float = 26.0,
        remains: int = 0,
        seed: int = 1,
        gibs: GibRule | None = None,
        burst_sound: Speaker | None = None;
}

edge HasCorpse: World --> Corpse {}

def copy_lerp_frame(frame: LerpFrame) -> LerpFrame {
    return LerpFrame(
        animation=frame.animation,
        toggle=frame.toggle,
        old_frame=frame.old_frame,
        frame=frame.frame,
        old_time=frame.old_time,
        frame_time=frame.frame_time,
        start_time=frame.start_time,
        backlerp=frame.backlerp,
        yaw=frame.yaw,
        yawing=frame.yawing,
        pitch=frame.pitch,
        pitching=frame.pitching
    );
}

"""CopyToBodyQue: a dead body left where `actor` fell, wearing the same part
models and carrying on with its death sequence. It keeps the dead player's
health (`remains`) and, while that is above `gibs`' threshold, its gib
models, so it can still be blown apart."""
def leave_corpse(
    world: World,
    actor: Entity,
    rig: PlayerRig,
    remains: int = 0,
    gibs: GibRule | None = None,
    burst_sound: Speaker | None = None,
    eye_height: float = 26.0
) -> Corpse | None {
    if not rig.visible or rig.alive {
        return None;
    }
    areas = [actor->:In:->][?:Area];
    if not areas {
        return None;
    }
    copy = PlayerRig(
        offset=rig.offset.add(Vec3()),
        clips=rig.clips,
        clock=rig.clock,
        legs=copy_lerp_frame(rig.legs),
        torso=copy_lerp_frame(rig.torso),
        legs_angles=rig.legs_angles.add(Vec3()),
        torso_angles=rig.torso_angles.add(Vec3()),
        head_angles=rig.head_angles.add(Vec3()),
        legs_anim=rig.legs_anim,
        legs_toggle=rig.legs_toggle,
        torso_anim=rig.torso_anim,
        torso_toggle=rig.torso_toggle,
        alive=False,
        character=rig.character,
        voice=rig.voice,
        footsteps=rig.footsteps,
        head_offset=rig.head_offset,
        fixed_legs=rig.fixed_legs,
        fixed_torso=rig.fixed_torso
    );
    links = [edge rig->:Wears:->];
    parts = [rig->:Wears:->][?:ModelResource];
    for i in range(min(len(links), len(parts))) {
        copy +>:Wears(role=links[i].role):+> parts[i];
    }
    bodies = [world->:HasCorpse:->][?:Corpse];
    newest = 0;
    for body in bodies {
        newest = max(newest, body.order + 1);
    }
    if len(bodies) >= BODY_QUEUE_SIZE {
        oldest = bodies[0];
        for body in bodies {
            if body.order < oldest.order {
                oldest = body;
            }
        }
        remove_corpse(world, oldest);
    }
    corpse = Corpse(pos=actor.pos.add(Vec3()), yaw=actor.yaw, body=copy, order=newest, eye_height=eye_height,
        remains=remains, seed=newest * 7919 + 1, burst_sound=burst_sound);
    # "don't take more damage if already gibbed"
    if gibs is not None and not gibs_at(gibs, remains) {
        corpse.gibs = gibs;
        cuts = [edge actor->:GibsInto:->];
        pieces = [actor->:GibsInto:->][?:ModelResource];
        for i in range(min(len(cuts), len(pieces))) {
            corpse +>:GibsInto(count=cuts[i].count, head=cuts[i].head):+> pieces[i];
        }
    }
    corpse +>:HasVisual:+> copy;
    move_to_area(corpse, areas[0]);
    world +>:HasCorpse:+> corpse;
    return corpse;
}

def remove_corpse(world: World, corpse: Corpse) {
    corpse.body.visible = False;
    for link in [edge corpse->:In:->] {
        del link;
    }
    world del ->:HasCorpse:-> corpse;
}

"""G_Damage on a body: its health falls, and at GIB_HEALTH body_die throws its
gibs (CG_GibPlayer) and the body is gone. Returns whether it burst."""
def damage_corpse(world: World, corpse: Corpse, amount: int) -> bool {
    rule = corpse.gibs;
    if rule is None or amount <= 0 {
        return False;
    }
    corpse.remains -= amount;
    if not gibs_at(rule, corpse.remains) {
        return False;
    }
    throw_gibs(world, corpse, rule, corpse.pos.sub(Vec3(z=corpse.eye_height)), -corpse.remains, corpse.seed);
    speaker = corpse.burst_sound;
    if speaker is not None {
        speaker.origin = corpse.pos.add(Vec3());
        speaker.requests += 1;
    }
    corpse.gibs = None;
    remove_corpse(world, corpse);
    return True;
}

"""Whether a body can still be shot apart."""
def shootable(corpse: Corpse) -> bool {
    return corpse.gibs is not None and corpse.body.visible;
}

"""BodySink: bodies settle for five seconds, sink for one and a half, and go."""
walker CorpseTick {
    has dt: float,
        world: World | None = None;

    can begin with World entry {
        self.world = here;
        visit [here->:HasCorpse:->];
    }

    can settle with Corpse entry {
        here.age += self.dt;
        here.body spawn PoseRig(dt=self.dt, alive=False, yaw=here.yaw);
        if here.age > 5.0 {
            here.pos = here.pos.sub(Vec3(z=10.0 * self.dt));
        }
        world = self.world;
        if here.age > 6.5 and world is not None {
            remove_corpse(world, here);
        }
    }
}
