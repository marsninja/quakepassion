"""Campaign level flow on the original maps, headless: the exits that used to be
dropped load and fire (Q1 e1m7; Q2 jail1, base2, boss1), Q2 elevators answer
their buttons (lab, mine2) and Q1 closet monsters teleport in when their
chain fires (e1m3 fiends, then the shambler their counter calls)."""
import from engine.core.menu { game_directory }
import from engine.world.level { Level, load_level }
import from engine.world.world { World, Player }
import from engine.world.exits { LevelExit, HasExit, ExitTick }
import from engine.world.signals { Signal, HasSignal, Fire, SignalTick }
import from engine.world.trains { Train, HasTrain, TrainTick }
import from engine.world.doors { DoorTick }
import from engine.world.targets { TargetTick }
import from engine.world.particles { ImpactParticle, HasParticle }
import from engine.world.traversal { TraversalTick, TeleportMonsters }
import from engine.world.combat { Opponent, HasOpponent, CombatState, damage_opponent }
import from games.opponents { populate_opponents }
import from engine.math.vec3 { Vec3 }

def signal_for(world: World, level: Level, match_fields: dict[str, str]) -> Signal {
    for index in range(len(level.bsp.entities)) {
        fields = level.bsp.entities[index].fields;
        if all([fields.get(key, "") == value for (key, value) in match_fields.items()]) {
            for signal in [world->:HasSignal:->][?:Signal] {
                if index in signal.entities {
                    return signal;
                }
            }
        }
    }
    raise ValueError("No signal for " + str(match_fields));
}

"""Advance signals, movers and teleporters as the game loop does."""
def run(world: World, level: Level, player: Player, seconds: float) {
    dt = 1.0 / 60.0;
    for i in range(int(seconds / dt)) {
        world spawn SignalTick(dt=dt, inventory=player.inventory);
        world spawn TrainTick(bsp=level.bsp, collision=level.collision, dt=dt);
        world spawn DoorTick(
            bsp=level.bsp,
            collision=level.collision,
            player_origin=player.pos,
            dt=dt,
            touching=False
        );
        world spawn TraversalTick(
            player=player, collision=level.collision, start=player.pos, dt=dt, touching=False
        );
        world spawn TeleportMonsters(collision=level.collision, dt=dt, player=player);
    }
}

def nearest_monster(fiends: list[Opponent], origin: Vec3) -> Opponent {
    best = fiends[0];
    for enemy in fiends {
        if enemy.pos.sub(origin).length() < best.pos.sub(origin).length() {
            best = enemy;
        }
    }
    return best;
}

def exit_request(world: World) -> str {
    hit = world spawn ExitTick(start=Vec3(), finish=Vec3(), dt=0.01);
    return hit.request;
}

def open_map(game: str, name: str, skill: int = 1) -> tuple[World, Level, Player] {
    world = World();
    level = load_level(world, game_directory(game), name, game, skill);
    return (world, level, Player(pos=Vec3(z=-100000.0), health=100));
}

with entry {
    # Q1 e1m7: the exit fires its relay t18 and asks for start.
    (world, level, player) = open_map("q1", "e1m7");
    exits = [world->:HasExit:->][?:LevelExit];
    assert len(exits) == 1 and exits[0].destination == "start";
    box = exits[0].volume.bounds[0];
    centre = box.mins.lerp(box.maxs, 0.5);
    relay = signal_for(world, level, {"targetname": "t18"});
    touched = world spawn ExitTick(start=centre, finish=centre, dt=0.01, inventory=player.inventory);
    assert touched.request == "start" and touched.intermission;
    print("FLOW e1m7 exit", touched.request, "relay t18 fired", relay.enabled);

    # Q2 jail1: its only exit is reached through trigger_multiple -> t60.
    (world, level, player) = open_map("q2", "jail1");
    signal_for(world, level, {"target": "t60", "classname": "trigger_multiple"}) spawn Fire(emit=False);
    request = exit_request(world);
    assert request == "jail2$jail1";
    print("FLOW jail1 exit", request);

    # Q2 base2: the end of unit 1 waits for its relay's one second delay.
    (world, level, player) = open_map("q2", "base2");
    signal_for(world, level, {"targetname": "t4", "classname": "trigger_relay"}) spawn Fire(emit=False);
    assert not exit_request(world);
    run(world, level, player, 1.2);
    request = exit_request(world);
    assert request == "eou1_.cin+*bunk1$start";
    print("FLOW base2 exit", request);

    # Q2 boss1: the TRIGGERED trigger_once is armed by t118, then touched; its
    # relay leaves after a second and the teleport effect plays.
    (world, level, player) = open_map("q2", "boss1");
    gate = signal_for(world, level, {"target": "t158", "classname": "trigger_once"});
    gate spawn Fire(emit=False);
    gate spawn Fire(emit=False);
    world spawn TargetTick(
        player=player, collision=level.collision, state=CombatState(game="q2"), dt=0.01
    );
    sparks = len([world->:HasParticle:->][?:ImpactParticle]);
    assert sparks > 0;
    run(world, level, player, 1.2);
    request = exit_request(world);
    assert request == "boss2$start";
    print("FLOW boss1 exit", request, "teleport sparks", sparks);

    # Q2 lab and mine2: buttons call their elevators to the pathtarget corner.
    for scenario in [("lab", "e1", "t340"), ("mine2", "p3", "t14")] {
        (world, level, player) = open_map("q2", scenario[0]);
        lift: Train | None = None;
        for train in [world->:HasTrain:->][?:Train] {
            if level.bsp.entities[train.activation.entities[0]].fields.get("targetname", "") == scenario[2] {
                lift = train;
            }
        }
        assert lift is not None;
        start = lift.current.name;
        button = signal_for(world, level, {"classname": "func_button", "pathtarget": scenario[1]});
        button.pending += 1;
        run(world, level, player, 8.0);
        assert lift.current.name == scenario[1] and not lift.running;
        print("FLOW", scenario[0], "elevator", start, "->", lift.current.name, "motion", lift.motion.z);
    }

    # Q1 e1m3: killing the fiend that targets t174 opens the teleporter its
    # closet fiend waits in; both closet fiends feed counter t175, whose
    # shambler then teleports in too. The closets exist on hard skill.
    (world, level, player) = open_map("q1", "e1m3", 2);
    populate_opponents(world, level, game_directory("q1"));
    player.pos = Vec3(x=1300.0, y=600.0, z=600.0);
    fiends = [world->:HasOpponent:->][?:Opponent];
    guards = [
        nearest_monster(fiends, Vec3(x=1288.0, y=920.0, z=584.0)),
        nearest_monster(fiends, Vec3(x=1408.0, y=920.0, z=584.0))
    ];
    closet = [
        nearest_monster(fiends, Vec3(x=1392.0, y=1272.0, z=584.0)),
        nearest_monster(fiends, Vec3(x=1496.0, y=1272.0, z=584.0))
    ];
    shambler = nearest_monster(fiends, Vec3(x=1288.0, y=1288.0, z=584.0));
    state = CombatState(game="q1");
    for guard in guards {
        damage_opponent(guard, 10000, player.inventory, state);
    }
    run(world, level, player, 0.5);
    assert closet[0] is not closet[1];
    for fiend in closet {
        assert fiend.pos.y < 1000.0;
        print("FLOW e1m3 fiend arrived at", int(fiend.pos.x), int(fiend.pos.y), int(fiend.pos.z));
    }
    assert shambler.pos.y > 1200.0;
    for fiend in closet {
        damage_opponent(fiend, 10000, player.inventory, state);
    }
    run(world, level, player, 0.5);
    assert shambler.pos.y < 1000.0;
    print("FLOW e1m3 shambler arrived at", int(shambler.pos.x), int(shambler.pos.y), int(shambler.pos.z));
    print("CAMPAIGN FLOW SMOKE PASS");
}
