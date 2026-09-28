import from engine.world.speakers { Speaker, HasSpeaker, SpeakerTick, load_speakers }
import from engine.audio.feedback { sound_falloff }
import from games.fixtures { fixture_rule }
import from engine.world.signals { Fire }
import from engine.world.world { World, Player }
import from engine.world.level { Level }
import from engine.world.combat { CombatState }
import from engine.core.savegame { snapshot, restore }
import from engine.formats.bsp { Bsp, MapEntity }

test "authored speaker flags paths and toggle state survive saves" {
    for game in ["q2", "q3"] {
        world = World();
        bsp = Bsp(
            game=game,
            entities=[
                MapEntity(
                    fields={
                        "classname": "target_speaker",
                        "noise": "world/wind",
                        "spawnflags": "1"
                    }
                ),
                MapEntity(
                    fields={
                        "classname": "target_speaker",
                        "noise": "world/beep.wav",
                        "spawnflags": "0"
                    }
                ),
                MapEntity(
                    fields={
                        "classname": "target_speaker",
                        "noise": "*pain.wav",
                        "spawnflags": "0"
                    }
                )
            ]
        );
        load_speakers(world, bsp);
        speakers = [world->:HasSpeaker:->][?:Speaker];
        assert len(speakers) == 3;
        assert speakers[0].path == "sound/world/wind.wav"
            and speakers[0].playing
            and speakers[0].looping;
        assert speakers[1].path == "sound/world/beep.wav" and not speakers[1].looping;
        # Q3 plays sexed sounds on the activator; Q2 at the speaker.
        assert speakers[2].activator_sound == (game == "q3");
        speakers[0].activation spawn Fire(emit=False);
        speakers[1].activation spawn Fire(emit=False);
        world spawn SpeakerTick();
        assert not speakers[0].playing and speakers[1].requests == 1;
        player = Player();
        state = CombatState();
        level = Level(bsp=bsp, name="fixture");
        data = snapshot(world, level, player, state);
        speakers[0].playing = True;
        speakers[1].requests = 0;
        restore(world, level, player, state, data);
        assert not speakers[0].playing and speakers[1].requests == 1;
        speakers[0].activation spawn Fire(emit=False);
        speakers[0].activation spawn Fire(emit=False);
        world spawn SpeakerTick();
        assert not speakers[0].playing;
    }
}

test "target_speaker keys follow each game's SP_target_speaker" {
    entities = [
        MapEntity(
            fields={
                "classname": "target_speaker",
                "noise": "world/amb1",
                "spawnflags": "1",
                "volume": "0.3",
                "attenuation": "2"
            }
        ),
        MapEntity(
            fields={
                "classname": "target_speaker",
                "noise": "world/voice.wav",
                "volume": "0.4",
                "attenuation": "-1"
            }
        ),
        MapEntity(
            fields={
                "classname": "target_speaker",
                "noise": "sound/world/growl3.wav",
                "wait": "20",
                "random": "15"
            }
        ),
        MapEntity(
            fields={
                "classname": "target_speaker",
                "noise": "sound/world/drip.wav",
                "wait": "5",
                "random": "0.05"
            }
        )
    ];
    q2 = World();
    load_speakers(q2, Bsp(game="q2", entities=entities));
    loud = [q2->:HasSpeaker:->][?:Speaker];
    # Q2 loops are always volume 1 at the looping falloff; -1 is everywhere.
    assert loud[0].volume == 1.0 and loud[0].attenuation == 3.0 and loud[0].playing;
    assert abs(loud[1].volume - 0.4) < 0.0001 and loud[1].attenuation == 0.0;
    assert loud[2].repeat_spread == 0.0;
    q3 = World();
    load_speakers(q3, Bsp(game="q3", entities=entities));
    heard = [q3->:HasSpeaker:->][?:Speaker];
    # Q3 ignores volume and attenuation, and repeats speakers with a random.
    assert heard[0].volume == 1.0 and heard[1].attenuation == 1.0;
    assert heard[2].repeat_wait == 20.0 and heard[2].repeat_spread == 15.0;
    # CG_Speaker tests s.clientNum (random in tenths): 0.05 never repeats.
    assert heard[3].repeat_wait == 5.0 and heard[3].repeat_spread == 0.0;
    q3 spawn SpeakerTick(dt=0.1);
    assert heard[2].requests == 1 and heard[3].requests == 0;
    assert heard[2].repeat_clock >= 5.0 and heard[2].repeat_clock <= 35.0;
    waited = heard[2].repeat_clock;
    q3 spawn SpeakerTick(dt=waited - 0.05);
    assert heard[2].requests == 1;
    q3 spawn SpeakerTick(dt=0.1);
    assert heard[2].requests == 2;
}

test "each game's spatialization falls off at its own rate" {
    # Quake: attenuation / 1000 a unit from the source.
    assert abs(sound_falloff("q1", 500.0, 1.0, False) - 0.5) < 0.0001;
    assert abs(sound_falloff("q1", 100.0, 3.0, True) - 0.7) < 0.0001;
    # Quake II: full inside 80 units, loops at 0.003, ATTN_NORM at 0.0005.
    assert sound_falloff("q2", 60.0, 1.0, False) == 1.0;
    assert abs(sound_falloff("q2", 1080.0, 1.0, False) - 0.5) < 0.0001;
    assert abs(sound_falloff("q2", 180.0, 1.0, True) - 0.7) < 0.0001;
    assert abs(sound_falloff("q2", 180.0, 3.0, False) - 0.7) < 0.0001;
    # Quake III: 0.0008 a unit past 80, whatever the attenuation.
    assert abs(sound_falloff("q3", 705.0, 3.0, False) - 0.5) < 0.0001;
    assert sound_falloff("q2", 5000.0, 0.0, False) == 1.0;
}

test "teleporters hum as triggers.qc and g_misc.c make them" {
    hum = fixture_rule("q1", {"classname": "trigger_teleport", "model": "*3"});
    assert hum is not None and hum.sound == "sound/ambience/hum1.wav";
    assert hum.volume == 0.5 and hum.attenuation == 3.0 and hum.centered;
    assert fixture_rule("q1", {"classname": "trigger_teleport", "spawnflags": "2"}) is None;
    pad = fixture_rule("q2", {"classname": "misc_teleporter", "target": "t1"});
    assert pad is not None and pad.sound == "sound/world/amb10.wav";
    assert fixture_rule("q2", {"classname": "misc_teleporter"}) is None;
    thunder = fixture_rule("q1", {"classname": "ambient_thunder"});
    assert thunder is not None and thunder.sound == "sound/ambience/thunder1.wav";
}
