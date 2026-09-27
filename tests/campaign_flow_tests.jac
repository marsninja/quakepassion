"""Campaign level flow: activation chains that skip unsupported targets, exits
with their own targets, Q2 elevators, monster teleporters and pushes, removable
walls, and the messages and sounds of doors and keys."""
import from engine.world.doors {
    Door,
    HasDoor,
    DoorTick,
    load_doors,
    connect_targets,
    key_text,
    mover_voices
}
import from engine.world.exits { LevelExit, HasExit, ExitTick, load_exits }
import from engine.world.triggers { load_triggers, TouchTrigger, HasTrigger }
import from engine.world.trains { Train, HasTrain, TrainTick, load_trains }
import from engine.world.brushes { BrushObject, HasBrush, BrushTick, load_brushes }
import from engine.world.traversal {
    Traversal,
    Destination,
    HasTraversal,
    ArrivesAt,
    TraversalTick,
    TeleportMonsters
}
import from engine.world.signals { Signal, HasSignal, Targets, Fire, chain_notes }
import from engine.world.combat { Opponent, HasOpponent, CombatState }
import from engine.world.world { World, Player }
import from engine.world.inventory { AdjustInventory, quantity }
import from engine.physics.collision { CollisionMap }
import from engine.formats.bsp { MapEntity, Model, Face }
import from engine.math.vec3 { Vec3 }
import from tests.door_support { DoorFixture }
import from tests.trigger_support { trigger_fixture, touch }


def flow_box(center: Vec3 = Vec3()) -> CollisionMap {
    volume = CollisionMap();
    volume.add_brush(
        [
            Vec3(x=1.0),
            Vec3(x=-1.0),
            Vec3(y=1.0),
            Vec3(y=-1.0),
            Vec3(z=1.0),
            Vec3(z=-1.0)
        ],
        [8.0, 8.0, 8.0, 8.0, 8.0, 8.0],
        Vec3(),
        Vec3(),
        center
    );
    volume.reindex();
    return volume;
}

def signal_of(world: World, index: int) -> Signal {
    for signal in [world->:HasSignal:->][?:Signal] {
        if index in signal.entities {
            return signal;
        }
    }
    raise ValueError("no signal for entity " + str(index));
}

test "chains skip targets without a use and keep firing the rest" {
    for game in ["q1", "q2"] {
        fixture = trigger_fixture(game);
        fixture.world = World();
        # A second recipient of the trigger's target has no use here.
        fixture.bsp.entities.append(
            MapEntity(fields={"classname": "misc_mystery", "targetname": "gate"})
        );
        load_doors(fixture.world, fixture.bsp, fixture.collision);
        relay = signal_of(fixture.world, 1);
        assert relay.enabled;
        door = [fixture.world->:HasDoor:->][?:Door][0];
        assert door.enabled and not door.automatic;
        relay spawn Fire(emit=False);
        fixture.tick(Vec3(x=500.0), 0.01);
        assert door.state == "opening";
        notes = [note for note in chain_notes(fixture.world) if note.entity == 2];
        assert len(notes) == 1 and "misc_mystery" in notes[0].reason;
    }
}

test "Q2 changelevels with targets, delays and flags still load" {
    fixture = trigger_fixture("q2");
    fixture.world = World();
    fixture.bsp.entities[1].fields["target"] = "leave";
    fixture.bsp.entities.append(
        MapEntity(
            fields={
                "classname": "target_changelevel",
                "targetname": "leave",
                "target": "jail1",
                "delay": "2",
                "spawnflags": "1",
                "map": "eou1_.cin+*bunk1$start"
            }
        )
    );
    load_exits(fixture.world, fixture.bsp);
    load_doors(fixture.world, fixture.bsp, fixture.collision);
    load_triggers(fixture.world, fixture.bsp);
    exits = [fixture.world->:HasExit:->][?:LevelExit];
    assert len(exits) == 1;
    touch(fixture, Vec3(x=100.0, z=24.0), Vec3(x=300.0, z=24.0));
    # use_target_changelevel ignores the exit's own delay.
    hit = fixture.world spawn ExitTick(start=Vec3(), finish=Vec3(), dt=0.01);
    assert hit.request == "eou1_.cin+*bunk1$start" and hit.intermission;
}

test "Q1 exits fire their targets when touched and honour NO_INTERMISSION" {
    world = World();
    relay = Signal(relay=True);
    output = Signal();
    relay +>:Targets:+> output;
    exit_signal = Signal(entities=[0]);
    exit_signal +>:Targets:+> relay;
    world +>:HasSignal:+> exit_signal;
    world +>:HasExit:+> LevelExit(
        destination="start", activation=exit_signal, contact=True, volume=flow_box()
    );
    hit = world spawn ExitTick(start=Vec3(x=-20.0), finish=Vec3(x=20.0), dt=0.01);
    assert hit.request == "start" and hit.intermission;
    assert output.pending == 1;
    quiet = World();
    quiet +>:HasExit:+> LevelExit(
        destination="e1m1", contact=True, volume=flow_box(), intermission=False
    );
    direct = quiet spawn ExitTick(start=Vec3(x=-20.0), finish=Vec3(x=20.0), dt=0.01);
    assert direct.request == "e1m1" and not direct.intermission;
}

test "Q2 trigger_elevator sends its idle train to the caller's path corner" {
    fixture = DoorFixture();
    fixture.setup(
        "q2", {"classname": "func_train", "target": "low", "targetname": "lift", "speed": "64"}
    );
    fixture.bsp.entities.extend(
        [
            MapEntity(fields={"classname": "path_corner", "targetname": "low", "origin": "0 0 0", "wait": "-1"}),
            MapEntity(fields={"classname": "path_corner", "targetname": "high", "origin": "0 0 64", "wait": "-1"}),
            MapEntity(fields={"classname": "trigger_elevator", "targetname": "call", "target": "lift"}),
            MapEntity(fields={"classname": "trigger_relay", "targetname": "press", "target": "call", "pathtarget": "high"})
        ]
    );
    load_trains(fixture.world, fixture.bsp, fixture.collision);
    connect_targets(fixture.world, fixture.bsp);
    train = [fixture.world->:HasTrain:->][?:Train][0];
    for i in range(10) {
        fixture.world spawn TrainTick(bsp=fixture.bsp, collision=fixture.collision, dt=0.1);
    }
    assert train.motion.z == 0.0 and not train.running;
    signal_of(fixture.world, 4) spawn Fire(emit=False);
    for i in range(20) {
        fixture.world spawn TrainTick(bsp=fixture.bsp, collision=fixture.collision, dt=0.1);
    }
    assert train.motion.z == 64.0 and not train.running;
    assert train.current.name == "high";
}

test "monsters use named Q1 teleporters just after their use and die on the player" {
    world = World();
    gate = Traversal(volume=flow_box(), kind="teleport", gated=True, monsters=True, game="q1");
    gate +>:ArrivesAt:+> Destination(origin=Vec3(x=500.0), yaw=1.5);
    world +>:HasTraversal:+> gate;
    fiend = Opponent(pos=Vec3(z=22.0), health=100, alert=1.0);
    world +>:HasOpponent:+> fiend;
    far = Player(pos=Vec3(x=-900.0, z=22.0));
    world spawn TeleportMonsters(collision=CollisionMap(), dt=0.01, player=far);
    assert fiend.pos.x == 0.0;
    gate.activation.pending = 1;
    world spawn TraversalTick(
        player=far, collision=CollisionMap(), start=far.pos, dt=0.01, touching=False
    );
    moved = world spawn TeleportMonsters(collision=CollisionMap(), dt=0.01, player=far);
    assert moved.arrivals == 1;
    assert fiend.pos.x == 500.0 and fiend.yaw == 1.5 and fiend.alert == 1.0;
    # A second monster arriving on the player's spot explodes itself.
    other = Opponent(pos=Vec3(z=22.0), health=100);
    world +>:HasOpponent:+> other;
    fiend.pos = Vec3(x=900.0, z=22.0);
    near = Player(pos=Vec3(x=500.0, z=22.0), health=100);
    gate.window = 0.2;
    world spawn TeleportMonsters(collision=CollisionMap(), dt=0.01, player=near);
    assert other.health <= 0 and near.health == 100;
}

test "a fast monster crossing a thin teleporter between ticks still uses it" {
    world = World();
    gate = Traversal(volume=flow_box(), kind="teleport", monsters=True, game="q1");
    gate +>:ArrivesAt:+> Destination(origin=Vec3(y=900.0));
    world +>:HasTraversal:+> gate;
    fiend = Opponent(pos=Vec3(x=-60.0, z=22.0), health=100);
    world +>:HasOpponent:+> fiend;
    world spawn TeleportMonsters(collision=CollisionMap(), dt=0.01);
    assert fiend.pos.x == -60.0;
    # A leap carries it from one side of the 16-unit trigger to the other.
    fiend.pos = Vec3(x=60.0, z=22.0);
    moved = world spawn TeleportMonsters(collision=CollisionMap(), dt=0.01);
    assert moved.arrivals == 1 and fiend.pos.y == 900.0;
    # Placed far away (a respawn or another teleport) is not a sweep.
    runner = Opponent(pos=Vec3(x=-600.0, z=22.0), health=100);
    world +>:HasOpponent:+> runner;
    world spawn TeleportMonsters(collision=CollisionMap(), dt=0.5);
    runner.pos = Vec3(x=600.0, z=22.0);
    placed = world spawn TeleportMonsters(collision=CollisionMap(), dt=0.5);
    assert placed.arrivals == 0 and runner.pos.x == 600.0;
}

test "pushes launch monsters and players-only teleporters ignore them" {
    world = World();
    push = Traversal(volume=flow_box(), kind="push", monsters=True, velocity=Vec3(z=800.0));
    world +>:HasTraversal:+> push;
    only = Traversal(volume=flow_box(Vec3(x=200.0)), kind="teleport", monsters=False);
    only +>:ArrivesAt:+> Destination(origin=Vec3(x=900.0));
    world +>:HasTraversal:+> only;
    grunt = Opponent(pos=Vec3(z=22.0), health=30, grounded=True);
    stay = Opponent(pos=Vec3(x=200.0, z=22.0), health=30);
    world +>:HasOpponent:+> grunt;
    world +>:HasOpponent:+> stay;
    world spawn TeleportMonsters(collision=CollisionMap(), dt=0.01);
    assert grunt.velocity.z == 800.0 and not grunt.grounded;
    assert stay.pos.x == 200.0;
}

test "plain walls keep an identity so killtargets remove them" {
    for game in ["q1", "q2"] {
        fixture = DoorFixture();
        fixture.setup(game, {"classname": "func_wall", "targetname": "block", "spawnflags": "0"});
        fixture.bsp.entities.append(
            MapEntity(fields={"classname": "trigger_relay", "targetname": "open", "killtarget": "block"})
        );
        load_brushes(fixture.world, fixture.bsp, fixture.collision);
        connect_targets(fixture.world, fixture.bsp);
        walls = [fixture.world->:HasBrush:->][?:BrushObject];
        assert len(walls) == 1 and walls[0].active;
        signal_of(fixture.world, 1) spawn Fire(emit=False);
        fixture.world spawn BrushTick(
            bsp=fixture.bsp, collision=fixture.collision, player=Player(), state=CombatState()
        );
        assert walls[0].destroyed and fixture.bsp.faces[0].hidden;
        assert 0 in fixture.collision.disabled;
    }
}

test "door touch messages, key wording and mover sounds follow the originals" {
    fixture = DoorFixture();
    fixture.setup("q1", {"targetname": "far", "message": "This door opens elsewhere..."});
    door = [fixture.world->:HasDoor:->][?:Door][0];
    player = Player(pos=Vec3(x=-20.0, z=46.0), health=100);
    told = fixture.world spawn DoorTick(
        bsp=fixture.bsp,
        collision=fixture.collision,
        player_origin=Vec3(x=-20.0, z=24.0),
        dt=0.01,
        player=player
    );
    assert told.message == "This door opens elsewhere..."
        and told.cues == ["sound/misc/talk.wav"];
    again = fixture.world spawn DoorTick(
        bsp=fixture.bsp,
        collision=fixture.collision,
        player_origin=Vec3(x=-20.0, z=24.0),
        dt=0.01,
        player=player
    );
    assert not again.message;
    door.requested = True;
    door.message_wait = 0.0;
    opened = fixture.world spawn DoorTick(
        bsp=fixture.bsp, collision=fixture.collision, player_origin=Vec3(x=500.0), dt=0.01
    );
    assert door.state == "opening" and not door.touch_message;
    assert key_text("q1", "key_silver", 0) == "You need the silver key";
    assert key_text("q1", "key_gold", 1) == "You need the gold runekey";
    assert key_text("q1", "key_silver", 2) == "You need the silver keycard";
    assert mover_voices("q1", "func_door", {"sounds": "1"})
        == ["", "doors/doormv1.wav", "doors/drclos4.wav"];
    assert mover_voices("q2", "func_door", {})
        == ["doors/dr1_strt.wav", "doors/dr1_mid.wav", "doors/dr1_end.wav"];
    assert mover_voices("q2", "func_door", {"sounds": "1"}) == ["", "", ""];
    assert mover_voices("q1", "func_plat", {})[1] == "plats/medplat1.wav";
    assert mover_voices("q2", "func_button", {})[0] == "switches/butn2.wav";
    # The moving loop runs while the door travels and the stop plays at rest.
    sounding = DoorFixture();
    sounding.setup("q2", {"targetname": "far"});
    mover = [sounding.world->:HasDoor:->][?:Door][0];
    loop = mover.move_voice;
    assert loop is not None;
    mover.requested = True;
    sounding.tick(Vec3(x=500.0), 0.01);
    sounding.tick(Vec3(x=500.0), 0.01);
    start = mover.start_voice;
    assert start is not None and loop.playing and start.requests == 1;
    for i in range(40) {
        sounding.tick(Vec3(x=500.0), 0.05);
    }
    stop = mover.stop_voice;
    assert stop is not None and stop.requests >= 1;
}

test "Q2 trigger_key names the missing item and debounces its message" {
    key = Signal(relay=True, key="key_data_cd", once=True);
    player = Player();
    first = key spawn Fire(emit=False, inventory=player.inventory);
    assert first.message == "You need the Data CD"
        and first.cues == ["sound/misc/keytry.wav"];
    second = key spawn Fire(emit=False, inventory=player.inventory);
    assert not second.message;
    player.inventory spawn AdjustInventory(kind="key_data_cd", amount=1);
    used = key spawn Fire(emit=False, inventory=player.inventory);
    assert "sound/misc/keyuse.wav" in used.cues
        and quantity(player.inventory, "key_data_cd") == 0;
}
