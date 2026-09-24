"""Q3 single-player podium (g_arenas.c). When an arena match ends, the view
moves to the intermission point (FindIntermissionPoint), the podium model rises
80 units ahead of it and 70 below, and copies of the top three finishers stand
on its pads facing the camera (SpawnModelsOnVictoryPads). Two seconds later the
winner plays its gesture and taunt (CelebrateStart), and stands again when the
gesture timer runs out (CelebrateStop)."""
import math;
import from .world { World, Entity, move_to_area }
import from .models { Visual, ModelResource, UsesModel, HasVisual, PlayerRig, WeaponKit, Holds }
import from .player_rig { PoseRig, hold_kit, reset_rig }
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

node Podium(Entity) {
    has visual: Visual = Visual(),
        shown: bool = False,
        clock: float = 0.0,
        celebrating: bool = False,
        celebrated: bool = False,
        taunts: int = 0;
}

"""A finisher's stand-in on the podium: its body (holding a weapon) and taunt."""
node Figure(Entity) {
    has body: PlayerRig = PlayerRig(),
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
edge Wields: Figure --> WeaponKit {
    has key: str = "";
}

"""A figure for one finisher, drawn with the given body."""
def podium_figure(body: PlayerRig, taunt: str) -> Figure {
    figure = Figure(body=body, taunt=taunt);
    figure +>:HasVisual:+> body;
    body.visible = False;
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
        # SpawnModelOnVictoryPad: standing, facing the view.
        reset_rig(figure.body, math.degrees(facing));
        figure.body spawn PoseRig(dt=0.0, yaw=facing);
        podium +>:Stands(place=place + 1):+> figure;
        move_to_area(figure, level.areas[level.locate(figure.pos)]);
    }
    return podium;
}

"""Give a figure the weapon its competitor holds (a machine gun when it has
none, as SpawnModelOnVictoryPad does)."""
def dress_figure(figure: Figure, held: str) -> None {
    chosen: WeaponKit | None = None;
    for bot in [figure->:Portrays:->][?:Opponent] {
        rig = bot.visual;
        if isinstance(rig, PlayerRig) {
            kits = [rig->:Holds:->][?:WeaponKit];
            if kits {
                chosen = kits[0];
            }
        }
    }
    links = [edge figure->:Wields:->];
    arms = [figure->:Wields:->][?:WeaponKit];
    for i in range(min(len(links), len(arms))) {
        if links[i].key == (held or "machinegun") {
            chosen = arms[i];
        }
    }
    hold_kit(figure.body, chosen);
}

"""CelebrateStart two seconds after the podium rises: the winner plays
TORSO_GESTURE and its taunt; CelebrateStop returns it to TORSO_STAND when the
gesture timer runs out. Every figure keeps breathing on LEGS_IDLE."""
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
        gesture = False;
        if winner is not None and not here.celebrating and not here.celebrated and here.clock >= 2.0 {
            here.celebrating = True;
            gesture = True;
            here.taunts += 1;
            if winner.taunt {
                self.cues.append(winner.taunt);
            }
        }
        if here.celebrating and winner is not None and winner.body.torso_timer <= 0.0 and not gesture {
            here.celebrating = False;
            here.celebrated = True;
        }
        for figure in figures {
            figure.body spawn PoseRig(dt=self.dt, yaw=figure.yaw, gesture=gesture and figure is winner);
        }
    }
}
