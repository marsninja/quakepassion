import from engine.core.savegame { snapshot, restore, values }
import from engine.world.world { World, Player }
import from engine.world.level { Level }
import from engine.world.combat { Opponent, HasOpponent, CombatState }
import from engine.world.inventory { AdjustInventory, quantity }
import from engine.math.vec3 { Vec3 }

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
