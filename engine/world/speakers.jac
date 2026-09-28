"""Authored sound emitters with shared activation and persistent loop state.

Q2 and Q3 target_speaker (g_target.c SP_target_speaker, Use_Target_Speaker):
spawnflags 1 and 2 make a looping sound that each use toggles (1 starts it
on); otherwise each use plays the sound once. Q2 loops always play at volume
1 and the looping attenuation, and "attenuation" -1 means heard everywhere.
Q3 global (4) and activator (8) speakers play at full volume, and a Q3
speaker with a "random" of a tenth or more also sounds by itself every
"wait" seconds, give or take "random" (cg_ents.c CG_Speaker)."""
import from .world { World }
import from .signals { Signal, HasSignal }
import from ..formats.bsp { Bsp }
import from ..math.vec3 { Vec3 }

edge HasSpeaker: World --> Speaker {}
node Speaker {
    has path: str,
        origin: Vec3,
        volume: float = 1.0,
        attenuation: float = 1.0,
        global_sound: bool = False,
        activator_sound: bool = False,
        looping: bool = False,
        playing: bool = False,
        requests: int = 0,
        activation: Signal = Signal(),
        # CG_Speaker's s.frame and s.clientNum: wait and random in tenths.
        repeat_wait: float = 0.0,
        repeat_spread: float = 0.0,
        repeat_clock: float = 0.0,
        random_state: int = 1;

    """crandom(): a value between -1 and 1."""
    def crandom() -> float {
        self.random_state = (self.random_state * 48271) % 2147483647;
        return float(self.random_state) / 2147483647.0 * 2.0 - 1.0;
    }
}

walker SpeakerTick {
    has dt: float = 0.0;

    can begin with World entry {
        visit [here->:HasSpeaker:->];
    }
    can update with Speaker entry {
        if here.activation.killed {
            here.playing = False;
            here.requests = 0;
            return;
        }
        # CG_Speaker: an automatic speaker sounds whenever its time comes.
        if here.repeat_spread > 0.0 and self.dt > 0.0 {
            here.repeat_clock -= self.dt;
            if here.repeat_clock <= 0.0 {
                here.requests += 1;
                here.repeat_clock = here.repeat_wait + here.repeat_spread * here.crandom();
            }
        }
        if here.activation.pending > 0 {
            if here.looping {
                if here.activation.pending % 2 != 0 {
                    here.playing = not here.playing;
                }
            } else {
                here.requests += here.activation.pending;
            }
            here.activation.pending = 0;
        }
    }
}

def load_speakers(world: World, bsp: Bsp) {
    if bsp.game not in ["q2", "q3"] {
        return;
    }
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        if fields.get("classname", "") != "target_speaker" {
            continue;
        }
        path = fields.get("noise", "");
        if not path {
            continue;
        }
        flags = int(fields.get("spawnflags", "0"));
        q3 = bsp.game == "q3";
        activator = q3 and flags & 8 != 0;
        if path.startswith("*") {
            # Sexed sounds: Q3 plays them on the activator; Q2 plays them at
            # the speaker in the default male voice (S_RegisterSexedSound).
            path = "player/" + ("male/" if bsp.game == "q2" else "sarge/") + path[1:];
            activator = q3;
        }
        if ".wav" not in path.lower() {
            path += ".wav";
        }
        if not path.startswith("sound/") {
            path = "sound/" + path;
        }
        parts = fields.get("origin", "0 0 0").split();
        if len(parts) != 3 {
            raise ValueError("Invalid speaker origin");
        }
        looping = flags & 3 != 0;
        volume = 1.0;
        attenuation = 1.0;
        if not q3 and not looping {
            # Q2 SP_target_speaker: 0 means 1, and -1 means no attenuation.
            volume = float(fields.get("volume", "1"));
            if volume == 0.0 {
                volume = 1.0;
            }
            attenuation = float(fields.get("attenuation", "1"));
            if attenuation == 0.0 {
                attenuation = 1.0;
            } elif attenuation == -1.0 {
                attenuation = 0.0;
            }
        } elif not q3 {
            # Q2 looped sounds are always volume 1 at the looping falloff.
            attenuation = 3.0;
        }
        delay = float(fields.get("wait", "0")) if q3 else 0.0;
        spread = float(fields.get("random", "0")) if q3 else 0.0;
        speaker = Speaker(
            path=path,
            origin=Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2])),
            volume=max(0.0, min(1.0, volume)),
            attenuation=max(0.0, attenuation),
            global_sound=q3 and flags & 4 != 0,
            activator_sound=activator,
            looping=looping,
            playing=flags & 1 != 0,
            activation=Signal(entities=[index]),
            # SP_target_speaker stores them in tenths of a second.
            repeat_wait=float(int(delay * 10.0)) / 10.0,
            repeat_spread=float(int(spread * 10.0)) / 10.0,
            random_state=index + 1
        );
        world +>:HasSpeaker:+> speaker;
        world +>:HasSignal:+> speaker.activation;
    }
}
