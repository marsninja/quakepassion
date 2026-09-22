"""Decode and play every weapon sound through the native audio backend."""
import os;
import time;
import from games.weapons { weapon_sounds }
import from engine.audio.feedback { Feedback }
with entry {
    for pair in [("q1", "id1"), ("q2", "baseq2"), ("q3", "baseq3")] {
        names = weapon_sounds(pair[0]);
        audio = Feedback(volume=0.0);
        audio.open(pair[0], os.getenv("HOME", "") + "/quake-assets/" + pair[1], names);
        assert audio.ready and len(audio.sounds) == 3 + len(names);
        for index in range(len(names)) {
            audio.play(3 + index);
        }
        time.sleep(0.02);
        audio.close();
        assert not audio.ready and not audio.sounds;
        print("WEAPON AUDIO PASS", pair[0], len(names));
    }
}
