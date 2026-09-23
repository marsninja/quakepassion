import from engine.world.world { World, Player }
import from engine.world.combat { CombatState, Opponent, HasOpponent }
import from engine.world.targets { TargetEvent, HasTarget, TargetTick }
import from engine.world.signals { Signal }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "a used killbox telefrags everything inside it and nothing outside" {
    world = World();
    collision = CollisionMap();
    box = TargetEvent(kind="killbox", mins=Vec3(x=-64.0, y=-64.0, z=-64.0), maxs=Vec3(x=64.0, y=64.0, z=64.0), activation=Signal(entities=[1]));
    world +>:HasTarget:+> box;
    player = Player(health=100, pos=Vec3(z=collision.eye_height));
    inside = Opponent(health=300, pos=Vec3(x=40.0, z=22.0));
    outside = Opponent(health=300, pos=Vec3(x=400.0, z=22.0));
    world +>:HasOpponent:+> inside;
    world +>:HasOpponent:+> outside;
    world spawn TargetTick(player=player, collision=collision, state=CombatState(), dt=0.01);
    assert player.health == 100 and inside.health == 300;
    box.activation.pending = 1;
    world spawn TargetTick(player=player, collision=collision, state=CombatState(), dt=0.01);
    assert player.health == 0 and inside.health == 0 and outside.health == 300;
}
