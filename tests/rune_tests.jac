import from games.items { pickup_rule }
import from engine.world.world { World, Player }
import from engine.world.pickups { Pickup, HasPickup, PickupTick }
import from engine.world.inventory { quantity, AdjustInventory, CopyInventory }
import from engine.world.gates {
    load_gates,
    ApplyGates,
    HasGate,
    CampaignGate,
    rune_summary
}
import from engine.world.signals { Signal, Targets }
import from engine.world.level { Level }
import from engine.world.combat { CombatState }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }
import from tests.door_support { DoorFixture }

test "sigils union their flags, emit targets, and survive key clearing" {
    world = World();
    player = Player();
    sink = Signal();
    for flags in [1, 2, 2, 12] {
        rule = pickup_rule("q1", {"classname": "item_sigil", "spawnflags": str(flags)});
        assert rule is not None;
        item = Pickup(rule=rule);
        item.activation +>:Targets:+> sink;
        world +>:HasPickup:+> item;
        world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=0.1);
        assert not item.active;
    }
    assert quantity(player.inventory, "runes") == 15 and sink.pending == 4;
    player.inventory spawn AdjustInventory(kind="key_gold", amount=1);
    copy = player.inventory spawn CopyInventory(skip_keys=True);
    assert quantity(copy.result, "runes") == 15
        and quantity(copy.result, "key_gold") == 0;
    assert rune_summary(copy.result) == "Runes: 1, 2, 3, 4";
}

test "episode and boss gates derive collision and visibility from saved runes" {
    for kind in ["func_episodegate", "func_bossgate"] {
        f = DoorFixture();
        f.setup("q1", {"classname": kind, "spawnflags": "1"});
        load_gates(f.world, f.bsp, f.collision);
        gates = [f.world->:HasGate:->][?:CampaignGate];
        assert len(gates) == 1 and len(gates[0].hulls) == 1;
        assert f.bsp.faces[0].hidden == (kind == "func_episodegate");
        assert (0 in f.collision.disabled) == (kind == "func_episodegate");
        player = Player();
        player.inventory spawn AdjustInventory(kind="runes", amount=15, capacity=15);
        f.world spawn ApplyGates(
            inventory=player.inventory, bsp=f.bsp, collision=f.collision
        );
        assert f.bsp.faces[0].hidden == (kind == "func_bossgate");
        level = Level(bsp=f.bsp, collision=f.collision, name="start");
        combat = CombatState();
        saved = snapshot(f.world, level, player, combat);
        player.inventory spawn AdjustInventory(kind="runes", amount=-15);
        f.world spawn ApplyGates(
            inventory=player.inventory, bsp=f.bsp, collision=f.collision
        );
        restore(f.world, level, player, combat, saved);
        assert f.bsp.faces[0].hidden == (kind == "func_bossgate");
        assert f.collision.trace(Vec3(z=24.0), Vec3(z=24.0)).start_solid
            == (kind == "func_episodegate");
    }
}

test "partial rune sets keep the final gate closed and only close matching episodes" {
    f = DoorFixture();
    f.setup("q1", {"classname": "func_episodegate", "spawnflags": "2"});
    load_gates(f.world, f.bsp, f.collision);
    player = Player();
    player.inventory spawn AdjustInventory(kind="runes", amount=1, capacity=15);
    f.world spawn ApplyGates(
        inventory=player.inventory, bsp=f.bsp, collision=f.collision
    );
    assert f.bsp.faces[0].hidden;
    gate = [f.world->:HasGate:->][?:CampaignGate][0];
    gate.boss = True;
    f.world spawn ApplyGates(
        inventory=player.inventory, bsp=f.bsp, collision=f.collision
    );
    assert not f.bsp.faces[0].hidden;
}
