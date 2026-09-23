"""Native check of the original end map: train, teleporter, telefrag and finale."""
import os;
import from engine.world.world { World, Player }
import from engine.world.level { load_level, spawn_player }
import from engine.world.combat { Opponent, HasOpponent, CombatState }
import from engine.world.finale {
    TeleportTrain,
    HasTeleportTrain,
    TeleportTrainTick,
    Finale,
    HasFinale,
    FinaleTick,
    telefrag,
    intermission_camera,
    SHUB_TEXT
}
import from engine.world.traversal { Traversal, HasTraversal, TraversalTick }
import from engine.core.savegame { snapshot, restore }
import from games.opponents { populate_opponents, populate_finale }
import from engine.math.vec3 { Vec3 }

with entry {
    directory = os.getenv("HOME", "") + "/quake-assets/id1";
    world = World();
    level = load_level(world, directory, "end", "q1");
    player = spawn_player(level);
    populate_opponents(world, level, directory);
    assert populate_finale(world, level, directory) == 1;
    trains = [world->:HasTeleportTrain:->][?:TeleportTrain];
    assert len(trains) == 1 and trains[0].speed == 200.0;
    bosses = [
        enemy
        for enemy in [world->:HasOpponent:->][?:Opponent]
        if enemy.rule.script == "shub"
    ];
    assert len(bosses) == 1 and bosses[0].health == 40000;
    assert len([world->:HasFinale:->]) == 1;
    followers = [
        link
        for link in [world->:HasTraversal:->][?:Traversal]
        if link.kind == "teleport_train"
    ];
    assert len(followers) == 1;
    start = trains[0].pos.add(Vec3());
    corners = 0;
    last = trains[0].current.entity;
    for i in range(1200) {
        world spawn TeleportTrainTick(dt=0.01);
        if trains[0].current.entity != last {
            corners += 1;
            last = trains[0].current.entity;
        }
    }
    assert corners >= 3 , str(corners);
    assert trains[0].pos.sub(start).length() > 10.0;
    print("FINALE PASS train corners", corners);
    view = intermission_camera(level.bsp);
    assert view.found;
    state = CombatState(game="q1");
    boss = bosses[0];
    inside = boss.pos.sub(Vec3(z=boss.eye_height)).add(Vec3(z=100.0));
    assert not telefrag(world, player, inside.add(Vec3(x=600.0)), level.collision.eye_height);
    assert telefrag(world, player, inside, level.collision.eye_height);
    assert boss.boss_phase == 1;
    saved = snapshot(world, level, player, state);
    for i in range(100) {
        world spawn FinaleTick(player=player, state=state, dt=0.1);
    }
    finale = [world->:HasFinale:->][?:Finale][0];
    assert boss.boss_phase == 3 and finale.text == SHUB_TEXT and state.kills == 1;
    print("FINALE PASS shub dissolved");
    restore(world, level, player, state, saved);
    assert boss.boss_phase == 1 and boss.visual.visible and finale.camera;
    print("FINALE PASS restored telefrag phase");
    e1m7 = World();
    ending = load_level(e1m7, directory, "e1m7", "q1");
    assert intermission_camera(ending.bsp).found;
    print("FINALE PASS e1m7 intermission camera");
}
