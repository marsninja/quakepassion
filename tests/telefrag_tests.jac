import from engine.physics.collision { CollisionMap }
import from engine.world.world { Player, World }
import from engine.world.combat { Opponent, HasOpponent, CombatState, KillBox }
import from engine.world.arena { SpawnPoint, HasSpawn, ChooseSpawn }
import from engine.world.traversal { Traversal, Destination, ArrivesAt, HasTraversal, TraversalTick }
import from engine.math.vec3 { Vec3 }

test "teleporting onto a monster telefrags it and counts the kill" {
    world = World();
    collision = CollisionMap();
    volume = CollisionMap();
    volume.add_box(Vec3(x=-64.0, y=-64.0, z=-64.0), Vec3(x=64.0, y=64.0, z=64.0), Vec3(), Vec3(), Vec3());
    portal = Traversal(kind="teleport", volume=volume, game="q2");
    portal +>:ArrivesAt:+> Destination(origin=Vec3(x=1000.0, z=24.0), exit_speed=0.0);
    world +>:HasTraversal:+> portal;
    squatter = Opponent(health=400, game="q2", pos=Vec3(x=1020.0, z=46.0));
    neighbour = Opponent(health=400, game="q2", pos=Vec3(x=1040.0, y=40.0, z=46.0));
    world +>:HasOpponent:+> squatter;
    world +>:HasOpponent:+> neighbour;
    player = Player(health=100, pos=Vec3(z=46.0));
    tally = CombatState();
    world spawn TraversalTick(player=player, collision=collision, start=Vec3(z=24.0), dt=0.01, tally=tally);
    assert portal.activations == 1 and player.pos.x == 1000.0;
    # Only boxes that overlap the arrival: 20 units away dies, 40 and 40 lives.
    assert squatter.health <= 0 and neighbour.health == 400;
    assert tally.kills == 1;
}

test "Q3 telefrags hit players and bots only, and teleports avoid occupied spawns" {
    world = World();
    player = Player(health=125, pos=Vec3(x=10.0, z=50.0));
    bot = Opponent(health=125, arena=True, game="q3", eye_height=26.0, pos=Vec3(y=10.0, z=50.0));
    monster = Opponent(health=100, game="q3", pos=Vec3(x=-10.0, z=46.0));
    arriving = Opponent(health=125, arena=True, game="q3", eye_height=26.0, pos=Vec3(z=50.0));
    world +>:HasOpponent:+> bot;
    world +>:HasOpponent:+> monster;
    world +>:HasOpponent:+> arriving;
    struck = world spawn KillBox(mover=arriving, origin=Vec3(z=24.0), game="q3", bystander=player, bystander_height=26.0);
    assert struck.victims == 2;
    assert player.health <= 0 and bot.health <= 0;
    assert monster.health == 100 and arriving.health == 125;
    # SpotWouldTelefrag: a spawn someone stands on is never chosen.
    world +>:HasSpawn:+> SpawnPoint(pos=Vec3(x=2000.0));
    world +>:HasSpawn:+> SpawnPoint(pos=Vec3(x=1800.0));
    world +>:HasSpawn:+> SpawnPoint(pos=Vec3(x=100.0));
    for seed in range(1, 6) {
        choice = world spawn ChooseSpawn(avoid=[Vec3()], occupied=[Vec3(x=2000.0, z=10.0)], seed=seed);
        spot = choice.pick();
        assert spot is not None and spot.pos.x == 1800.0;
    }
}
