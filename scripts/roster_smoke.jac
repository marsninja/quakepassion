"""Check the complete Q1/Q2 rosters' original frames, sounds and missiles."""
import os;
import from engine.assets.library { AssetLibrary }
import from games.enemies { enemy_rule }
import from games.opponents { frame_indices }
import from engine.world.opponent_rule { rule_profiles }
import from games.weapons { weapon_effects }

with entry {
    rosters = {
        "q1": [
            "monster_army",
            "monster_dog",
            "monster_knight",
            "monster_enforcer",
            "monster_ogre",
            "monster_hell_knight",
            "monster_wizard",
            "monster_demon1",
            "monster_shambler",
            "monster_zombie",
            "monster_shalrath",
            "monster_tarbaby",
            "monster_fish"
        ],
        "q2": [
            "monster_soldier_light",
            "monster_soldier",
            "monster_soldier_ss",
            "monster_infantry",
            "monster_berserk",
            "monster_gladiator",
            "monster_chick",
            "monster_gunner",
            "monster_flyer",
            "monster_floater",
            "monster_hover",
            "monster_mutant",
            "monster_parasite",
            "monster_brain",
            "monster_medic",
            "monster_flipper",
            "monster_tank",
            "monster_tank_commander",
            "monster_supertank",
            "monster_boss2",
            "monster_jorg",
            "monster_makron",
            "misc_insane",
            "monster_commander_body",
            "monster_boss3_stand"
        ]
    };
    for game in ["q1", "q2"] {
    library = AssetLibrary(game=game);
    library.open(os.getenv("HOME", "") + "/quake-assets/" + ("id1" if game == "q1" else "baseq2"));
    try {
        for kind in rosters[game] {
            rule = enemy_rule(game, kind);
            assert rule is not None;
            model = library.model(rule.model, skin=rule.skin).model;
            names = [frame.name for frame in model.surfaces[0].frames];
            checked = 0;
            for group in [
                rule.knockdown.frames,
                rule.idle_frames,
                rule.run.frames,
                rule.walk.frames,
                rule.attack_frames,
                rule.melee_frames,
                rule.alternate_melee_frames
            ] + [sequence.frames for sequence in rule.pains + rule.deaths]
                + [other.frames for other in rule.other_walks] {
                for name in group {
                    assert name in names , kind + ":" + name;
                    checked += 1;
                }
            }
            # Every pain and death sequence: its frames in order in the model,
            # a stride for each frame, and its own sound in the archive.
            for sequence in rule.pains + rule.deaths {
                assert sequence.frames , kind + ":" + sequence.name;
                assert not sequence.steps or len(sequence.steps) == len(sequence.frames) , kind + ":" + sequence.name;
                placed = frame_indices(model.surfaces[0].frames, sequence.frames, rule.model, sequence.name);
                assert placed == [placed[0] + i for i in range(len(placed))] , kind + ":" + sequence.name;
            }
            sounds: list[str] = [rule.sight_sound, rule.death_sound] + rule.pain_sounds
                + [rule.attack_sound, rule.melee_sound]
                + [sequence.sound for sequence in rule.pains + rule.deaths];
            for sequence in rule.pains + rule.deaths + [rule.knockdown] {
                for event in sequence.events {
                    assert event.frame < len(sequence.frames) , kind + ":" + sequence.name;
                    sounds.extend(event.sounds);
                }
            }
            for profile in rule_profiles(rule) {
                assert len(profile.frames) == int(profile.duration * 10.0 + 0.5)
                    or not profile.frames , kind + ":" + profile.name;
                for name in profile.frames {
                    assert name in names , kind + ":" + name;
                    checked += 1;
                }
                for at in profile.times {
                    assert at <= profile.duration + 0.000001 , kind + ":" + profile.name;
                }
                sounds.append(profile.sound);
                sounds.append(profile.extra_sound);
                if profile.missile_effect {
                    found = False;
                    for effect in weapon_effects(game) {
                        if effect.key == profile.missile_effect {
                            if effect.flight.lower().endswith((".mdl", ".md2", ".md3")) {
                                assert library.model(effect.flight).model.surfaces;
                            } else {
                                assert len(library.read(effect.flight)) > 0;
                            }
                            found = True;
                        }
                    }
                    assert found , profile.missile_effect;
                }
            }
            for path in sounds {
                if path {
                    assert len(library.read(path)) > 44 , path;
                }
            }
            print("ROSTER ASSET PASS", game, kind, "frames", checked);
        }
        for pair in [("monster_zombie", 1), ("misc_insane", 8)] {
            if (game == "q1") != (pair[0] == "monster_zombie") {
                continue;
            }
            crucified = enemy_rule(game, pair[0], pair[1]);
            # The crucified zombie is a decoration; the crucified marine can be killed.
            assert crucified is not None and (crucified.decoration or crucified.passive);
            model = library.model(crucified.model).model;
            names = [frame.name for frame in model.surfaces[0].frames];
            for name in crucified.idle_frames {
                assert name in names , name;
            }
            print("ROSTER ASSET PASS", game, pair[0] + "(crucified)");
        }
    } finally {
        library.close();
    }
    }
}
