import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, CombatTick }
import from engine.world.speakers { Speaker, HasSpeaker }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "enforcer attack cues follow both bolt events without boundary duplicates" {
    rule = enemy_rule("q1", "monster_enforcer");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=300.0));
    speaker = Speaker(path=rule.attack_sound, origin=Vec3());
    world +>:HasSpeaker:+> speaker;
    enemy = Opponent(rule=rule, attack_wait=0.0, attack_speaker=speaker);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    collision = CollisionMap();
    for i in range(100) {
        world spawn CombatTick(
            player=player, collision=collision, state=state, dt=0.01
        );
    }
    assert enemy.attack_event == 2 and speaker.requests == 2;
}
