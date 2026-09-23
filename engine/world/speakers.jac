"""Authored sound emitters with shared activation and persistent loop state."""
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
        activation: Signal = Signal();
}

walker SpeakerTick {
    can begin with World entry {
        visit [here->:HasSpeaker:->];
    }
    can update with Speaker entry {
        if here.activation.killed {
            here.playing = False;
            here.requests = 0;
            return;
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
        activator = bsp.game == "q3" and flags & 8 != 0;
        if path.startswith("*") {
            path = "player/" + ("male/" if bsp.game == "q2" else "sarge/") + path[1:];
            activator = True;
        }
        if not path.lower().endswith(".wav") {
            path += ".wav";
        }
        if not path.startswith("sound/") {
            path = "sound/" + path;
        }
        parts = fields.get("origin", "0 0 0").split();
        if len(parts) != 3 {
            raise ValueError("Invalid speaker origin");
        }
        volume = float(fields.get("volume", "1"));
        if volume == 0.0 {
            volume = 1.0;
        }
        attenuation = float(fields.get("attenuation", "1"));
        if attenuation == 0.0 {
            attenuation = 1.0;
        }
        speaker = Speaker(
            path=path,
            origin=Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2])),
            volume=max(0.0, min(1.0, volume)),
            attenuation=max(0.0, attenuation),
            global_sound=bsp.game == "q3" and flags & 4 != 0,
            activator_sound=activator,
            looping=flags & 3 != 0,
            playing=flags & 1 != 0,
            activation=Signal(entities=[index])
        );
        world +>:HasSpeaker:+> speaker;
        world +>:HasSignal:+> speaker.activation;
    }
}
