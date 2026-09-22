import from engine.world.speakers { Speaker, HasSpeaker, SpeakerTick, load_speakers }
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
        assert speakers[2].activator_sound;
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
