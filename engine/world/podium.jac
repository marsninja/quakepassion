"""Q3 single-player podium (g_arenas.c). When an arena match ends, the view
moves to the intermission point (FindIntermissionPoint), the podium model rises
80 units ahead of it and 70 below, and copies of the top three finishers stand
on its pads facing the camera (SpawnModelsOnVictoryPads). Two seconds later the
winner plays its gesture and taunt (CelebrateStart), and stands again when the
gesture timer runs out (CelebrateStop)."""
import math;
import from .world { World, Entity, move_to_area }
import from .models { Visual, ModelResource, UsesModel, HasVisual }
import from .arena { ArenaMatch, ChooseSpawn, standings }
import from .combat { Opponent }
import from .level { Level }
import from ..formats.bsp { Bsp }
import from ..math.vec3 { Vec3 }

# g_arenas.c pad offsets along the podium's forward, right and up.
glob PODIUM_OFFSETS: list[Vec3] = [
    Vec3(z=74.0),
    Vec3(x=-10.0, y=60.0, z=54.0),
    Vec3(x=-19.0, y=-60.0, z=45.0)
];

# TIMER_GESTURE: 34 frames at 66 ms, plus 50.
glob GESTURE_TIME: float = 2.294;

node Podium(Entity) {
    has visual: Visual = Visual(),
        shown: bool = False,
        clock: float = 0.0,
        celebrating: bool = False,
        celebrated: bool = False,
        taunts: int = 0;
}

"""A finisher's stand-in on the podium: its body, weapon and taunt."""
node Figure(Entity) {
    has body: Visual = Visual(),
        weapon: Visual = Visual(),
        stand_frame: int = 0,
        gesture_frames: list[int] = [],
        gesture_rate: float = 15.0,
        taunt: str = "";
}

edge HasPodium: World --> Podium {}
edge Stands: Podium --> Figure {
    has place: int = 1;
}
"""Every competitor's stand-in, by its name in the match."""
edge Poses: Podium --> Figure {
    has name: str = "",
        human: bool = False;
}
"""A bot's stand-in copies the weapon the bot holds when the match ends."""
edge Portrays: Figure --> Opponent {}
"""The human's stand-in can hold any weapon."""
edge Wields: Figure --> ModelResource {
    has key: str = "";
}

"""A figure for one finisher, drawn with the given body and weapon models."""
def podium_figure(body: ModelResource, weapon: ModelResource | None, taunt: str, gesture_rate: float) -> Figure {
    figure = Figure(taunt=taunt, gesture_rate=gesture_rate);
    figure +>:HasVisual:+> figure.body;
    figure.body +>:UsesModel:+> body;
    figure +>:HasVisual:+> figure.weapon;
    if weapon is not None {
        figure.weapon +>:UsesModel:+> weapon;
    }
    frames = body.model.surfaces[0].frames if body.model.surfaces else [];
    for i in range(len(frames)) {
        if frames[i].name == "stand0" {
            figure.stand_frame = i;
        }
        if frames[i].name.startswith("gesture") {
            figure.gesture_frames.append(i);
        }
    }
    figure.body.visible = False;
    figure.weapon.visible = False;
    return figure;
}

"""FindIntermissionPoint: the info_player_intermission, aimed at its target
when it has one; otherwise the spawn spot furthest from the world origin.
Returns [origin, Vec3(pitch, yaw)] in Quake degrees."""
def arena_intermission(world: World, bsp: Bsp) -> list[Vec3] {
    points: dict[str, Vec3] = {};
    for entity in bsp.entities {
        name = entity.fields.get("targetname", "");
        if name {
            points[name] = podium_point(entity.fields.get("origin", "0 0 0"));
        }
    }
    for entity in bsp.entities {
        fields = entity.fields;
        if fields.get("classname", "") != "info_player_intermission" {
            continue;
        }
        origin = podium_point(fields.get("origin", "0 0 0"));
        angles = Vec3(y=float(fields.get("angle", "0")));
        parts = fields.get("angles", "").split();
        if len(parts) == 3 {
            angles = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
        }
        target = fields.get("target", "");
        if target in points {
            aim = points[target].sub(origin);
            flat = math.sqrt(aim.x * aim.x + aim.y * aim.y);
            angles = Vec3(x=-math.degrees(math.atan2(aim.z, flat)), y=math.degrees(math.atan2(aim.y, aim.x)));
        }
        return [origin, angles];
    }
    choice = world spawn ChooseSpawn(avoid=[Vec3()], seed=1);
    spot = choice.pick();
    if spot is None {
        return [Vec3(), Vec3()];
    }
    return [spot.pos.add(Vec3(z=9.0)), Vec3(y=math.degrees(spot.yaw))];
}

def podium_point(text: str) -> Vec3 {
    parts = text.split();
    if len(parts) != 3 {
        return Vec3();
    }
    return Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
}

"""SpawnPodium and SpawnModelOnVictoryPad: place the podium before the view
and the top three finishers' figures on its pads, all turned toward the view.
`held` is the human's weapon."""
def raise_podium(world: World, contest: ArenaMatch, level: Level, view: Vec3, angles: Vec3, held: str) -> Podium | None {
    podiums = [world->:HasPodium:->][?:Podium];
    if not podiums {
        return None;
    }
    podium = podiums[0];
    pitch = math.radians(angles.x);
    yaw = math.radians(angles.y);
    ahead = Vec3(x=math.cos(pitch) * math.cos(yaw), y=math.cos(pitch) * math.sin(yaw), z=-math.sin(pitch));
    base = view.add(ahead.scale(80.0)).sub(Vec3(z=70.0));
    toward = view.sub(base);
    facing = math.atan2(toward.y, toward.x);
    podium.pos = base;
    podium.yaw = facing;
    podium.visual.visible = True;
    podium.shown = True;
    podium.clock = 0.0;
    podium.celebrating = False;
    podium.celebrated = False;
    move_to_area(podium, level.areas[level.locate(base)]);
    cast = [edge podium->:Poses:->];
    figures = [podium->:Poses:->][?:Figure];
    forward = Vec3(x=math.cos(facing), y=math.sin(facing));
    right = Vec3(x=math.sin(facing), y=-math.cos(facing));
    rows = standings(contest);
    for place in range(min(3, len(rows))) {
        figure: Figure | None = None;
        for i in range(min(len(cast), len(figures))) {
            if (rows[place].human and cast[i].human)
                or (not rows[place].human and not cast[i].human and cast[i].name == rows[place].name) {
                figure = figures[i];
            }
        }
        if figure is None {
            continue;
        }
        dress_figure(figure, held);
        offset = PODIUM_OFFSETS[place];
        figure.pos = base.add(forward.scale(offset.x)).add(right.scale(offset.y)).add(Vec3(z=offset.z));
        figure.yaw = facing;
        figure.body.visible = True;
        figure.body.first = figure.stand_frame;
        figure.body.second = figure.stand_frame;
        figure.body.blend = 0.0;
        figure.weapon.first = figure.stand_frame;
        figure.weapon.second = figure.stand_frame;
        figure.weapon.blend = 0.0;
        podium +>:Stands(place=place + 1):+> figure;
        move_to_area(figure, level.areas[level.locate(figure.pos)]);
    }
    return podium;
}

"""Give a figure the weapon its competitor holds (a machine gun when it has
none, as SpawnModelOnVictoryPad does)."""
def dress_figure(figure: Figure, held: str) -> None {
    chosen: ModelResource | None = None;
    for bot in [figure->:Portrays:->][?:Opponent] {
        shown = bot.weapon_visual;
        if shown is not None {
            models = [shown->:UsesModel:->][?:ModelResource];
            if models {
                chosen = models[0];
            }
        }
    }
    links = [edge figure->:Wields:->];
    arms = [figure->:Wields:->][?:ModelResource];
    for i in range(min(len(links), len(arms))) {
        if links[i].key == (held or "machinegun") {
            chosen = arms[i];
        }
    }
    for old in [edge figure.weapon->:UsesModel:->] {
        del old;
    }
    if chosen is not None {
        figure.weapon +>:UsesModel:+> chosen;
    }
    figure.weapon.visible = chosen is not None;
}

"""CelebrateStart two seconds after the podium rises; CelebrateStop when the
gesture timer runs out."""
walker PodiumTick {
    has dt: float,
        cues: list[str] = [];

    can begin with World entry {
        visit [here->:HasPodium:->];
    }

    can celebrate with Podium entry {
        if not here.shown {
            return;
        }
        here.clock += self.dt;
        seats = [edge here->:Stands:->];
        figures = [here->:Stands:->][?:Figure];
        winner: Figure | None = None;
        for i in range(min(len(seats), len(figures))) {
            if seats[i].place == 1 {
                winner = figures[i];
            }
        }
        if winner is None or not winner.gesture_frames {
            return;
        }
        if not here.celebrating and not here.celebrated and here.clock >= 2.0 {
            here.celebrating = True;
            here.taunts += 1;
            if winner.taunt {
                self.cues.append(winner.taunt);
            }
        }
        if not here.celebrating {
            return;
        }
        elapsed = here.clock - 2.0;
        if elapsed >= GESTURE_TIME {
            here.celebrating = False;
            here.celebrated = True;
            winner.body.first = winner.stand_frame;
            winner.body.second = winner.stand_frame;
            winner.body.blend = 0.0;
        } else {
            position = elapsed * winner.gesture_rate;
            last = len(winner.gesture_frames) - 1;
            index = min(int(position), last);
            winner.body.first = winner.gesture_frames[index];
            winner.body.second = winner.gesture_frames[min(index + 1, last)];
            winner.body.blend = position - float(int(position)) if index < last else 0.0;
        }
        winner.weapon.first = winner.body.first;
        winner.weapon.second = winner.body.second;
        winner.weapon.blend = winner.body.blend;
    }
}
