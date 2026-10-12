"""Q1's last encounter: the spiked teleport train, the telefrag into
Shub-Niggurath, the finale timeline, and intermission cameras and texts."""
import from engine.formats.numbers { atof, atoi }
import math;
import from .world { World, Entity, Player }
import from .trains { TrackPoint, HasTrack, TrackNext }
import from .combat { Opponent, HasOpponent, CombatState, request_sound }
import from .models { Visual, ModelResource }
import from .signals { Signal, HasSignal, Fire }
import from .gibs { GibsInto, GibDice, launch_gib }
import from .fixtures { Fixture }
import from .lightstyles { LightStyles, HasLightStyles }
import from .particles { teleport_splash }
import from ..formats.bsp { Bsp, MapEntity }
import from ..math.vec3 { Vec3 }

edge HasTeleportTrain: World --> TeleportTrain {}
node TeleportTrain(Entity) {
    has entity: int,
        current: TrackPoint,
        destination: TrackPoint | None = None,
        speed: float = 100.0,
        visual: Visual = Visual(),
        running: bool = True,
        activation: Signal = Signal();
}

edge HasFinale: World --> Finale {}
node Finale {
    has camera: bool = False,
        origin: Vec3 = Vec3(),
        yaw: float = 0.0,
        pitch: float = 0.0,
        text: str = "";
}

"""The player model oldone.qc finale_4 puts down by the pit once
Shub-Niggurath is gone; it stands hidden until then."""
edge LeftStanding: Opponent --> Fixture {}

# oldone.qc: finale_1's timer runs finale_2 (the teleport splash inside her)
# after a second, and finale_3 (the thrashing) two seconds after that.
glob SHUB_SPLASH_AT: float = 1.0,
     SHUB_THRASH_AT: float = 3.0;

# The brightness old_thrash1-19 give light style 0, a frame each; old_thrash20
# runs finale_4, which sets it back to normal.
glob SHUB_THRASH_LIGHT: str = "mkkigecacegikmmgcba";

"""Which old_thrash function plays on the `frame`th tenth of a second of the
thrashing: old_thrash1-15 three times over (old_thrash15 counts the passes),
then old_thrash16-20."""
def shub_thrash(frame: int) -> int {
    if frame < 45 {
        return frame % 15 + 1;
    }
    return min(20, frame - 29);
}

obj IntermissionView {
    has found: bool = False,
        origin: Vec3 = Vec3(),
        yaw: float = 0.0,
        pitch: float = 0.0;
}

def entity_point(entity: MapEntity) -> Vec3 {
    parts = entity.fields.get("origin", "0 0 0").split();
    if len(parts) != 3 {
        raise ValueError("Invalid finale origin");
    }
    return Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
}

# An authored intermission camera; `pick` chooses among several (Q1
# FindIntermission picks one at random). Q1 info_intermission uses `mangle`,
# Q2 info_player_intermission `angles`; pitch is positive downward.
def intermission_camera(bsp: Bsp, pick: int = 0) -> IntermissionView {
    spots = [
        entity
        for entity in bsp.entities
        if entity.fields.get("classname", "")
            in ["info_intermission", "info_player_intermission"]
    ];
    view = IntermissionView();
    if not spots and bsp.game == "q2" {
        # p_hud.c BeginIntermission: "the map creator forgot to put in an
        # intermission point", so the first player start serves.
        spots = [
            entity for entity in bsp.entities if entity.fields.get("classname", "") == "info_player_start"
        ][:1];
        pick = 0;
    }
    if not spots {
        return view;
    }
    entity = spots[pick % len(spots)];
    key = "mangle" if entity.fields.get("classname", "") == "info_intermission" else "angles";
    # A point entity's "angle" is its yaw (G_SetMovedir's ED_ParseField).
    angles = entity.fields.get(key, "0 " + entity.fields.get("angle", "0") + " 0").split();
    if len(angles) != 3 {
        raise ValueError("Invalid intermission angles");
    }
    view.found = True;
    view.origin = entity_point(entity);
    view.pitch = -float(angles[0]) * math.pi / 180.0;
    view.yaw = float(angles[1]) * math.pi / 180.0;
    return view;
}

glob EPISODE_TEXTS: dict[str, str] = {
         "e1m7": "As the corpse of the monstrous entity\nChthon sinks back into the lava whence\nit rose, you grip the Rune of Earth\nMagic tightly. Now that you have\nconquered the Dimension of the Doomed,\nrealm of Earth Magic, you are ready to\ncomplete your task. A Rune of magic\npower lies at the end of each haunted\nland of Quake. Go forth, seek the\ntotality of the four Runes!",
         "e2m6": "The Rune of Black Magic throbs evilly in\nyour hand and whispers dark thoughts\ninto your brain. You learn the inmost\nlore of the Hell-Mother; Shub-Niggurath!\nYou now know that she is behind all the\nterrible plotting which has led to so\nmuch death and horror. But she is not\ninviolate! Armed with this Rune, you\nrealize that once all four Runes are\ncombined, the gate to Shub-Niggurath's\nPit will open, and you can face the\nWitch-Goddess herself in her frightful\notherworld cathedral.",
         "e3m6": "The charred viscera of diabolic horrors\nbubble viscously as you seize the Rune\nof Hell Magic. Its heat scorches your\nhand, and its terrible secrets blight\nyour mind. Gathering the shreds of your\ncourage, you shake the devil's shackles\nfrom your soul, and become ever more\nhard and determined to destroy the\nhideous creatures whose mere existence\nthreatens the souls and psyches of all\nthe population of Earth.",
         "e4m7": "Despite the awful might of the Elder\nWorld, you have achieved the Rune of\nElder Magic, capstone of all types of\narcane wisdom. Beyond good and evil,\nbeyond life and death, the Rune\npulsates, heavy with import. Patient and\npotent, the Elder Being Shub-Niggurath\nweaves her dire plans to clear off all\nlife from the Earth, and bring her own\nfoul offspring to our world! For all the\ndwellers in these nightmare dimensions\nare her descendants! Once all Runes of\nmagic power are united, the energy\nbehind them will blast open the Gateway\nto Shub-Niggurath, and you can travel\nthere to foil the Hell-Mother's plots\nin person."
     };

glob RUNES_TEXT: str = "Now, you have all four Runes. You sense\ntremendous invisible forces moving to\nunseal ancient barriers. Shub-Niggurath\nhad hoped to use the Runes Herself to\nclear off the Earth, but now instead,\nyou will use them to enter her home and\nconfront her as an avatar of avenging\nEarth-life. If you defeat her, you will\nbe remembered forever as the savior of\nthe planet. If she conquers, it will be\nas if you had never been born.";

glob SHUB_TEXT: str = "Congratulations and well done! You have\nbeaten the hideous Shub-Niggurath, and\nher hundreds of ugly changelings and\nmonsters. You have proven that your\nskill and your cunning are greater than\nall the powers of Quake. You are the\nmaster now. Id Software salutes you.";

def episode_text(game: str, map_name: str, destination: str) -> str {
    if game == "q1" and destination == "start" and map_name in EPISODE_TEXTS {
        return EPISODE_TEXTS[map_name];
    }
    return "";
}

# Point path corners exist for every named corner already; the train only needs
# the first one and the shared next links.
def load_finale(world: World, bsp: Bsp) {
    if bsp.game != "q1" {
        return;
    }
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        if fields.get("classname", "") != "misc_teleporttrain" {
            continue;
        }
        target = fields.get("target", "");
        first: TrackPoint | None = None;
        for point in [world->:HasTrack:->][?:TrackPoint] {
            if point.name == target {
                first = point;
                break;
            }
        }
        if first is None {
            continue;
        }
        speed = atof(fields.get("speed", "0"));
        if speed <= 0.0 {
            speed = 100.0;
        }
        # func_train_find: a named train waits for its first use (train_use).
        train = TeleportTrain(
            entity=index,
            current=first,
            speed=speed,
            pos=first.origin.add(Vec3()),
            running=not fields.get("targetname", ""),
            activation=Signal(entities=[index])
        );
        world +>:HasTeleportTrain:+> train;
        world +>:HasSignal:+> train.activation;
    }
    for entity in bsp.entities {
        if entity.fields.get("classname", "") == "monster_oldone" {
            world +>:HasFinale:+> Finale();
            break;
        }
    }
}

def teleport_train_at(world: World, entity: int) -> TeleportTrain | None {
    for train in [world->:HasTeleportTrain:->][?:TeleportTrain] {
        if train.entity == entity {
            return train;
        }
    }
    return None;
}

# Shub-Niggurath's authored bounds are 320 by 256 wide and 280 tall around
# an origin 24 units above her base.
def inside_boss(boss: Opponent, point: Vec3) -> bool {
    origin = boss.pos.sub(Vec3(z=boss.eye_height));
    return abs(point.x - origin.x) <= boss.rule.width
        and abs(point.y - origin.y) <= boss.rule.width * 0.8
        and point.z >= origin.z - 24.0
        and point.z <= origin.z + 256.0;
}

walker TeleportTrainTick {
    has dt: float;

    can begin with World entry {
        if self.dt > 0.0 {
            visit [here->:HasTeleportTrain:->];
        }
    }

    can advance with TeleportTrain entry {
        if here.activation.pending > 0 {
            here.activation.pending = 0;
            here.running = True;
        }
        if not here.running {
            return;
        }
        remaining = here.speed * self.dt;
        if remaining <= 0.0 {
            return;
        }
        here.yaw += self.dt * 3.5;
        stalled: list[TrackPoint] = [];
        while remaining > 0.0 {
            if here.destination is None {
                options = [here.current->:TrackNext:->][?:TrackPoint];
                if not options {
                    return;
                }
                here.destination = options[0];
            }
            destination = here.destination;
            if destination is None {
                return;
            }
            delta = destination.origin.sub(here.pos);
            distance = delta.length();
            # Coincident corners must not hang a tick on a zero-length cycle.
            if distance == 0.0 {
                if destination in stalled {
                    return;
                }
                stalled.append(destination);
            } else {
                stalled = [];
            }
            if distance > remaining {
                here.pos = here.pos.add(delta.scale(remaining / distance));
                return;
            }
            here.pos = destination.origin.add(Vec3());
            here.current = destination;
            here.destination = None;
            remaining = max(0.0, remaining - distance);
        }
    }
}

"""Set light style 0, the map's ordinary light, to one brightness letter."""
def shub_light(world: World, letter: str) {
    for styles in [world->:HasLightStyles:->][?:LightStyles] {
        if styles.patterns.get(0, "m") != letter {
            styles.patterns[0] = letter;
            styles.refresh();
        }
    }
}

"""What a finished or unfinished finale leaves in the world, put right as the
finale ends and after a save is restored: once she is gone (finale_4) the
player model stands by the pit and the light is back to normal."""
def settle_finale(world: World, boss: Opponent) {
    gone = boss.boss_phase >= 3;
    for figure in [boss->:LeftStanding:->][?:Fixture] {
        figure.visual.visible = gone;
    }
    if gone {
        boss.visual.visible = False;
    }
    if boss.boss_phase != 2 {
        shub_light(world, "m");
    }
}

# Phases: 0 idle, 1 telefragged (finale_1 and finale_2), 2 thrashing
# (finale_3), 3 gone (finale_4). The boss only dies by telefrag; ordinary
# damage is refused by the shared combat rules. Her think keeps its own 10 Hz
# beat through finale_1-3; it is taken here to fall on finale_3's, so the
# pulsing style finale_3 sets gives way to old_thrash1's at once.
walker FinaleTick {
    has player: Player,
        state: CombatState,
        dt: float,
        world: World | None = None,
        completed: bool = False;

    can begin with World entry {
        if self.dt <= 0.0 {
            return;
        }
        self.world = here;
        here spawn TeleportTrainTick(dt=self.dt);
        visit [here->:HasOpponent:->];
    }

    """old_idle1-46, which she keeps playing until finale_3."""
    def idle(boss: Opponent) {
        if not boss.idle_animation {
            return;
        }
        boss.animation_time += self.dt * 10.0;
        index = int(boss.animation_time) % len(boss.idle_animation);
        boss.visual.first = boss.idle_animation[index];
        boss.visual.second = boss.idle_animation[(index + 1) % len(boss.idle_animation)];
        boss.visual.blend = boss.animation_time - float(int(boss.animation_time));
    }

    """finale_4: fifty gibs thrown from a 5 by 5 grid at two heights, a third
    each of gib1, gib2 and gib3 as ThrowGib(-999) throws them, the closing
    text, and the boss gone. She was never flagged FL_MONSTER, so Killed
    does not count her among the kills."""
    def burst(world: World, boss: Opponent) {
        if boss.rule.pain_sounds {
            request_sound(boss, boss.rule.pain_sounds[0]);
        }
        rule = boss.gib_rule;
        models = [boss->:GibsInto:->][?:ModelResource];
        if rule is not None and models {
            dice = GibDice(seed=max(1, boss.shot_random % 2147483647));
            origin = boss.pos.sub(Vec3(z=boss.eye_height));
            for height in [16.0, 112.0] {
                for across in range(5) {
                    for along in range(5) {
                        roll = dice.roll();
                        pick = 0 if roll < 0.3 else (1 if roll < 0.6 else 2);
                        launch_gib(
                            world,
                            boss,
                            models[min(pick, len(models) - 1)],
                            rule,
                            origin.add(
                                Vec3(
                                    x=float(across) * 32.0 - 64.0,
                                    y=float(along) * 32.0 - 64.0,
                                    z=height
                                )
                            ),
                            999,
                            dice
                        );
                    }
                }
            }
        }
        boss.boss_phase = 3;
        boss.boss_time = 0.0;
        boss.health = 0;
        for finale in [world->:HasFinale:->][?:Finale] {
            finale.text = SHUB_TEXT;
        }
        settle_finale(world, boss);
        self.completed = True;
    }

    can boss with Opponent entry {
        world = self.world;
        if here.rule.script != "shub" or world is None {
            return;
        }
        if here.boss_phase == 0 {
            self.idle(here);
            return;
        }
        if here.boss_phase >= 3 {
            self.completed = True;
            return;
        }
        before = here.boss_time;
        here.boss_time += self.dt;
        if here.boss_phase == 1 {
            self.idle(here);
            # finale_2: a teleport splash inside her, 100 units along -y.
            if before < SHUB_SPLASH_AT and here.boss_time >= SHUB_SPLASH_AT {
                teleport_splash(
                    world, here.pos.sub(Vec3(z=here.eye_height)).sub(Vec3(y=100.0))
                );
                request_sound(here, "sound/misc/r_tele1.wav");
            }
            if here.boss_time < SHUB_THRASH_AT {
                return;
            }
            # finale_3: she starts thrashing wildly.
            here.boss_phase = 2;
            here.boss_time -= SHUB_THRASH_AT;
            request_sound(here, here.rule.death_sound);
        }
        frame = int(here.boss_time * 10.0 + 0.000001);
        state = shub_thrash(frame);
        if state >= 20 {
            self.burst(world, here);
            return;
        }
        frames = here.death_animation;
        if frames {
            here.visual.first = frames[(state - 1) % len(frames)];
            here.visual.second = frames[(shub_thrash(frame + 1) - 1) % len(frames)];
            here.visual.blend = here.boss_time * 10.0 - float(frame);
        }
        shub_light(world, SHUB_THRASH_LIGHT[state - 1]);
    }
}

# Telefrag resolution shared by the traversal contact and tests.
def telefrag(world: World, player: Player, point: Vec3, eye_height: float) -> bool {
    struck = False;
    for boss in [world->:HasOpponent:->][?:Opponent] {
        if boss.rule.script != "shub" or boss.boss_phase != 0 or boss.dormant {
            continue;
        }
        if inside_boss(boss, point) {
            boss.boss_phase = 1;
            boss.boss_time = 0.0;
            # combat.qc Killed: monster_death_use fires her targets.
            boss.activation spawn Fire();
            struck = True;
        }
    }
    if struck {
        for finale in [world->:HasFinale:->][?:Finale] {
            finale.camera = True;
        }
    }
    return struck;
}
