import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, CombatState, CombatTick, HasOpponent }
import from engine.math.vec3 { Vec3 }
import from tests.navigation_jump_tests { jump_gap }

test "arena route jump is executed through the shared movement integrator" {
    world = World();
    collision = jump_gap();
    player = Player(pos=Vec3(x=96.0, z=22.03125));
    bot = Opponent(arena=True, grounded=True, pos=Vec3(z=22.03125), last_seen=player.pos, arena_goal=player.pos, alert=100.0, attack_wait=1000.0);
    world +>:HasOpponent:+> bot;
    state = CombatState(game="q3");
    lifted = False;
    for i in range(1000) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 120.0);
        if bot.pos.z > 40.0 { lifted = True; }
    }
    assert lifted;
    assert bot.pos.x > 60.0 and bot.pos.z > 21.0;
}
