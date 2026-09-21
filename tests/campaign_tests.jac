import from engine.world.signals { Signal, HasSignal, Targets, Fire }
import from engine.world.inventory { Inventory, AdjustInventory, quantity }
import from engine.world.world { Player }
import from engine.world.doors { Door, HasDoor, DoorTick, load_doors }
import from engine.formats.bsp { MapEntity }
import from engine.math.vec3 { Vec3 }
import from engine.core.savegame { snapshot, restore }
import from engine.world.level { Level }
import from engine.world.combat { CombatState }
import from games.items { pickup_rule }
import from tests.door_support { DoorFixture }

test "key gates consume a key once and counters persist partial progress" {
    inventory = Inventory();
    gate = Signal(relay=True, key="key_data_cd", once=True);
    counter = Signal(relay=True, remaining=2, once=True);
    destination = Signal();
    gate +>:Targets:+> counter;
    counter +>:Targets:+> destination;
    gate spawn Fire(emit=False, inventory=inventory);
    assert gate.enabled and counter.remaining == 2;
    inventory spawn AdjustInventory(kind="key_data_cd", amount=1);
    gate spawn Fire(emit=False, inventory=inventory);
    assert not gate.enabled and quantity(inventory, "key_data_cd") == 0;
    assert counter.remaining == 1 and destination.pending == 0;
    world = World();
    world +>:HasSignal:+> gate;
    world +>:HasSignal:+> counter;
    world +>:HasSignal:+> destination;
    level = Level();
    player = Player(inventory=inventory);
    data = snapshot(world, level, player, CombatState());
    counter.remaining = 99;
    gate.enabled = True;
    restore(world, level, player, CombatState(), data);
    assert counter.remaining == 1 and not gate.enabled;
    gate spawn Fire(emit=False, inventory=inventory);
    assert counter.remaining == 1;
    counter spawn Fire(emit=False, inventory=inventory);
    assert destination.pending == 1 and not counter.enabled;
}

test "Q1 key door consumes the correct key and saves its unlock" {
    fixture = DoorFixture();
    fixture.setup("q1", {"spawnflags": "8"});
    door = [fixture.world->:HasDoor:->][?:Door][0];
    player = Player(pos=Vec3(x=60.0, z=24.0));
    player.inventory spawn AdjustInventory(kind="key_silver", amount=1);
    fixture.world spawn DoorTick(bsp=fixture.bsp, collision=fixture.collision,
        player_origin=player.pos, player=player, dt=0.05);
    assert door.position == 0.0 and not door.unlocked;
    player.inventory spawn AdjustInventory(kind="key_gold", amount=1);
    fixture.world spawn DoorTick(bsp=fixture.bsp, collision=fixture.collision,
        player_origin=player.pos, player=player, dt=0.05);
    assert door.unlocked and door.position > 0.0;
    assert quantity(player.inventory, "key_gold") == 0;
    assert quantity(player.inventory, "key_silver") == 1;
    level = Level(bsp=fixture.bsp, collision=fixture.collision);
    data = snapshot(fixture.world, level, player, CombatState());
    door.unlocked = False;
    restore(fixture.world, level, player, CombatState(), data);
    assert door.unlocked and door.hold_time < 0.0;
}

test "campaign item adapters choose original key models" {
    silver = pickup_rule("q1", {"classname": "item_key1"}, 2);
    assert silver is not None and silver.model == "progs/b_s_key.mdl";
    gold = pickup_rule("q1", {"classname": "item_key2"}, 1);
    assert gold is not None and gold.kind == "key_gold";
    cube = pickup_rule("q2", {"classname": "key_power_cube"});
    assert cube is not None and cube.capacity == 8;
}

test "authored Q2 key and counter chain unlocks its named door" {
    fixture = DoorFixture();
    fixture.setup("q2", {"targetname": "door"});
    fixture.world = World();
    fixture.bsp.entities.append(MapEntity(fields={
        "classname": "trigger_key", "targetname": "key_gate",
        "item": "key_data_cd", "target": "objective"
    }));
    fixture.bsp.entities.append(MapEntity(fields={
        "classname": "trigger_counter", "targetname": "objective",
        "count": "1", "target": "door"
    }));
    load_doors(fixture.world, fixture.bsp, fixture.collision);
    gate = [signal for signal in [fixture.world->:HasSignal:->][?:Signal] if signal.key][0];
    door = [fixture.world->:HasDoor:->][?:Door][0];
    player = Player(pos=Vec3(x=200.0));
    gate spawn Fire(emit=False, inventory=player.inventory);
    assert door.activation.pending == 0;
    player.inventory spawn AdjustInventory(kind="key_data_cd", amount=1);
    gate spawn Fire(emit=False, inventory=player.inventory);
    assert door.activation.pending == 1;
    fixture.tick(player.pos);
    assert door.position > 0.0 and quantity(player.inventory, "key_data_cd") == 0;
}

import from engine.core.campaign { Campaign, Remember, Recall, Visited, MapState, pack_campaign, unpack_campaign }
import from engine.world.world { World }

test "hub replaces visited snapshots and envelopes round trip without ambiguity" {
    campaign = Campaign();
    level = Level();
    level.bsp.game = "q2";
    level.name = "base1";
    data = snapshot(World(), level, Player(), CombatState());
    campaign spawn Remember(name="base1", data=data);
    campaign spawn Remember(name="base1", data=data);
    assert len([campaign->:Visited:->][?:MapState]) == 1;
    saved = unpack_campaign(pack_campaign(campaign, data));
    assert saved.active == data;
    recalled = saved spawn Recall(name="base1");
    assert recalled.data == data;
    rejected = False;
    try { unpack_campaign(pack_campaign(campaign, data) + "garbage\n"); }
    except ValueError { rejected = True; }
    assert rejected;
}
