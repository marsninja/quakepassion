import from engine.world.signals { Signal, Targets, Fire, HasSignal, SignalTick }
import from engine.world.world { World, Player }
import from engine.world.inventory { AdjustInventory }
import from engine.world.level { Level }
import from engine.world.combat { CombatState }
import from engine.core.savegame { snapshot, restore }
import from tests.door_support { DoorFixture }
import from engine.formats.bsp { MapEntity }
import from engine.world.doors { load_doors, Door, HasDoor }

test "activation relays fan out once through cycles" {
    source = Signal();
    relay = Signal(relay=True);
    other = Signal(relay=True);
    destination = Signal();
    source +>:Targets:+> relay;
    relay +>:Targets:+> other;
    other +>:Targets:+> relay;
    relay +>:Targets:+> destination;
    other +>:Targets:+> destination;
    source spawn Fire();
    assert destination.pending == 1;
    source spawn Fire();
    assert destination.pending == 2;
}

test "independent delayed uses retain each activation and activator inventory" {
    world = World();
    relay = Signal(relay=True, delay=1.0);
    gate = Signal(relay=True, key="key_data_cd", once=True);
    sink = Signal();
    player = Player();
    player.inventory spawn AdjustInventory(kind="key_data_cd", amount=1);
    world +>:HasSignal:+> relay;
    relay +>:Targets:+> gate;
    gate +>:Targets:+> sink;
    relay spawn Fire(emit=False, inventory=player.inventory);
    world spawn SignalTick(dt=0.5);
    assert sink.pending == 0 and len(relay.queued) == 1;
    relay spawn Fire(emit=False, inventory=player.inventory);
    assert len(relay.queued) == 2;
    world spawn SignalTick(dt=0.5);
    assert sink.pending == 1 and len(relay.queued) == 1;
    world spawn SignalTick(dt=0.5);
    assert sink.pending == 1 and len(relay.queued) == 0;
}

test "Q3 delay resets its timer while Q1 Q2 delayed relays queue uses" {
    for replace in [False, True] {
        world = World();
        relay = Signal(relay=True, delay=1.0, replace_pending=replace);
        sink = Signal();
        world +>:HasSignal:+> relay;
        relay +>:Targets:+> sink;
        relay spawn Fire(emit=False);
        world spawn SignalTick(dt=0.75);
        relay spawn Fire(emit=False);
        world spawn SignalTick(dt=0.25);
        assert sink.pending == (0 if replace else 1);
        world spawn SignalTick(dt=0.75);
        assert sink.pending == (1 if replace else 2);
    }
}

test "delayed chains are independent of world registration order" {
    for reverse in [False, True] {
        world = World();
        first = Signal(relay=True, delay=0.5);
        second = Signal(relay=True, delay=0.5);
        sink = Signal();
        world +>:HasSignal:+> (second if reverse else first);
        world +>:HasSignal:+> (first if reverse else second);
        first +>:Targets:+> second;
        second +>:Targets:+> sink;
        first spawn Fire(emit=False);
        world spawn SignalTick(dt=0.5);
        assert sink.pending == 0 and len(second.queued) == 1;
        world spawn SignalTick(dt=0.5);
        assert sink.pending == 1;
    }
}

test "one shot delayed relay still delivers after disabling itself" {
    world = World();
    relay = Signal(relay=True, delay=0.5, once=True);
    sink = Signal();
    world +>:HasSignal:+> relay;
    relay +>:Targets:+> sink;
    relay spawn Fire(emit=False);
    relay spawn Fire(emit=False);
    assert not relay.enabled and len(relay.queued) == 1;
    world spawn SignalTick(dt=0.5);
    assert sink.pending == 1;
}

test "saved delayed activations retain time and inventory across restoration" {
    world = World();
    relay = Signal(relay=True, delay=1.0, variance=0.25, random_state=123);
    sink = Signal();
    player = Player();
    world +>:HasSignal:+> relay;
    world +>:HasSignal:+> sink;
    relay +>:Targets:+> sink;
    relay spawn Fire(emit=False, inventory=player.inventory);
    world spawn SignalTick(dt=0.25);
    remaining = relay.queued[0].remaining;
    state = relay.random_state;
    level = Level(name="fixture");
    data = snapshot(world, level, player, CombatState());
    world spawn SignalTick(dt=2.0);
    restore(world, level, player, CombatState(), data);
    assert sink.pending == 0 and len(relay.queued) == 1;
    assert relay.queued[0].remaining == remaining and relay.random_state == state;
    assert relay.queued[0].inventory is player.inventory;
    world spawn SignalTick(dt=remaining);
    assert sink.pending == 1;
}

test "authored startup triggers deliver after game specific startup delays" {
    for game in ["q2", "q3"] {
        fixture = DoorFixture();
        fixture.setup(game, {"targetname": "gate"});
        fixture.world = World();
        fixture.bsp.entities.append(
            MapEntity(fields={"classname": "trigger_always", "target": "gate"})
        );
        load_doors(fixture.world, fixture.bsp, fixture.collision);
        door = [fixture.world->:HasDoor:->][?:Door][0];
        fixture.world spawn SignalTick(dt=0.1);
        assert door.activation.pending == 0;
        fixture.world spawn SignalTick(dt=0.10001);
        assert door.activation.pending == (0 if game == "q3" else 1);
        fixture.world spawn SignalTick(dt=0.1);
        assert door.activation.pending == 1;
        fixture.world spawn SignalTick(dt=1.0);
        assert door.activation.pending == 1;
    }
}

test "timers toggle immediately and preserve remaining intervals on save load" {
    world = World();
    timer = Signal(interval=0.5);
    sink = Signal();
    player = Player();
    world +>:HasSignal:+> timer;
    world +>:HasSignal:+> sink;
    timer +>:Targets:+> sink;
    timer spawn Fire(emit=False, inventory=player.inventory);
    assert sink.pending == 1 and timer.timer_running;
    world spawn SignalTick(dt=0.25);
    assert sink.pending == 1;
    level = Level(name="fixture");
    data = snapshot(world, level, player, CombatState());
    world spawn SignalTick(dt=0.25);
    assert sink.pending == 2;
    restore(world, level, player, CombatState(), data);
    assert sink.pending == 1 and timer.timer_remaining == 0.25;
    world spawn SignalTick(dt=0.25);
    assert sink.pending == 2;
    timer spawn Fire(emit=False);
    world spawn SignalTick(dt=5.0);
    assert not timer.timer_running and sink.pending == 2;
    timer spawn Fire(emit=False);
    assert timer.timer_running and sink.pending == 3;
}

test "authored timers use game startup timing and deterministic bounded variance" {
    for game in ["q2", "q3"] {
        fixture = DoorFixture();
        fixture.setup(game, {"targetname": "gate"});
        fixture.world = World();
        fixture.bsp.entities.append(
            MapEntity(
                fields={
                    "classname": "func_timer",
                    "target": "gate",
                    "spawnflags": "1",
                    "wait": "1",
                    "random": "0"
                }
            )
        );
        load_doors(fixture.world, fixture.bsp, fixture.collision);
        door = [fixture.world->:HasDoor:->][?:Door][0];
        fixture.world spawn SignalTick(dt=0.1);
        assert door.activation.pending == (1 if game == "q3" else 0);
        fixture.world spawn SignalTick(dt=1.9);
        assert door.activation.pending == (2 if game == "q3" else 1);
    }
    a = Signal(interval=1.0, variance=0.25, random_state=121);
    b = Signal(interval=1.0, variance=0.25, random_state=121);
    for i in range(32) {
        interval = a.sample(a.interval);
        assert interval >= 0.75
            and interval <= 1.25
            and interval == b.sample(b.interval);
    }
}
