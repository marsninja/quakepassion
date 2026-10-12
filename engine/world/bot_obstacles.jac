"""What a Q3 bot does about a door in its way, after ai_dmq3.c
BotGetActivateGoal. A shut door that something else opens is no obstacle a
bot can walk through, so the bot finds what opens it and goes there first:
a button to walk into (BotFuncButtonActivateGoal), a trigger to stand in
(BotTriggerMultipleActivateGoal), or a button or door to shoot
(BotFuncDoorActivateGoal).

What opens a door is read off the level's own activation graph: the door's
`Signal` and the `Targets` edges into it from the buttons, triggers, relays
and delays that fire it. A `FindActivator` walker starts at the door and
walks those edges backwards, through relays and delays up to ten deep, as
BotGetActivateGoal's "tree-like activation" follows target and targetname
keys through the BSP entities."""
import from engine.formats.numbers { atof, atoi }
import math;
import from .world { World }
import from .doors { Door, HasDoor, DoorMember }
import from .signals { Signal, Targets }
import from .bot_routes { NavMesh, area_travel_time }
import from .bot_goals { BotGoal }
import from .bot_character { ActivateGoal, MAX_ACTIVATEAREAS }
import from ..formats.bsp { Bsp }
import from ..formats.aas { AREACONTENTS_MOVER }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3, forward_from }
import from ..math.aabb { AABB }

# be_aas_sample.c AAS_PresenceTypeBoundingBox for PRESENCE_CROUCH.
glob CROUCH_MINS: Vec3 = Vec3(x=-15.0, y=-15.0, z=-24.0),
    CROUCH_MAXS: Vec3 = Vec3(x=15.0, y=15.0, z=8.0);

"""How far the mover with BSP `model` stands from where the map has it
(its entity's currentOrigin)."""
def mover_offset(collision: CollisionMap, model: int) -> Vec3 {
    for i in range(len(collision.models)) {
        if collision.models[i] == model {
            return collision.offsets[i];
        }
    }
    return Vec3();
}

"""ai_dmq3.c BotModelMinsMaxs: the world box of the entity with BSP `model`
where it stands now, or None when the map has no such model."""
def model_box(bsp: Bsp, collision: CollisionMap, model: int) -> AABB | None {
    if model <= 0 or model >= len(bsp.models) {
        return None;
    }
    record = bsp.models[model];
    offset = mover_offset(collision, model);
    return AABB(mins=record.mins.add(offset), maxs=record.maxs.add(offset));
}

"""ai_dmq3.c BotSetMovedir from an entity's `angle` key: -1 is up, -2 down,
anything else a yaw."""
def activator_movedir(angle: float) -> Vec3 {
    if angle == -1.0 {
        return Vec3(z=1.0);
    }
    if angle == -2.0 {
        return Vec3(z=-1.0);
    }
    return forward_from(math.radians(angle), 0.0);
}

"""The BSP model an entity's `model` key names ("*N"), or 0."""
def brush_model(fields: dict[str, str]) -> int {
    name = fields.get("model", "");
    return int(name[1:]) if name.startswith("*") and name[1:].isdigit() else 0;
}

"""The first (or with `last`, the last) area with reachabilities on the line
from `start` down `depth` units (AAS_TraceAreas and AAS_AreaReachability),
with the point where the line enters it; area 0 when there is none."""
def reachable_area_below(mesh: NavMesh, start: Vec3, depth: float, last: bool = False) -> tuple[int, Vec3] {
    crossed = mesh.aas.trace_areas(start, start.sub(Vec3(z=depth)), 10);
    if last {
        crossed.reverse();
    }
    for found in crossed {
        if mesh.aas.areas[found[0]].reach_count > 0 {
            return found;
        }
    }
    return (0, Vec3());
}

"""How far in front of a button's middle a bot stands to touch it: half the
button's size along its move direction plus the crouching bot's own box."""
def touch_distance(box: AABB, movedir: Vec3, with_body: bool) -> float {
    size = box.maxs.sub(box.mins);
    dist = (abs(movedir.x) * size.x + abs(movedir.y) * size.y + abs(movedir.z) * size.z) * 0.5;
    if with_body {
        dist += abs(movedir.x) * (CROUCH_MAXS.x if movedir.x < 0.0 else -CROUCH_MINS.x);
        dist += abs(movedir.y) * (CROUCH_MAXS.y if movedir.y < 0.0 else -CROUCH_MINS.y);
        dist += abs(movedir.z) * (CROUCH_MAXS.z if movedir.z < 0.0 else -CROUCH_MINS.z);
    }
    return dist;
}

"""A goal box widened a unit on the side the button is pressed from
(BotFuncButtonActivateGoal's extramins and extramaxs)."""
def pressed_box(goal: BotGoal, movedir: Vec3) {
    goal.maxs = goal.maxs.add(Vec3(
        x=abs(movedir.x) if movedir.x < 0.0 else 0.0,
        y=abs(movedir.y) if movedir.y < 0.0 else 0.0,
        z=abs(movedir.z) if movedir.z < 0.0 else 0.0
    ));
    goal.mins = goal.mins.add(Vec3(
        x=abs(movedir.x) if movedir.x >= 0.0 else 0.0,
        y=abs(movedir.y) if movedir.y >= 0.0 else 0.0,
        z=abs(movedir.z) if movedir.z >= 0.0 else 0.0
    ));
}

"""ai_dmq3.c BotFuncButtonActivateGoal for the button entity `fields` with
BSP `model`. A button with health is shot: from where the bot stands when it
sees the button's face from its `eye`, otherwise from the nearest spot under
the button's front. Any other button is walked into: the goal is the button
itself, in the area under its front. Returns False when no area serves."""
def button_goal(
    fields: dict[str, str],
    model: int,
    bsp: Bsp,
    collision: CollisionMap,
    mesh: NavMesh,
    origin: Vec3,
    eye: Vec3,
    area: int,
    found: ActivateGoal
) -> bool {
    box = model_box(bsp, collision, model);
    if box is None {
        return False;
    }
    found.shoot = False;
    found.target = Vec3();
    found.entity = model;
    movedir = activator_movedir(atof(fields.get("angle", "0")));
    middle = box.mins.add(box.maxs).scale(0.5);
    if atof(fields.get("health", "0")) != 0.0 {
        face = middle.sub(movedir.scale(touch_distance(box, movedir, False)));
        found.target = face;
        found.shoot = True;
        sight = collision.trace_point(eye, face);
        if sight.fraction >= 1.0 or sight.model == model {
            found.goal = BotGoal(origin=origin, area=area);
            return True;
        }
        front = middle.sub(movedir.scale(touch_distance(box, movedir, True)));
        spot = reachable_area_below(mesh, front.add(Vec3(z=24.0)), 512.0, True);
        if spot[0] == 0 {
            return False;
        }
        # The original builds this box inside out (mins 8, maxs -8); the
        # bot's own box still overlaps it (BotTouchingGoal).
        found.goal = BotGoal(
            origin=spot[1], area=spot[0], mins=Vec3(x=8.0, y=8.0, z=8.0), maxs=Vec3(x=-8.0, y=-8.0, z=-8.0)
        );
        pressed_box(found.goal, movedir);
        return True;
    }
    front = middle.sub(movedir.scale(touch_distance(box, movedir, True)));
    spot = reachable_area_below(mesh, front.add(Vec3(z=24.0)), 100.0);
    if spot[0] == 0 {
        return False;
    }
    found.goal = BotGoal(origin=middle, area=spot[0], mins=box.mins.sub(middle), maxs=box.maxs.sub(middle));
    pressed_box(found.goal, movedir);
    return True;
}

"""ai_dmq3.c BotFuncDoorActivateGoal: a door with health is shot at its
middle from where the bot stands."""
def door_goal(model: int, bsp: Bsp, collision: CollisionMap, origin: Vec3, area: int, found: ActivateGoal) -> bool {
    box = model_box(bsp, collision, model);
    if box is None {
        return False;
    }
    found.target = box.mins.add(box.maxs).scale(0.5);
    found.shoot = True;
    found.entity = model;
    found.goal = BotGoal(origin=origin, area=area);
    return True;
}

"""ai_dmq3.c BotTriggerMultipleActivateGoal: the goal is the trigger's box,
in the first area with reachabilities under its middle."""
def trigger_goal(model: int, bsp: Bsp, collision: CollisionMap, mesh: NavMesh, found: ActivateGoal) -> bool {
    box = model_box(bsp, collision, model);
    if box is None {
        return False;
    }
    found.shoot = False;
    found.target = Vec3();
    middle = box.mins.add(box.maxs).scale(0.5);
    spot = reachable_area_below(mesh, middle.add(Vec3(z=24.0)), 100.0);
    if spot[0] == 0 {
        return False;
    }
    found.entity = model;
    found.goal = BotGoal(origin=middle, area=spot[0], mins=box.mins.sub(middle), maxs=box.maxs.sub(middle));
    return True;
}

"""ai_dmq3.c BotGetActivateGoal for a bot stopped (or about to be) by the
mover with BSP `model`: what the bot has to activate to get it out of the
way. `found` is the activate goal when `entity`, the BSP entity to
activate, is not 0.

- A door with health is shot (BotFuncDoorActivateGoal).
- A door that starts open, or is open or opening already, needs nothing.
- A button in the way needs nothing either.
- Otherwise the mover's activators are tried in the map's entity order: a
  func_button or trigger_multiple that fires it, or one behind a
  target_relay or target_delay, followed depth first up to ten deep.
  func_timers are passed over. An activator the bot has been at for over
  two seconds already is passed over too.
- A shut door's areas are stored with the goal and closed to routing
  before an activator's travel time is asked for, so one that can only be
  reached through the door does not count. They stay closed: the caller
  opens them again when the bot does not go (`found.enable_areas`).

`origin`, `eye`, `area` and `flags` are the bot's; `top` is the activate
goal it is at now."""
walker FindActivator {
    has model: int,
        bsp: Bsp,
        collision: CollisionMap,
        mesh: NavMesh,
        origin: Vec3,
        eye: Vec3,
        area: int,
        flags: int,
        now: float,
        top: ActivateGoal | None = None,
        found: ActivateGoal = ActivateGoal(goal=BotGoal(origin=Vec3(), area=0)),
        entity: int = 0,
        resolved: bool = False,
        trail: list[tuple[Signal, int]] = [],
        resume: int = 0;

    can begin with World entry {
        visit [here->:HasDoor:->];
    }

    """The BSP entity with brush `model` ("no entity found with model")."""
    def entity_of(model: int) -> int {
        for index in range(len(self.bsp.entities)) {
            if brush_model(self.bsp.entities[index].fields) == model {
                return index;
            }
        }
        return 0;
    }

    """The mover itself: what it is decides whether anything is needed."""
    can obstacle with Door entry {
        if self.resolved {
            return;
        }
        parts = [here];
        parts.extend([here->:DoorMember:->][?:Door]);
        if self.model not in [part.model for part in parts] {
            return;
        }
        self.resolved = True;
        index = self.entity_of(self.model);
        if index == 0 {
            return;
        }
        fields = self.bsp.entities[index].fields;
        classname = fields.get("classname", "");
        if classname == "func_door" {
            if atof(fields.get("health", "0")) != 0.0 {
                if door_goal(self.model, self.bsp, self.collision, self.origin, self.area, self.found) {
                    self.entity = index;
                }
                return;
            }
            # "if the door starts open then just wait for the door to return"
            # and "if the door is open or opening already".
            if atoi(fields.get("spawnflags", "0")) & 1 or here.position != 0.0 or here.state != "closed" {
                return;
            }
            self.store_areas();
        }
        if classname == "func_button" or not fields.get("targetname", "") {
            return;
        }
        visit [here.activation];
    }

    """"store all the areas the door is in": the mover areas its box
    touches, those with reachabilities first."""
    def store_areas() {
        box = model_box(self.bsp, self.collision, self.model);
        if box is None {
            return;
        }
        touched = [
            area
            for area in self.mesh.aas.box_areas(box.mins, box.maxs, MAX_ACTIVATEAREAS * 2)
            if self.mesh.aas.areas[area].contents & AREACONTENTS_MOVER
        ];
        routed = [area for area in touched if self.mesh.aas.areas[area].reach_count > 0];
        others = [area for area in touched if self.mesh.aas.areas[area].reach_count == 0];
        self.found.areas = (routed + others)[0:MAX_ACTIVATEAREAS];
    }

    """What fires `signal`, in the map's entity order."""
    def sources(signal: Signal) -> list[Signal] {
        ordered: list[Signal] = [];
        for source in [signal<-:Targets:<-][?:Signal] {
            if not source.entities {
                continue;
            }
            index = 0;
            while index < len(ordered) and ordered[index].entities[0] <= source.entities[0] {
                index += 1;
            }
            ordered.insert(index, source);
        }
        return ordered;
    }

    """"if the bot tries to activate this button already": the goal on top
    of its stack is this one, still running, begun over two seconds ago."""
    def at_it_already() -> bool {
        top = self.top;
        return top is not None
            and top.entity == self.found.entity
            and top.time > self.now
            and top.start_time < self.now - 2.0;
    }

    """From a reachability area the activator has to be reachable with the
    door's areas closed; the bot gets that travel time and 5 seconds."""
    def within_reach() -> bool {
        if self.area == 0 or self.mesh.aas.areas[self.area].reach_count == 0 {
            return True;
        }
        self.found.enable_areas(self.mesh, False);
        self.mesh.times_to(self.found.goal.area, self.flags);
        t = area_travel_time(self.mesh, self.area, self.origin, self.found.goal.area, self.flags);
        if t == 0 {
            return False;
        }
        self.found.time = self.now + float(t) * 0.01 + 5.0;
        return True;
    }

    """A signal that fires the mover, with those that fire it in turn. The
    walker goes down into a relay or delay and comes back up when nothing
    there serves, picking up where it left (`trail`, `resume`)."""
    can activators with Signal entry {
        sources = self.sources(here);
        index = self.resume;
        self.resume = 0;
        while index < len(sources) {
            source = sources[index];
            index += 1;
            fields = self.bsp.entities[source.entities[0]].fields;
            classname = fields.get("classname", "");
            model = brush_model(fields);
            if classname in ["func_button", "trigger_multiple"] {
                built = button_goal(
                    fields, model, self.bsp, self.collision, self.mesh, self.origin, self.eye, self.area, self.found
                )
                    if classname == "func_button"
                    else trigger_goal(model, self.bsp, self.collision, self.mesh, self.found);
                if built and not self.at_it_already() and self.within_reach() {
                    self.entity = source.entities[0];
                    disengage;
                }
            } elif classname in ["target_relay", "target_delay"]
                and fields.get("targetname", "")
                and len(self.trail) < 9 {
                self.trail.append((here, index));
                visit [source];
                return;
            }
        }
        if self.trail {
            back = self.trail.pop();
            self.resume = back[1];
            visit [back[0]];
        }
    }
}

"""ai_dmnet.c BotSelectActivateWeapon: the weapon number a bot shoots a
button or door with, the first it holds with ammo (`armed`) of the machine
gun, shotgun, plasma gun, lightning gun, railgun, rocket launcher and BFG;
-1 when it has none of them."""
def activate_weapon(armed: list[int]) -> int {
    for slot in [2, 3, 8, 6, 7, 5, 9] {
        if slot in armed {
            return slot;
        }
    }
    return -1;
}
