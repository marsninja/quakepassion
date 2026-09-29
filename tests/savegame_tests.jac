import from engine.core.savegame { snapshot, restore, values }
import from engine.world.world { World, Player }
import from engine.world.level { Level, BspArea }
import from engine.world.combat { Opponent, HasOpponent, CombatState }
import from engine.world.inventory { AdjustInventory, quantity }
import from engine.world.pickups { Pickup, PickupRule, HasPickup }
import from engine.world.drops { Flight, HasFlight, Carries, let_fall, end_flight }
import from engine.formats.bsp { Bsp, Model }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }

test "snapshots round trip player inventory and opponent state" {
    world = World();
    level = Level();
    level.name = "test";
    enemy = Opponent(health=0, pos=Vec3(x=40.0));
    world +>:HasOpponent:+> enemy;
    player = Player(
        pos=Vec3(x=10.0, z=100.0), health=50, armor=25, velocity=Vec3(x=2.0)
    );
    player.inventory spawn AdjustInventory(kind="shells", amount=7, capacity=100);
    combat = CombatState(kills=3, weapon=2);
    data = snapshot(world, level, player, combat);
    player.health = 1;
    player.pos = Vec3();
    enemy.health = 60;
    combat.kills = 0;
    restore(world, level, player, combat, data);
    assert player.health == 50 and player.armor == 25 and player.pos.z == 100.0;
    assert player.velocity.x == 2.0 and quantity(player.inventory, "shells") == 7;
    assert enemy.health == 0 and not enemy.visual.visible;
    assert combat.kills == 3 and combat.weapon == 2;
}

test "snapshots reject mismatched versions maps and incomplete graph records" {
    world = World();
    level = Level();
    player = Player();
    combat = CombatState();
    data = snapshot(world, level, player, combat);
    world +>:HasOpponent:+> Opponent();
    rejected = False;
    try {
        restore(world, level, player, combat, data);
    } except ValueError {
        rejected = True;
    }
    assert rejected;
    for invalid in ["QUAKEPASSION 0\nq1\ntest\n0", "QUAKEPASSION 1\nq2\nwrong\n0"] {
        rejected = False;
        try {
            restore(world, level, player, combat, invalid);
        } except ValueError {
            rejected = True;
        }
        assert rejected;
    }
    rejected = False;
    try {
        values("nan", 1);
    } except ValueError {
        rejected = True;
    }
    assert rejected;
}

test "a level's clock is kept in its saves" {
    world = World();
    level = Level();
    level.name = "test";
    level.clock = 83.25;
    player = Player();
    combat = CombatState();
    data = snapshot(world, level, player, combat);
    level.clock = 0.0;
    restore(world, level, player, combat, data);
    assert level.clock == 83.25;
}

def fall_world() -> World {
    world = World();
    for spot in [Vec3(z=15.0), Vec3(x=100.0, z=300.0)] {
        world +>:HasPickup:+> Pickup(
            rule=PickupRule(kind="shells", amount=10, capacity=100, model=""), pos=spot
        );
    }
    # The second hangs with no floor within 128 (Q2 droptofloor) and falls.
    let_fall(world, [world->:HasPickup:->][?:Pickup][1]);
    return world;
}

test "a falling item and where items have ridden to survive a save" {
    bsp = Bsp(game="q2", models=[Model(head=-1, first_face=0, face_count=0, vis_leaf_count=1)]);
    level = Level(bsp=bsp, areas=[BspArea(name="0", bounds=AABB(mins=Vec3(), maxs=Vec3()))]);
    level.name = "fall";
    world = fall_world();
    items = [world->:HasPickup:->][?:Pickup];
    # A lift has carried the first up; the second is part way down.
    items[0].pos.z = 79.0;
    items[1].pos.z = 280.0;
    [world->:HasFlight:->][?:Flight][0].velocity = Vec3(z=-240.0);
    saved = snapshot(world, level, Player(), CombatState());
    assert "FALL 1 0.0 0.0 -240.0" in saved;
    # Loading the level afresh starts the fall over; the save takes up from
    # where it was.
    fresh = fall_world();
    restore(fresh, level, Player(), CombatState(), saved);
    placed = [fresh->:HasPickup:->][?:Pickup];
    flights = [fresh->:HasFlight:->][?:Flight];
    assert len(flights) == 1 and flights[0].velocity.z == -240.0;
    assert [flights[0]->:Carries:->][?:Pickup][0] is placed[1];
    assert placed[1].pos.z == 280.0 and placed[0].pos.z == 79.0;
    # A landed item stays landed.
    for flight in flights {
        end_flight(fresh, flight);
    }
    placed[1].pos.z = 15.0;
    landed = snapshot(fresh, level, Player(), CombatState());
    assert "FALL" not in landed;
    again = fall_world();
    restore(again, level, Player(), CombatState(), landed);
    assert not [again->:HasFlight:->] and [again->:HasPickup:->][?:Pickup][1].pos.z == 15.0;
}
