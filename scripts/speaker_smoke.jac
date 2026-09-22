"""Native original-map audio decode, loop toggles, pause, and resource cleanup."""
import os;
import time;
import from engine.audio.feedback { Feedback, IsMusicStreamPlaying }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World }
import from engine.world.speakers { Speaker, HasSpeaker, SpeakerTick }
import from engine.world.signals { Fire }


with entry {
    for game in ["q2", "q3"] {
        directory = os.getenv("HOME", "")
            + "/quake-assets/"
            + ("baseq2" if game == "q2" else "baseq3");
        world = World();
        level = load_level(
            world, directory, "base1" if game == "q2" else "q3dm7", game
        );
        player = spawn_player(level);
        audio = Feedback(volume=0.02);
        audio.open(game, directory);
        assert audio.ready;
        speakers = [world->:HasSpeaker:->][?:Speaker];
        assert len(speakers) > 0;
        for speaker in speakers {
            if not speaker.looping {
                speaker.activation spawn Fire(emit=False);
            }
        }
        world spawn SpeakerTick();
        for frame in range(30) {
            audio.update(world, player.pos, player.yaw);
            time.sleep(1.0 / 120.0);
        }
        assert len(audio.emitters) > 0 and len(audio.missing) == 0;
        audio.update(world, player.pos, player.yaw, paused=True);
        for voice in audio.emitters.values() {
            assert not IsMusicStreamPlaying(voice.music);
        }
        audio.update(world, player.pos, player.yaw);
        for speaker in speakers {
            if speaker.looping and speaker.playing {
                speaker.activation spawn Fire(emit=False);
            }
        }
        world spawn SpeakerTick();
        audio.update(world, player.pos, player.yaw);
        for index in audio.emitters {
            if speakers[index].looping {
                assert not IsMusicStreamPlaying(audio.emitters[index].music);
            }
        }
        print(
            "SPEAKERS PASS",
            game,
            len(speakers),
            "emitters",
            len(audio.emitters),
            "decoded streams"
        );
        audio.close();
        assert not audio.ready and len(audio.emitters) == 0 and audio.library is None;
    }
}
