import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, damage_opponent }
import from engine.world.trains { TrackPoint, HasTrack, TrackNext }
import from engine.world.finale {
    TeleportTrain,
    HasTeleportTrain,
    TeleportTrainTick,
    Finale,
    HasFinale,
    FinaleTick,
    telefrag,
    episode_text,
    intermission_camera,
    SHUB_TEXT
}
import from engine.world.exits { exit_map, exit_spawn, exit_cinematic }
import from engine.world.level { Level }
import from engine.formats.bsp { MapEntity }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }

def circuit(world: World) -> TeleportTrain {
    a = TrackPoint(entity=1, name="a", origin=Vec3());
    b = TrackPoint(entity=2, name="b", origin=Vec3(x=100.0));
    c = TrackPoint(entity=3, name="c", origin=Vec3(x=100.0, y=100.0));
    a +>:TrackNext:+> b;
    b +>:TrackNext:+> c;
    c +>:TrackNext:+> a;
    for point in [a, b, c] {
        world +>:HasTrack:+> point;
    }
    train = TeleportTrain(entity=9, current=a, speed=200.0, pos=Vec3());
    world +>:HasTeleportTrain:+> train;
    return train;
}

test "teleport train runs its corner loop at authored speed" {
    world = World();
    train = circuit(world);
    for i in range(25) {
        world spawn TeleportTrainTick(dt=0.01);
    }
    assert abs(train.pos.x - 50.0) < 0.001 and train.destination is not None;
    for i in range(50) {
        world spawn TeleportTrainTick(dt=0.01);
    }
    assert abs(train.pos.x - 100.0) < 0.001 and abs(train.pos.y - 50.0) < 0.001;
    for i in range(150) {
        world spawn TeleportTrainTick(dt=0.01);
    }
    # 450 units along a 341.4 unit loop ends 8.6 units past the second corner.
    assert abs(train.pos.x - 100.0) < 0.5 and train.pos.y > 8.0 and train.pos.y < 9.5;
    assert train.yaw > 0.0 and train.current.entity == 2;
}

test "telefrag inside shub starts the finale and finishes with the closing text" {
    rule = enemy_rule("q1", "monster_oldone");
    assert rule is not None and rule.script == "shub";
    world = World();
    level = Level(name="end");
    level.bsp.game = "q1";
    circuit(world);
    world +>:HasFinale:+> Finale();
    shub = Opponent(
        rule=rule,
        pos=Vec3(x=-752.0, y=2032.0, z=80.0 + 22.0),
        health=40000,
        idle_animation=[0, 1, 2],
        death_animation=[5, 6, 7]
    );
    world +>:HasOpponent:+> shub;
    player = Player(pos=Vec3(x=-400.0, y=2032.0, z=100.0));
    state = CombatState(game="q1");
    assert damage_opponent(shub, 5000) == 0 and shub.health == 40000;
    assert not telefrag(world, player, Vec3(x=-400.0, y=2032.0, z=80.0), 22.0);
    assert shub.boss_phase == 0;
    world spawn FinaleTick(player=player, state=state, dt=0.5);
    assert shub.visual.first != shub.visual.second or shub.animation_time > 0.0;
    assert telefrag(world, player, Vec3(x=-700.0, y=2000.0, z=120.0), 22.0);
    finale = [world->:HasFinale:->][?:Finale][0];
    assert shub.boss_phase == 1 and finale.camera and not finale.text;
    saved = snapshot(world, level, player, state);
    for i in range(7) {
        world spawn FinaleTick(player=player, state=state, dt=0.5);
    }
    assert shub.boss_phase == 2 and shub.visual.visible;
    for i in range(13) {
        world spawn FinaleTick(player=player, state=state, dt=0.5);
    }
    assert shub.boss_phase == 3 and not shub.visual.visible and state.kills == 1;
    assert finale.text == SHUB_TEXT;
    finale.text = "";
    finale.camera = False;
    restore(world, level, player, state, saved);
    assert shub.boss_phase == 1 and finale.camera and not finale.text;
    assert shub.visual.visible;
}

test "teleport train position survives a save" {
    world = World();
    level = Level(name="loop");
    level.bsp.game = "q1";
    train = circuit(world);
    player = Player();
    state = CombatState(game="q1");
    for i in range(30) {
        world spawn TeleportTrainTick(dt=0.01);
    }
    saved = snapshot(world, level, player, state);
    for i in range(30) {
        world spawn TeleportTrainTick(dt=0.01);
    }
    assert abs(train.pos.x - 100.0) < 0.001;
    restore(world, level, player, state, saved);
    assert abs(train.pos.x - 60.0) < 0.001 and train.current.entity == 1;
    assert train.destination is not None and train.destination.entity == 2;
}

test "episode exits carry their closing texts and cinematic exits are skipped" {
    assert episode_text("q1", "e1m7", "start");
    assert episode_text("q1", "e2m6", "start");
    assert episode_text("q1", "e3m6", "start");
    assert episode_text("q1", "e4m7", "start");
    assert not episode_text("q1", "e1m2", "e1m3");
    assert not episode_text("q2", "e1m7", "start");
    assert exit_map("eou1_.cin+*bunk1$start") == "bunk1";
    assert exit_spawn("eou1_.cin+*bunk1$start") == "start";
    assert exit_cinematic("eou1_.cin+*bunk1$start") == "eou1_";
    assert exit_map("end.cin+victory.pcx") == "victory.pcx";
    assert exit_cinematic("base2$base1") == "";
    assert exit_map("*bunk1") == "bunk1";
    failed = False;
    try {
        exit_map("../evil");
    } except ValueError {
        failed = True;
    }
    assert failed;
}

test "intermission camera reads the authored mangle" {
    level = Level(name="camera");
    level.bsp.entities = [
        MapEntity(fields={"classname": "worldspawn"}),
        MapEntity(
            fields={
                "classname": "info_intermission",
                "origin": "-784 1656 56",
                "mangle": "-30 90 0"
            }
        )
    ];
    view = intermission_camera(level.bsp);
    assert view.found and view.origin.x == -784.0 and view.origin.z == 56.0;
    assert abs(view.yaw - 1.5707963) < 0.0001 and view.pitch > 0.5;
    assert not intermission_camera(Level(name="empty").bsp).found;
}

test "teleport train movement is independent of tick subdivision across corners" {
    whole = World();
    split = World();
    first = circuit(whole);
    second = circuit(split);
    whole spawn TeleportTrainTick(dt=5.125);
    for i in range(5125) {
        split spawn TeleportTrainTick(dt=0.001);
    }
    assert first.pos.sub(second.pos).length() < 0.00001;
    assert first.current.entity == second.current.entity;
    assert abs(first.yaw - second.yaw) < 0.00001;
}

test "coincident teleport corners advance safely and zero length loops terminate" {
    world = World();
    a = TrackPoint(entity=1, name="a", origin=Vec3());
    b = TrackPoint(entity=2, name="b", origin=Vec3());
    c = TrackPoint(entity=3, name="c", origin=Vec3(x=100.0));
    a +>:TrackNext:+> b;
    b +>:TrackNext:+> c;
    train = TeleportTrain(entity=1, current=a, speed=100.0);
    world +>:HasTeleportTrain:+> train;
    world spawn TeleportTrainTick(dt=0.5);
    assert abs(train.pos.x - 50.0) < 0.00001;
    train.current = a;
    train.destination = None;
    train.pos = Vec3();
    b del --> c;
    b +>:TrackNext:+> a;
    world spawn TeleportTrainTick(dt=1.0);
    assert train.pos.length() == 0.0;
}
