"""Shared translating proximity doors. Unsupported activation stays static."""
import math;
import from .combat { Opponent, HasOpponent, damage_opponent }
import from .damage { Damage, blast_strength }
import from .inventory { quantity, AdjustInventory }
import from .world { World, Player }
import from .signals {
    Signal,
    Fire,
    Targets,
    Kills,
    HasSignal,
    DelayedUse,
    progress_for,
    note_chain
}
import from ..formats.bsp { Bsp, MapEntity }
import from ..physics.collision { CollisionMap, Sweep, Trace }
import from .liquids { LiquidSpace, LiquidVolume, HasLiquid }
import from .speakers { Speaker, HasSpeaker }
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }
import from ..math.orientation { Basis, quake_basis }
import from .mover_ramp { MoverRamp, q2_mover_ramp, ramp_step, ramp_rest }

edge HasDoor: World --> Door {}
edge DoorLink: Door --> Door {}
edge DoorMember: Door --> Door {}

walker AssembleDoors {
    has members: list[Door] = [],
        ids: list[int] = [];

    can collect with Door entry {
        if here.model in self.ids {
            return;
        }
        self.ids.append(here.model);
        self.members.append(here);
        visit [here->:DoorLink:->];
    }
}

"""A func_water door carries its liquid volumes with it."""
edge Floods: Door --> LiquidVolume {}

node Door {
    has model: int,
        trigger: AABB,
        travel: Vec3,
        speed: float,
        hold_time: float,
        kind: str = "door",
        health: int = 0,
        max_health: int = 0,
        shared_health: bool = False,
        fire_on_start: bool = False,
        toggle: bool = False,
        contact_remaining: float = 0.0,
        rest: Vec3 = Vec3(),
        activation: Signal = Signal(),
        keys: list[str] = [],
        unlocked: bool = False,
        automatic: bool = True,
        monster_touch: bool = True,
        requested: bool = False,
        names: list[str] = [],
        enabled: bool = True,
        team: str = "",
        linkable: bool = True,
        bounds: AABB = AABB(mins=Vec3(), maxs=Vec3()),
        faces: list[int] = [],
        hulls: list[int] = [],
        origins: list[Vec3] = [],
        position: float = 0.0,
        state: str = "closed",
        remaining: float = 0.0,
        rotation: Vec3 = Vec3(),
        rest_angles: Vec3 = Vec3(),
        pivot: Vec3 = Vec3(),
        damage: int = 0,
        crusher: bool = False,
        crush_wait: float = 0.0,
        flooding: bool = False,
        entity: int = -1,
        reason: str = "",
        touch_message: str = "",
        message_wait: float = 0.0,
        talk: str = "",
        key_message: str = "",
        key_try: str = "",
        key_use: str = "",
        voices: list[str] = [],
        start_voice: Speaker | None = None,
        move_voice: Speaker | None = None,
        stop_voice: Speaker | None = None,
        voice_on_open: bool = False,
        voiced_state: str = "",
        ramp: MoverRamp | None = None;
}

"""The start, moving (looped) and stop sounds of a mover. Q1 doors.qc,
plats.qc, buttons.qc and func_train pick them by `sounds` (the moving sound
loops by its cue point until the stop sound replaces it); Q2 g_func.c uses
dr1_*, pt1_* and butn2 unless `sounds` is 1, and a train's `noise` loops."""
def mover_voices(game: str, kind: str, fields: dict[str, str]) -> list[str] {
    style = int(float(fields.get("sounds", "0")));
    if game == "q1" {
        if kind == "func_door" {
            pairs = [
                ["", ""],
                ["doors/doormv1.wav", "doors/drclos4.wav"],
                ["doors/hydro1.wav", "doors/hydro2.wav"],
                ["doors/stndr1.wav", "doors/stndr2.wav"],
                ["doors/ddoor1.wav", "doors/ddoor2.wav"]
            ];
            pair = pairs[style] if 0 <= style and style < len(pairs) else ["", ""];
            return ["", pair[0], pair[1]];
        }
        if kind == "func_plat" {
            if style == 1 {
                return ["", "plats/plat1.wav", "plats/plat2.wav"];
            }
            return ["", "plats/medplat1.wav", "plats/medplat2.wav"];
        }
        if kind == "func_button" {
            presses = ["buttons/airbut1.wav", "buttons/switch21.wav", "buttons/switch02.wav", "buttons/switch04.wav"];
            return [presses[style] if 0 <= style and style < len(presses) else "", "", ""];
        }
        if kind == "func_train" {
            return ["", "plats/train1.wav", "plats/train2.wav"] if style == 1 else ["", "", ""];
        }
        if kind == "func_door_secret" {
            if style == 1 {
                return ["doors/latch2.wav", "doors/winch2.wav", "doors/drclos4.wav"];
            }
            if style == 2 {
                return ["doors/airdoor2.wav", "doors/airdoor1.wav", "doors/airdoor2.wav"];
            }
            return ["doors/basesec2.wav", "doors/basesec1.wav", "doors/basesec2.wav"];
        }
        return ["", "", ""];
    }
    if game == "q2" {
        if kind in ["func_door", "func_door_rotating"] and style != 1 {
            return ["doors/dr1_strt.wav", "doors/dr1_mid.wav", "doors/dr1_end.wav"];
        }
        if kind == "func_plat" {
            return ["plats/pt1_strt.wav", "plats/pt1_mid.wav", "plats/pt1_end.wav"];
        }
        if kind == "func_button" and style != 1 {
            return ["switches/butn2.wav", "", ""];
        }
        if kind == "func_water" and style in [1, 2] {
            return ["world/mov_watr.wav", "", "world/stp_watr.wav"];
        }
        if kind == "func_train" and fields.get("noise", "") {
            noise = fields["noise"];
            return ["", noise if noise.endswith(".wav") else noise + ".wav", ""];
        }
    }
    return ["", "", ""];
}

"""A positional mover sound as a world speaker (ATTN_NORM for Q1, ATTN_STATIC
for Q2's movers)."""
def mover_voice(world: World, game: str, path: str, looping: bool, origin: Vec3) -> Speaker | None {
    if not path {
        return None;
    }
    voice = Speaker(
        path="sound/" + path,
        origin=origin,
        looping=looping,
        attenuation=3.0 if game == "q2" else 1.0
    );
    world +>:HasSpeaker:+> voice;
    return voice;
}

"""Q1 door_touch and Q2 trigger_key wording for a missing key."""
def key_text(game: str, key: str, worldtype: int) -> str {
    if game == "q1" {
        metal = "gold" if key == "key_gold" else "silver";
        noun = "key" if worldtype == 0 else ("runekey" if worldtype == 1 else "keycard");
        return "You need the " + metal + " " + noun;
    }
    return "Need " + key.replace("key_", "").replace("_", " ");
}

"""Whether a player standing at `origin` touches one of the mover's brushes
at its current pose (a one-unit reach around the player box)."""
def touches_mover(leader: Door, origin: Vec3) -> bool {
    members = [leader];
    members.extend([leader->:DoorMember:->][?:Door]);
    for part in members {
        shift = part.rest.add(part.travel.scale(leader.position));
        lo = part.bounds.mins.add(shift);
        hi = part.bounds.maxs.add(shift);
        if origin.x + 17.0 >= lo.x and origin.x - 17.0 <= hi.x
            and origin.y + 17.0 >= lo.y and origin.y - 17.0 <= hi.y
            and origin.z + 33.0 >= lo.z and origin.z - 25.0 <= hi.z {
            return True;
        }
    }
    return False;
}

"""Full travel of a mover: units for sliding movers, degrees for rotating doors."""
def door_span(door: Door) -> float {
    if door.rotation.length() > 0.0 {
        return door.rotation.length();
    }
    return door.travel.length();
}

def door_turn(part: Door, position: float) -> Basis | None {
    if part.rotation.length() == 0.0 and part.rest_angles.length() == 0.0 {
        return None;
    }
    return quake_basis(part.rest_angles.add(part.rotation.scale(position)));
}

"""Join each func_water door to the liquid volumes of its brush model."""
def flood_doors(world: World, liquids: LiquidSpace) {
    volumes = [liquids->:HasLiquid:->][?:LiquidVolume];
    for door in [world->:HasDoor:->][?:Door] {
        if not door.flooding {
            continue;
        }
        for volume in volumes {
            if volume.model == door.model {
                door +>:Floods:+> volume;
            }
        }
    }
}

"""Place one mover's faces and hulls at `position` along its travel."""
def apply_pose(part: Door, position: float, bsp: Bsp, collision: CollisionMap) {
    motion = part.rest.add(part.travel.scale(position));
    turn = door_turn(part, position);
    for volume in [part->:Floods:->][?:LiquidVolume] {
        volume.offset = motion;
    }
    for face in part.faces {
        bsp.faces[face].motion = motion;
        bsp.faces[face].turn = turn;
        bsp.faces[face].pivot = part.pivot;
    }
    for j in range(len(part.hulls)) {
        collision.set_offset(part.hulls[j], part.origins[j].add(motion));
        if turn is not None {
            collision.set_turn(part.hulls[j], turn);
        }
    }
}

"""Sweep an actor from `start` against a mover's old pose to `finish` against its
new pose, in the mover's own frame, so moving and turning hulls both block."""
def pose_sweep(
    collision: CollisionMap,
    part: Door,
    j: int,
    start: Vec3,
    finish: Vec3,
    before: float,
    after: float,
    top_drop: float
) -> Trace {
    old_base = part.origins[j].add(part.rest.add(part.travel.scale(before)));
    new_base = part.origins[j].add(part.rest.add(part.travel.scale(after)));
    local_start = start.sub(old_base);
    local_finish = finish.sub(new_base);
    old_turn = door_turn(part, before);
    new_turn = door_turn(part, after);
    if old_turn is not None {
        local_start = old_turn.inverse(local_start);
    }
    if new_turn is not None {
        local_finish = new_turn.inverse(local_finish);
    }
    query = collision.hulls[part.hulls[j]] spawn Sweep(
        top_drop=top_drop, start=local_start, finish=local_finish
    );
    return query.result;
}

walker DoorTick {
    has bsp: Bsp,
        collision: CollisionMap,
        player_origin: Vec3,
        dt: float,
        touching: bool = True,
        player: Player | None = None,
        message: str = "",
        cues: list[str] = [],
        actors: list[Opponent] = [];

    """Start the moving loop and the start sound when a mover sets off; stop
    the loop and play the stop sound when it comes to rest."""
    def voice(mover: Door) {
        moving = mover.state in ["opening", "closing"];
        was = mover.voiced_state in ["opening", "closing"];
        mover.voiced_state = mover.state;
        centre = mover.bounds.center().add(mover.rest).add(mover.travel.scale(mover.position));
        for speaker in [mover.start_voice, mover.move_voice, mover.stop_voice] {
            if speaker is not None {
                speaker.origin = centre;
            }
        }
        if moving and not was {
            start = mover.start_voice;
            if start is not None and (not mover.voice_on_open or mover.state == "opening") {
                start.requests += 1;
            }
            loop = mover.move_voice;
            if loop is not None {
                loop.playing = True;
            }
        } elif was and not moving {
            loop = mover.move_voice;
            if loop is not None {
                loop.playing = False;
            }
            stop = mover.stop_voice;
            if stop is not None {
                stop.requests += 1;
            }
        }
    }

    """Blocked movers hurt what stops them (Q1 door_blocked/plat_crush, Q2
    door_blocked/plat_blocked), at most ten times a second."""
    def crush(mover: Door, victim: Player) {
        if mover.damage <= 0 or victim.health <= 0 or mover.crush_wait > 0.0 {
            return;
        }
        mover.crush_wait = 0.1;
        if isinstance(victim, Opponent) {
            damage_opponent(victim, mover.damage, means="crush");
        } else {
            victim spawn Damage(amount=mover.damage, means="crush");
        }
    }

    # Crushers and doors with a negative wait keep pushing; others reverse.
    def blocked(mover: Door) {
        if mover.crusher or (mover.kind == "door" and mover.hold_time < 0.0) {
            return;
        }
        if mover.state == "opening" {
            mover.state = "closing";
        } elif mover.state == "closing" {
            mover.state = "opening";
        }
    }

    can start with World entry {
        if self.dt > 0.0 {
            self.actors = [
                actor
                for actor in [here->:HasOpponent:->][?:Opponent]
                if actor.health > 0 and not actor.dormant and not actor.rule.inert
            ];
            visit [here->:HasDoor:->];
        }
    }

    can advance with Door entry {
        if self.dt <= 0.0 or not here.enabled {
            return;
        }
        # killtarget removes the whole mover group (G_FreeEdict).
        if here.activation.killed {
            here.enabled = False;
            members = [here];
            members.extend([here->:DoorMember:->][?:Door]);
            for part in members {
                for face in part.faces {
                    self.bsp.faces[face].hidden = True;
                }
                for index in part.hulls {
                    self.collision.set_disabled(index, True);
                }
            }
            return;
        }
        here.crush_wait = max(0.0, here.crush_wait - self.dt);
        here.message_wait = max(0.0, here.message_wait - self.dt);
        self.voice(here);
        origin = self.player_origin;
        if self.player is not None {
            origin = self.player.pos.sub(Vec3(z=self.collision.eye_height));
        }
        # Q1 door_touch / Q2 door_touch: a door that opens elsewhere tells the
        # player who touches it, until it is first used.
        if here.touch_message
            and here.message_wait <= 0.0
            and self.touching
            and self.player is not None
            and self.player.health > 0
            and here.state == "closed"
            and touches_mover(here, origin) {
            self.message = here.touch_message;
            if here.talk {
                self.cues.append(here.talk);
            }
            here.message_wait = 2.0 if here.talk == "sound/misc/talk.wav" else 5.0;
        }
        rider = False;
        if here.kind == "platform"
            and self.player is not None
            and self.player.velocity.z <= 0.0 {
            for index in here.hulls {
                local = origin.sub(self.collision.offsets[index]);
                support = self.collision.hulls[index] spawn Sweep(
                    top_drop=self.collision.top_drop,
                    start=local,
                    finish=local.add(Vec3(z=-0.25))
                );
                if not support.result.start_solid
                    and support.result.fraction < 1.0
                    and support.result.normal.z >= 0.7 {
                    rider = True;
                }
            }
        }
        riders: list[Opponent] = [];
        monster_contact = False;
        if here.automatic and here.monster_touch and (not here.keys or here.unlocked) {
            for actor in self.actors {
                actor_origin = actor.pos.sub(Vec3(z=actor.eye_height));
                if here.kind in ["door", "platform"]
                    and here.trigger.contains(actor_origin) {
                    monster_contact = True;
                }
            }
        }
        if here.kind == "platform" {
            for actor in self.actors {
                if actor.velocity.z > 0.0 {
                    continue;
                }
                actor_origin = actor.pos.sub(Vec3(z=actor.eye_height));
                for index in here.hulls {
                    local = actor_origin.sub(self.collision.offsets[index]);
                    support = self.collision.hulls[index] spawn Sweep(
                        top_drop=0.0, start=local, finish=local.add(Vec3(z=-0.25))
                    );
                    if not support.result.start_solid
                        and support.result.fraction < 1.0
                        and support.result.normal.z >= 0.7 {
                        riders.append(actor);
                        break;
                    }
                }
            }
        }
        contact = here.automatic and here.trigger.contains(origin);
        if here.kind == "platform" {
            contact = (self.touching and (contact or (rider and here.state == "open")))
                or monster_contact
                or (bool(riders) and here.state == "open");
            if here.state == "closing" {
                contact = False;
            }
        } elif here.kind == "door" {
            contact = contact or monster_contact;
        }
        if here.kind == "button" {
            contact = False;
            if self.touching and here.automatic {
                for index in here.hulls {
                    for delta in [
                        Vec3(x=0.125),
                        Vec3(x=-0.125),
                        Vec3(y=0.125),
                        Vec3(y=-0.125),
                        Vec3(z=0.125),
                        Vec3(z=-0.125)
                    ] {
                        local = origin.sub(self.collision.offsets[index]);
                        probe = self.collision.hulls[index] spawn Sweep(
                            top_drop=self.collision.top_drop,
                            start=local,
                            finish=local.add(delta)
                        );
                        if probe.result.start_solid or probe.result.fraction < 1.0 {
                            contact = True;
                        }
                    }
                }
            }
        }
        here.contact_remaining = max(0.0, here.contact_remaining - self.dt);
        if here.toggle and contact {
            if here.contact_remaining > 0.0 {
                contact = False;
            } else {
                here.contact_remaining = 1.0;
            }
        }
        near = here.requested or here.activation.pending > 0 or contact;
        if here.keys and not here.unlocked {
            here.requested = False;
            here.activation.pending = 0;
            if not near
                or not self.touching
                or self.player is None
                or self.player.health <= 0 {
                return;
            }
            for key in here.keys {
                if quantity(self.player.inventory, key) <= 0 {
                    # door_touch: the key message and try sound every 2 seconds.
                    if here.message_wait <= 0.0 {
                        self.message = here.key_message
                            or "Need " + key.replace("key_", "").replace("_", " ");
                        if here.key_try {
                            self.cues.append(here.key_try);
                        }
                        here.message_wait = 2.0;
                    }
                    return;
                }
            }
            for key in here.keys {
                self.player.inventory spawn AdjustInventory(kind=key, amount=-1);
            }
            here.unlocked = True;
            here.touch_message = "";
            if here.key_use {
                self.cues.append(here.key_use);
            } else {
                self.message = "Door unlocked";
            }
            here.hold_time = -1.0;
        }
        here.requested = False;
        here.activation.pending = 0;
        if here.state == "locked" {
            if not near {
                return;
            }
            here.state = "closing";
            here.automatic = True;
            near = False;
        }
        if here.kind == "button" and here.state == "open" {
            near = False;
        }
        if near and here.toggle and here.state in ["opening", "open"] {
            here.state = "closing";
            here.health = here.max_health;
            for part in [here->:DoorMember:->][?:Door] {
                part.health = part.max_health;
            }
            near = False;
        }
        if near {
            # door_use: messages are for touch only and end with the first use.
            here.touch_message = "";
            if here.state == "closed" or here.state == "closing" {
                here.state = "opening";
                if here.fire_on_start {
                    fired = here.activation spawn Fire(
                        inventory=self.player.inventory
                            if self.player is not None
                            else None
                    );
                    if fired.message {
                        self.message = fired.message;
                    }
                }
            }
            here.remaining = here.hold_time;
        }
        # A pressed button shows its alternate (Q1 +a) or next (Q2) texture.
        if here.kind == "button" {
            pressed = 1 if here.state in ["opening", "open"] else 0;
            for face in here.faces {
                self.bsp.faces[face].frame = pressed;
            }
        }
        if here.state == "open" {
            if not near and not here.toggle and here.hold_time >= 0.0 {
                here.remaining -= self.dt;
                if here.remaining <= 0.0 {
                    here.state = "closing";
                    here.health = here.max_health;
                    for part in [here->:DoorMember:->][?:Door] {
                        part.health = part.max_health;
                    }
                }
            }
            return;
        }
        if here.state == "closed" {
            return;
        }
        direction = 1.0 if here.state == "opening" else -1.0;
        # Q2 Think_AccelMove ramps plats (and doors given accel/decel).
        travel = here.speed * self.dt;
        ramp = here.ramp;
        if ramp is not None {
            travel = ramp_step(
                ramp,
                1 if direction > 0.0 else -1,
                door_span(here) * (1.0 - here.position if direction > 0.0 else here.position),
                here.speed,
                self.dt
            );
        }
        next_position = max(
            0.0, min(1.0, here.position + direction * travel / door_span(here))
        );
        members = [here];
        members.extend([here->:DoorMember:->][?:Door]);
        carried = origin;
        if rider {
            carried = origin.add(here.travel.scale(next_position - here.position));
            path = self.collision.trace(origin, carried, exclude=here.hulls);
            if path.start_solid or path.fraction < 1.0 {
                here.state = "closing" if here.state == "opening" else "opening";
                return;
            }
        }
        # Validate the whole group before changing any render or collision state.
        for part in members {
            for j in range(len(part.hulls)) {
                query = pose_sweep(
                    self.collision,
                    part,
                    j,
                    origin,
                    carried,
                    here.position,
                    next_position,
                    self.collision.top_drop
                );
                if query.start_solid or query.fraction < 1.0 {
                    if self.player is not None and self.touching {
                        self.crush(here, self.player);
                    }
                    self.blocked(here);
                    return;
                }
            }
        }
        actor_destinations: list[Vec3] = [];
        for actor in self.actors {
            actor_origin = actor.pos.sub(Vec3(z=actor.eye_height));
            destination = actor_origin;
            if actor in riders {
                destination = actor_origin.add(
                    here.travel.scale(next_position - here.position)
                );
                path = self.collision.trace(
                    actor_origin, destination, exclude=here.hulls, top_drop=0.0
                );
                if path.start_solid or path.fraction < 1.0 {
                    here.state = "closing" if here.state == "opening" else "opening";
                    return;
                }
            }
            actor_destinations.append(destination);
        }
        # Living opponents obstruct the same swept mover volume as the player.
        # Validate everyone before committing any member of a linked door group.
        for actor_index in range(len(self.actors)) {
            actor_origin = self.actors[actor_index].pos.sub(
                Vec3(z=self.actors[actor_index].eye_height)
            );
            destination = actor_destinations[actor_index];
            for part in members {
                for j in range(len(part.hulls)) {
                    index = part.hulls[j];
                    if len(self.collision.bounds) == len(self.collision.hulls) {
                        bounds = self.collision.bounds[index];
                        if (
                            actor_origin.x < bounds.mins.x
                            and destination.x < bounds.mins.x
                        )
                            or (
                                actor_origin.x > bounds.maxs.x
                                and destination.x > bounds.maxs.x
                            )
                            or (
                                actor_origin.y < bounds.mins.y
                                and destination.y < bounds.mins.y
                            )
                            or (
                                actor_origin.y > bounds.maxs.y
                                and destination.y > bounds.maxs.y
                            )
                            or (
                                actor_origin.z < bounds.mins.z
                                and destination.z < bounds.mins.z
                            )
                            or (
                                actor_origin.z > bounds.maxs.z
                                and destination.z > bounds.maxs.z
                            ) {
                            continue;
                        }
                    }
                    query = pose_sweep(
                        self.collision,
                        part,
                        j,
                        actor_origin,
                        destination,
                        here.position,
                        next_position,
                        0.0
                    );
                    if query.start_solid or query.fraction < 1.0 {
                        self.crush(here, self.actors[actor_index]);
                        self.blocked(here);
                        return;
                    }
                }
            }
        }
        for part in members {
            part.position = next_position;
            apply_pose(part, next_position, self.bsp, self.collision);
        }
        for actor_index in range(len(self.actors)) {
            actor = self.actors[actor_index];
            if actor in riders {
                actor.pos = actor_destinations[actor_index].add(
                    Vec3(z=actor.eye_height)
                );
                actor.grounded = True;
                actor.route = [];
                actor.route_wait = 0.0;
            }
        }
        if rider and self.player is not None {
            self.player.pos = carried.add(Vec3(z=self.collision.eye_height));
            self.player.grounded = True;
        }
        # A ramped move sits still for its first frame, so arrival is judged
        # in the direction of travel.
        arrived = (next_position == 1.0 and direction > 0.0)
            or (next_position == 0.0 and direction < 0.0);
        if ramp is not None and arrived {
            ramp_rest(ramp);
        }
        if next_position == 1.0 and direction > 0.0 {
            here.state = "open";
            here.remaining = here.hold_time;
            if not here.fire_on_start {
                fired = here.activation spawn Fire(
                    inventory=self.player.inventory if self.player is not None else None
                );
                if fired.message {
                    self.message = fired.message;
                }
            }
        } elif next_position == 0.0 and direction < 0.0 {
            here.state = "closed";
        }
    }
}

def model_bounds(bsp: Bsp, model: int) -> AABB {
    record = bsp.models[model];
    lo = Vec3(x=1.0e30, y=1.0e30, z=1.0e30);
    hi = Vec3(x=-1.0e30, y=-1.0e30, z=-1.0e30);
    for i in range(record.first_face, record.first_face + record.face_count) {
        for v in bsp.faces[i].vertices {
            lo = Vec3(x=min(lo.x, v.x), y=min(lo.y, v.y), z=min(lo.z, v.z));
            hi = Vec3(x=max(hi.x, v.x), y=max(hi.y, v.y), z=max(hi.z, v.z));
        }
    }
    return AABB(mins=lo, maxs=hi);
}

def overlaps(a: AABB, b: AABB) -> bool {
    return a.mins.x <= b.maxs.x
        and a.maxs.x >= b.mins.x
        and a.mins.y <= b.maxs.y
        and a.maxs.y >= b.mins.y
        and a.mins.z <= b.maxs.z
        and a.maxs.z >= b.mins.z;
}

def door_direction(entity: MapEntity) -> Vec3 {
    yaw = float(entity.fields.get("angle", "0"));
    pitch = 0.0;
    if entity.fields.get("angles", "") {
        angles = entity.fields["angles"].split();
        if len(angles) != 3 {
            raise ValueError("Invalid door angles");
        }
        pitch = float(angles[0]);
        yaw = float(angles[1]);
    }
    if yaw == -1.0 {
        return Vec3(z=1.0);
    }
    if yaw == -2.0 {
        return Vec3(z=-1.0);
    }
    yaw *= math.pi / 180.0;
    pitch *= math.pi / 180.0;
    return Vec3(
        x=math.cos(pitch) * math.cos(yaw),
        y=math.cos(pitch) * math.sin(yaw),
        z=-math.sin(pitch)
    );
}

"""Build movers. Level loading passes `connect=False` and resolves every
activation chain once, after all other activatable entities are loaded."""
def load_doors(world: World, bsp: Bsp, collision: CollisionMap, connect: bool = True) {
    candidates: list[Door] = [];
    for index in range(len(bsp.entities)) {
        entity = bsp.entities[index];
        fields = entity.fields;
        kind = fields.get("classname", "");
        rotating = kind == "func_door_rotating" and bsp.game == "q2";
        # g_func.c SP_func_water: a door whose brush is liquid.
        water = kind == "func_water" and bsp.game == "q2";
        if kind not in ["func_door", "func_button", "func_plat"] and not rotating and not water {
            continue;
        }
        # Keep unsupported members in the graph so a locked half disables its group.
        flags = int(fields.get("spawnflags", "0"));
        allowed = 3840 if bsp.game == "q1" else (7936 if bsp.game == "q2" else 0);
        if kind == "func_door" {
            allowed |= 1;
            if bsp.game in ["q1", "q2"] {
                allowed |= 32;
            }
            if bsp.game == "q2" {
                allowed |= 8;
            }
            if bsp.game == "q1" {
                allowed |= 28;
            }
        }
        if kind == "func_plat" and bsp.game != "q3" {
            allowed |= 1;
        }
        # Q1 buttons.qc reads no spawnflags; Q2 func_door's bit 2 is unused ("x").
        if kind == "func_button" and bsp.game == "q1" {
            allowed |= 1;
        }
        if kind == "func_door" and bsp.game == "q2" {
            allowed |= 2;
        }
        # Q2/Q3 CRUSHER; Q2 rotating doors add REVERSE and the X/Y axis flags.
        if kind == "func_door" and bsp.game in ["q2", "q3"] {
            allowed |= 5;
        }
        # g_func.c SP_func_door: ANIMATED (16) and ANIMATED_FAST (64) only
        # animate the door's textures (EF_ANIM_ALL, EF_ANIM_ALLFAST).
        if kind == "func_door" and bsp.game == "q2" {
            allowed |= 16 | 64;
        }
        if rotating {
            allowed |= 1 | 2 | 4 | 8 | 16 | 32 | 64 | 128;
        }
        if water {
            allowed |= 1;
        }
        health = max(0, int(float(fields.get("health", "0"))));
        reason = "";
        if flags & ~allowed {
            reason = "spawnflags " + str(flags & ~allowed);
        } elif health > 0
            and kind != "func_button"
            and not (kind in ["func_door", "func_door_rotating"] and bsp.game in ["q1", "q2"]) {
            reason = "shootable " + kind;
        }
        # killtarget is a Kills edge fired with the mover's targets.
        name = fields.get("model", "");
        if not name.startswith("*") {
            continue;
        }
        model = int(name[1:]);
        if model <= 0 or model >= len(bsp.models) {
            raise ValueError("Invalid door model");
        }
        bounds = model_bounds(bsp, model);
        direction = door_direction(entity);
        size = bounds.size();
        lip = float(fields.get("lip", "4" if kind == "func_button" else "8"));
        if lip == 0.0 and bsp.game != "q3" {
            lip = 4.0 if kind == "func_button" else 8.0;
        }
        if water {
            lip = float(fields.get("lip", "0"));
        }
        distance = abs(direction.x) * size.x
            + abs(direction.y) * size.y
            + abs(direction.z) * size.z
            - lip;
        if kind == "func_plat" {
            direction = Vec3(z=1.0);
            distance = float(fields.get("height", "0"));
            if distance == 0.0 {
                distance = size.z - lip;
            }
        }
        speed = float(fields.get("speed", "0"));
        hold_time = float(fields.get("wait", "0"));
        if speed == 0.0 {
            speed = 40.0
                if kind == "func_button"
                else (400.0 if bsp.game == "q3" else 100.0);
        }
        if hold_time == 0.0 {
            hold_time = (3.0 if bsp.game == "q2" else 1.0)
                if kind == "func_button"
                else (2.0 if bsp.game == "q3" else 3.0);
        }
        if kind == "func_plat" {
            if float(fields.get("speed", "0")) == 0.0 {
                speed = 150.0 if bsp.game == "q1" else 200.0;
            }
            hold_time = 1.0 if bsp.game == "q3" else 3.0;
        }
        # Water rises at 25 units a second and toggles unless given a wait.
        if water {
            speed = float(fields.get("speed", "0")) or 25.0;
            hold_time = float(fields.get("wait", "0")) or -1.0;
        }
        if rotating {
            # g_func.c SP_func_door_rotating: degrees, 90 by default.
            distance = float(fields.get("distance", "0"));
            if distance == 0.0 {
                distance = 90.0;
            }
        }
        # A mover whose lip swallows its size still runs its cycle and fires its
        # targets (Move_Calc finishes at once); negative distances reverse it.
        if abs(distance) < 0.01 {
            distance = 0.01;
        }
        if speed <= 0.0 and not reason {
            reason = "no speed";
        }
        enabled = not reason;
        # Expand the proximity volume by the standing player extents as well.
        margin = Vec3(x=76.0, y=76.0, z=8.0);
        if kind == "func_button" {
            width = 15.0 if bsp.game == "q3" else 16.0;
            margin = Vec3(x=width + 0.125, y=width + 0.125, z=0.125);
        }
        door = Door(
            model=model,
            kind="platform"
                if kind == "func_plat"
                else ("button" if kind == "func_button" else "door"),
            rest=Vec3(z=-distance) if kind == "func_plat" else Vec3(),
            keys=(["key_gold"] if flags & 8 else [])
                + (["key_silver"] if flags & 16 else [])
                if bsp.game == "q1" and kind == "func_door"
                else (
                    fields["key"].split()
                        if bsp.game == "passion" and fields.get("key", "")
                        else []
                ),
            enabled=enabled,
            health=health,
            max_health=health,
            shared_health=bsp.game == "q1",
            monster_touch=not (bsp.game == "q2" and flags & 8 != 0),
            fire_on_start=kind in ["func_door", "func_door_rotating"]
                and bsp.game in ["q1", "q2"],
            toggle=(kind in ["func_door", "func_door_rotating"]
                and bsp.game in ["q1", "q2"]
                and flags & 32 != 0)
                or (water and hold_time < 0.0),
            automatic=(
                health == 0 and (bsp.game != "q2" or not fields.get("targetname", ""))
            )
                if kind == "func_button"
                else health == 0 and not bool(fields.get("targetname", "")) and not water,
            names=[fields["targetname"]] if fields.get("targetname", "") else [],
            team=fields.get("team", ""),
            linkable=flags & 4 == 0,
            bounds=bounds,
            travel=direction.scale(distance),
            speed=speed,
            hold_time=hold_time,
            ramp=q2_mover_ramp(kind, fields, speed)
                if bsp.game == "q2" and not rotating
                else None,
            trigger=AABB(
                mins=bounds.mins.sub(margin).sub(Vec3(z=32.0)),
                maxs=bounds.maxs.add(margin).add(Vec3(z=24.0))
            )
        );
        message = fields.get("message", "");
        if kind == "func_button" and message and bsp.game in ["q1", "q2"] {
            # A button's message is printed when it fires (SUB_UseTargets).
            door.activation.message = message;
            door.activation.cue = "sound/misc/talk.wav" if bsp.game == "q1" else "sound/misc/talk1.wav";
        }
        # Q1 door_touch prints any door's message; Q2 only a named, unshot door's.
        if kind in ["func_door", "func_door_rotating"]
            and message
            and (bsp.game == "q1" or (bsp.game == "q2" and fields.get("targetname", "") and health == 0)) {
            door.touch_message = message;
            door.talk = "sound/misc/talk.wav" if bsp.game == "q1" else "sound/misc/talk1.wav";
        }
        if door.keys and bsp.game == "q1" {
            worldtype = int(float(bsp.entities[0].fields.get("worldtype", "0"))) if bsp.entities else 0;
            door.key_message = key_text("q1", door.keys[0], worldtype);
            noises = ["med", "rune", "base"];
            noise = noises[worldtype] if 0 <= worldtype and worldtype < 3 else "med";
            door.key_try = "sound/doors/" + noise + "try.wav";
            door.key_use = "sound/doors/" + noise + "use.wav";
        }
        door.voices = mover_voices(bsp.game, kind, fields);
        door.voice_on_open = kind == "func_button";
        # Crush damage defaults: Q1 plats 1, other movers 2 (Q1/Q2/Q3 "dmg").
        door.damage = int(float(fields.get("dmg", "0")));
        if door.damage == 0 and kind != "func_button" {
            door.damage = 1 if kind == "func_plat" and bsp.game == "q1" else 2;
        }
        door.crusher = bsp.game in ["q2", "q3"]
            and kind in ["func_door", "func_door_rotating"]
            and flags & 4 != 0;
        if rotating {
            axis = Vec3(y=1.0);
            if flags & 64 {
                axis = Vec3(z=1.0);
            } elif flags & 128 {
                axis = Vec3(x=1.0);
            }
            if flags & 2 {
                axis = axis.scale(-1.0);
            }
            door.travel = Vec3();
            door.rotation = axis.scale(distance);
            coords = fields.get("origin", "0 0 0").split();
            if len(coords) != 3 {
                raise ValueError("Invalid rotating door origin");
            }
            door.pivot = Vec3(x=float(coords[0]), y=float(coords[1]), z=float(coords[2]));
            if flags & 1 {
                door.rest_angles = door.rotation;
                door.rotation = door.rotation.scale(-1.0);
            }
        } elif (kind == "func_door" or water) and flags & 1 {
            door.rest = door.travel;
            door.travel = door.travel.scale(-1.0);
        }
        if water {
            door.monster_touch = False;
            door.flooding = True;
        }
        if kind == "func_plat" {
            inset = 33.0 if bsp.game == "q3" else 25.0;
            lo = bounds.mins.add(Vec3(x=inset, y=inset));
            hi = bounds.maxs.sub(Vec3(x=inset, y=inset));
            if lo.x >= hi.x {
                lo.x = bounds.center().x;
                hi.x = lo.x + 1.0;
            }
            if lo.y >= hi.y {
                lo.y = bounds.center().y;
                hi.y = lo.y + 1.0;
            }
            lo.z = bounds.maxs.z - distance;
            hi.z = bounds.maxs.z + 8.0;
            if bsp.game == "q3" {
                lo.z = bounds.mins.z - distance;
                hi.z -= distance;
            }
            if flags & 1 {
                hi.z = lo.z + 8.0;
            }
            width = 15.0 if bsp.game == "q3" else 16.0;
            door.trigger = AABB(
                mins=lo.sub(Vec3(x=width, y=width, z=32.0)),
                maxs=hi.add(Vec3(x=width, y=width, z=24.0))
            );
            if not door.automatic and bsp.game != "q3" {
                door.position = 1.0;
                door.state = "locked";
            }
        }
        record = bsp.models[model];
        door.faces = list(
            range(record.first_face, record.first_face + record.face_count)
        );
        for i in range(len(collision.models)) {
            if collision.models[i] != model {
                continue;
            }
            door.hulls.append(i);
            door.origins.append(collision.offsets[i]);
        }
        # Liquid movers have no solid hulls; their volumes move instead.
        # A member without clip hulls (drawn-only brushes) still moves in view.
        if door.enabled and not door.hulls and not door.faces and not door.flooding {
            reason = "no collision hull";
            door.enabled = False;
        }
        door.entity = index;
        door.reason = reason;
        candidates.append(door);
    }
    for i in range(len(candidates)) {
        first = candidates[i];
        for j in range(i + 1, len(candidates)) {
            second = candidates[j];
            linked = first.kind == "door"
                and second.kind == "door"
                and (
                    first.linkable
                    and second.linkable
                    and overlaps(first.bounds, second.bounds)
                )
                if bsp.game == "q1"
                else (
                    first.kind == "door"
                    and second.kind == "door"
                    and bool(first.team)
                    and first.team == second.team
                );
            if linked {
                first +>:DoorLink:+> second;
                second +>:DoorLink:+> first;
            }
        }
    }
    grouped: list[int] = [];
    for leader in candidates {
        if leader.model in grouped {
            continue;
        }
        assembly = leader spawn AssembleDoors();
        grouped.extend(assembly.ids);
        enabled = True;
        duration = 0.0;
        bounds = leader.trigger;
        why = "";
        for part in assembly.members {
            if not part.enabled {
                enabled = False;
                why = why or part.reason;
            }
            if part.speed > 0.0 {
                duration = max(duration, door_span(part) / part.speed);
            }
            bounds = union_bounds(bounds, part.trigger);
            # A team containing another mover class cannot be animated partially.
            if part.team and bsp.game != "q1" {
                for ent in bsp.entities {
                    if ent.fields.get("team", "") == part.team
                        and ent.fields.get("classname", "")
                            not in ["func_door", "func_door_rotating"] {
                        enabled = False;
                        why = why or "team with " + ent.fields.get("classname", "");
                    }
                }
            }
        }
        if not enabled or duration <= 0.0 {
            for part in assembly.members {
                note_chain(
                    world,
                    part.entity,
                    "static mover: " + (part.reason or why or "no travel time")
                );
            }
            continue;
        }
        for part in assembly.members {
            for key in part.keys {
                if key not in leader.keys {
                    leader.keys.append(key);
                }
            }
            # LinkDoors: the master takes a member's message and key wording.
            if part.touch_message and not leader.touch_message {
                leader.touch_message = part.touch_message;
                leader.talk = part.talk;
            }
            if part.key_message and not leader.key_message {
                leader.key_message = part.key_message;
                leader.key_try = part.key_try;
                leader.key_use = part.key_use;
            }
            if leader.shared_health and part.max_health > 0 {
                leader.health = part.health;
                leader.max_health = part.max_health;
            }
            leader.automatic = leader.automatic and part.automatic;
            leader.monster_touch = leader.monster_touch and part.monster_touch;
            for name in part.names {
                if name not in leader.names {
                    leader.names.append(name);
                }
            }
        }
        leader.trigger = bounds;
        leader.speed = door_span(leader) / duration;
        for part in assembly.members {
            for index in part.hulls {
                if part.rotation.length() > 0.0 {
                    collision.allow_rotation(index);
                } elif len(collision.bounds) == len(collision.hulls) {
                    b = collision.bounds[index];
                    delta = part.travel;
                    collision.bounds[index] = AABB(
                        mins=b.mins.add(
                            Vec3(
                                x=min(part.rest.x, part.rest.x + delta.x),
                                y=min(part.rest.y, part.rest.y + delta.y),
                                z=min(part.rest.z, part.rest.z + delta.z)
                            )
                        ),
                        maxs=b.maxs.add(
                            Vec3(
                                x=max(part.rest.x, part.rest.x + delta.x),
                                y=max(part.rest.y, part.rest.y + delta.y),
                                z=max(part.rest.z, part.rest.z + delta.z)
                            )
                        )
                    );
                }
            }
            if part.model != leader.model {
                leader +>:DoorMember:+> part;
            }
        }
        if len(leader.voices) == 3 {
            centre = leader.bounds.center().add(leader.rest).add(leader.travel.scale(leader.position));
            leader.start_voice = mover_voice(world, bsp.game, leader.voices[0], False, centre);
            leader.move_voice = mover_voice(world, bsp.game, leader.voices[1], True, centre);
            leader.stop_voice = mover_voice(world, bsp.game, leader.voices[2], False, centre);
        }
        leader.voiced_state = leader.state;
        world +>:HasDoor:+> leader;
    }
    collision.reindex();
    if connect {
        connect_targets(world, bsp);
        pose_doors(world, bsp, collision);
    }
}

def pose_doors(world: World, bsp: Bsp, collision: CollisionMap) {
    for mover in [world->:HasDoor:->][?:Door] {
        if mover.enabled {
            members = [mover];
            members.extend([mover->:DoorMember:->][?:Door]);
            for part in members {
                apply_pose(part, mover.position, bsp, collision);
            }
        }
    }
}


def union_bounds(a: AABB, b: AABB) -> AABB {
    return AABB(
        mins=Vec3(
            x=min(a.mins.x, b.mins.x),
            y=min(a.mins.y, b.mins.y),
            z=min(a.mins.z, b.mins.z)
        ),
        maxs=Vec3(
            x=max(a.maxs.x, b.maxs.x),
            y=max(a.maxs.y, b.maxs.y),
            z=max(a.maxs.z, b.maxs.z)
        )
    );
}


def connect_targets(world: World, bsp: Bsp) {
    signals: list[Signal] = [world->:HasSignal:->][?:Signal];
    leaders = [world->:HasDoor:->][?:Door];
    for leader in leaders {
        members = [leader];
        members.extend([leader->:DoorMember:->][?:Door]);
        for part in members {
            part.activation = leader.activation;
            for index in range(len(bsp.entities)) {
                fields = bsp.entities[index].fields;
                if fields.get("model", "") == "*" + str(part.model) {
                    leader.activation.entities.append(index);
                }
            }
        }
        signals.append(leader.activation);
    }
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        kind = fields.get("classname", "");
        if (kind == "trigger_secret" and bsp.game == "q1")
            or (kind in ["target_secret", "target_goal"] and bsp.game == "q2") {
            progress = progress_for(world);
            secret = kind != "target_goal";
            if secret {
                progress.total_secrets += 1;
            } else {
                progress.total_goals += 1;
            }
            signals.append(
                Signal(
                    entities=[index],
                    relay=True,
                    once=True,
                    progress=progress,
                    objective="secret" if secret else "goal",
                    message=fields.get(
                        "message", "You found a secret area!" if bsp.game == "q1" else ""
                    ),
                    cue=authored_cue(bsp.game, kind, fields)
                )
            );
        }
        # Touch triggers are relays of their own, so use by name, touch and
        # shooting all fire the same targets (Q1 multi_trigger, Q2 Touch_Multi).
        if kind in ["trigger_once", "trigger_multiple", "trigger_onlyregistered"] {
            flags = int(fields.get("spawnflags", "0"));
            signals.append(
                Signal(
                    entities=[index],
                    relay=True,
                    once=kind == "trigger_once" or float(fields.get("wait", "0")) < 0.0,
                    message=fields.get("message", ""),
                    cue=authored_cue(bsp.game, kind, fields),
                    armable=bsp.game == "q2" and flags & 4 != 0,
                    armed=not (bsp.game == "q2" and flags & 4 != 0)
                )
            );
        }
        if kind == "func_timer" and bsp.game in ["q2", "q3"] {
            interval = float(fields.get("wait", "1"));
            if interval <= 0.0 {
                interval = 1.0;
            }
            timer = Signal(
                entities=[index],
                interval=interval,
                random_state=index + 1,
                variance=max(
                    0.0,
                    min(
                        float(fields.get("random", "1" if bsp.game == "q3" else "0")),
                        interval - 0.1
                    )
                ),
                timer_running=int(fields.get("spawnflags", "0")) & 1 != 0
            );
            if timer.timer_running {
                timer.timer_remaining = 0.1
                    if bsp.game == "q3"
                    else max(
                        0.0,
                        1.0
                            + float(fields.get("pausetime", "0"))
                            + float(fields.get("delay", "0"))
                            + timer.sample(interval)
                    );
            }
            signals.append(timer);
        }
        if kind == "target_crosslevel_trigger" and bsp.game == "q2" {
            signals.append(
                Signal(
                    entities=[index],
                    relay=True,
                    grant_flags=int(fields.get("spawnflags", "0")) & 255
                )
            );
        }
        if kind == "target_crosslevel_target" and bsp.game == "q2" {
            signals.append(
                Signal(
                    entities=[index],
                    require_flags=int(fields.get("spawnflags", "0")) & 255,
                    queued=[DelayedUse(remaining=float(fields.get("delay", "0")) or 1.0)]
                )
            );
        }
        if kind == "trigger_always" and bsp.game in ["q2", "q3"] {
            startup = 0.3
                if bsp.game == "q3"
                else max(0.2, float(fields.get("delay", "0")));
            signals.append(
                Signal(entities=[index], queued=[DelayedUse(remaining=startup)])
            );
        }
        if kind in ["trigger_key", "trigger_counter"] and bsp.game in ["q1", "q2"] {
            key = fields.get("item", "") if kind == "trigger_key" else "";
            if kind == "trigger_counter"
                or (bsp.game == "q2" and key.startswith("key_")) {
                signals.append(
                    Signal(
                        relay=True,
                        entities=[index],
                        key=key,
                        once=True,
                        remaining=max(1, int(fields.get("count", "2")))
                            if kind == "trigger_counter"
                            else 0,
                        # NOMESSAGE (1) silences the counter's progress.
                        counter_style="silent"
                            if int(fields.get("spawnflags", "0")) & 1
                            else bsp.game,
                        message=fields.get("message", "")
                    )
                );
            }
        }
        if kind in ["trigger_relay", "target_relay", "target_delay"]
            and int(fields.get("spawnflags", "0")) == 0 {
            signal = Signal(
                relay=True,
                entities=[index],
                message=fields.get("message", ""),
                cue=authored_cue(bsp.game, kind, fields)
            );
            if kind == "target_delay" and bsp.game == "q3" {
                signal.delay = float(fields.get("delay", fields.get("wait", "1")));
                if signal.delay <= 0.0 {
                    signal.delay = 1.0;
                }
                signal.variance = max(0.0, float(fields.get("random", "0")));
                signal.replace_pending = True;
                signal.random_state = index + 1;
            }
            signals.append(signal);
        }
    }
    # Recipients with no use behaviour here (visibility portals, markers, path
    # and combat points, teleport destinations) accept uses as no-ops, as the
    # originals ignore those uses.
    covered: set[int] = set();
    for signal in signals {
        for index in signal.entities {
            covered.add(index);
        }
    }
    passive = [
        "func_areaportal",
        "info_null",
        "info_notnull",
        "target_position",
        "point_combat",
        "path_corner",
        "info_teleport_destination",
        "misc_teleporter_dest",
        "misc_portal_camera",
        "target_string",
        "target_character",
        # No use function in the originals: worldspawn, exploding barrels and
        # monster jump triggers are named but never react to a use.
        "worldspawn",
        "misc_explobox",
        "trigger_monsterjump"
    ];
    for index in range(len(bsp.entities)) {
        if index not in covered
            and bsp.entities[index].fields.get("classname", "") in passive {
            signals.append(Signal(entities=[index]));
        }
    }
    registered = [world->:HasSignal:->][?:Signal];
    for signal in signals {
        if signal not in registered {
            world +>:HasSignal:+> signal;
        }
    }
    # Resolve every recipient; recipients without a use are only noted.
    unused: list[int] = [];
    for signal in signals {
        for index in signal.entities {
            fields = bsp.entities[index].fields;
            kind = fields.get("classname", "");
            if bsp.game in ["q1", "q2"] {
                signal.delay = max(signal.delay, float(fields.get("delay", "0")));
            }
            # Trains follow their target; Q2 changelevels never use theirs.
            if kind == "func_train" or kind == "target_changelevel" {
                continue;
            }
            # Path points and Q2 clocks fire their pathtarget; other users hand
            # theirs to the elevators they call.
            passes = kind in ["path_corner", "point_combat", "func_clock"] and bsp.game != "q3";
            target = fields.get("pathtarget", "") if passes else fields.get("target", "");
            if not passes and bsp.game == "q2" and fields.get("pathtarget", "") {
                signal.pathtarget = fields["pathtarget"];
            }
            if kind.startswith("monster_") and bsp.game == "q2" {
                target = fields.get("deathtarget", target);
            }
            if not target {
                continue;
            }
            for recipient in range(len(bsp.entities)) {
                if bsp.entities[recipient].fields.get("targetname", "") != target {
                    continue;
                }
                if kind == "path_corner"
                    and bsp.game == "q3"
                    and bsp.entities[recipient].fields.get("classname", "")
                        == "path_corner" {
                    continue;
                }
                resolved = False;
                for destination in signals {
                    if recipient in destination.entities {
                        signal +>:Targets:+> destination;
                        resolved = True;
                        break;
                    }
                }
                # Q1 SUB_UseTargets and Q2 G_UseTargets skip targets without a
                # use; the rest of the chain still fires.
                if not resolved and recipient not in unused {
                    unused.append(recipient);
                    note_chain(
                        world,
                        recipient,
                        "no use for "
                            + bsp.entities[recipient].fields.get("classname", "")
                    );
                }
            }
        }
    }
    # killtarget recipients without a graph identity cannot be removed; the rest
    # of the chain still runs rather than being disabled.
    for signal in signals {
        for index in signal.entities {
            victim = bsp.entities[index].fields.get("killtarget", "");
            if not victim {
                continue;
            }
            for recipient in range(len(bsp.entities)) {
                if bsp.entities[recipient].fields.get("targetname", "") != victim {
                    continue;
                }
                for destination in signals {
                    if recipient in destination.entities and destination is not signal {
                        signal +>:Kills:+> destination;
                        break;
                    }
                }
            }
        }
    }
    for signal in signals {
        if not signal.enabled {
            signal.queued = [];
            signal.timer_running = False;
        }
    }
    for leader in leaders {
        leader.enabled = leader.enabled and leader.activation.enabled;
    }
}


"""Activation sounds: Q1/Q2 trigger `sounds` (secret, beep, switch), message
beeps (Q1 SUB_UseTargets misc/talk, Q2 G_UseTargets misc/talk1 unless
`noise`), Q1 secrets' default."""
def authored_cue(game: str, kind: str, fields: dict[str, str]) -> str {
    style = int(fields.get("sounds", "0"));
    if (game == "q1" and kind == "trigger_secret" or game == "q2" and kind in ["target_secret", "target_goal"]) and style == 0 and not fields.get("noise", "") {
        style = 1;
    }
    if style == 1 {
        return "sound/misc/secret.wav";
    }
    if style == 2 {
        return "sound/misc/talk.wav";
    }
    if style == 3 {
        return "sound/misc/trigger1.wav";
    }
    # Q1 SUB_UseTargets: a message without a noise sounds misc/talk.
    if game == "q1" and fields.get("message", "") and style == 0 {
        return "sound/misc/talk.wav";
    }
    if game == "q2" and fields.get("message", "") {
        noise = fields.get("noise", "");
        if noise {
            return ("sound/" + noise if not noise.startswith("sound/") else noise)
                + ("" if noise.endswith(".wav") else ".wav");
        }
        return "sound/misc/talk1.wav";
    }
    return "";
}

def resolve_targets(world: World, bsp: Bsp, target: str) -> list[Signal] {
    result: list[Signal] = [];
    signals = [world->:HasSignal:->][?:Signal];
    for index in range(len(bsp.entities)) {
        if bsp.entities[index].fields.get("targetname", "") != target {
            continue;
        }
        # Recipients without a use are skipped, as G_UseTargets does.
        for signal in signals {
            if signal.enabled and index in signal.entities {
                result.append(signal);
                break;
            }
        }
    }
    return result;
}


def damage_button(button: Door, amount: int) -> bool {
    if amount <= 0
        or not button.enabled
        or button.kind != "button"
        or button.max_health <= 0
        or button.activation.pending > 0
        or button.state not in ["closed", "closing"] {
        return False;
    }
    button.health = max(0, button.health - amount);
    if button.health == 0 {
        button.health = button.max_health;
        button.activation.pending += 1;
        return True;
    }
    return False;
}

def damage_mover(leader: Door, part: Door, amount: int) -> bool {
    if leader.kind == "button" {
        return damage_button(leader, amount);
    }
    if amount <= 0
        or not leader.enabled
        or leader.kind != "door"
        or leader.activation.pending > 0
        or leader.state not in ["closed", "closing"] {
        return False;
    }
    target = leader if leader.shared_health else part;
    if target.max_health <= 0 {
        return False;
    }
    target.health = max(0, target.health - amount);
    if target.health > 0 {
        return False;
    }
    leader.health = leader.max_health;
    for member in [leader->:DoorMember:->][?:Door] {
        member.health = member.max_health;
    }
    leader.activation.pending += 1;
    return True;
}

walker BlastMover {
    has origin: Vec3,
        amount: int,
        radius: float,
        game: str,
        collision: CollisionMap,
        player: Player,
        energy_burst: bool = False;

    can begin with World entry {
        visit [here->:HasDoor:->];
    }

    can hit with Door entry {
        if not here.enabled {
            return;
        }
        members = [here];
        members.extend([here->:DoorMember:->][?:Door]);
        for part in members {
            if part.max_health <= 0
                and not (here.shared_health and here.max_health > 0) {
                continue;
            }
            center = part.bounds.center().add(part.rest).add(
                part.travel.scale(here.position)
            );
            strength = blast_strength(
                self.game,
                self.amount,
                self.radius,
                center.sub(self.origin).length(),
                self.energy_burst
            );
            if strength <= 0.0 {
                continue;
            }
            sight = self.collision.trace(
                self.origin, center, exclude=part.hulls, point=True
            );
            if sight.start_solid or sight.fraction < 1.0 {
                continue;
            }
            if self.energy_burst {
                sight = self.collision.trace(
                    self.player.pos, center, exclude=part.hulls, point=True
                );
                if sight.start_solid or sight.fraction < 1.0 {
                    continue;
                }
            }
            damage_mover(here, part, int(strength));
        }
    }
}
