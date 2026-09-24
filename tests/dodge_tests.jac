import math;
import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    Projectile,
    HasProjectile,
    CombatState,
    CombatTick,
    Aim,
    Dodge,
    check_dodge,
    crouching,
    duck_length
}
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "Q2 infantry facing a blaster shot duck under it for a second" {
    rule = enemy_rule("q2", "monster_infantry");
    assert rule is not None;
    world = World();
    player = Player(health=100, pos=Vec3(z=22.0));
    collision = CollisionMap();
    state = CombatState();
    guard = Opponent(
        rule=rule, game="q2", health=100, pos=Vec3(x=300.0, z=22.0), yaw=math.pi,
        attack_wait=10.0, duck_animation=[0, 1, 2, 3, 4]
    );
    world +>:HasOpponent:+> guard;
    # Frames duck01-05, holding duck02 until a second after duck01.
    assert abs(duck_length(guard) - 1.4) < 0.0001;
    guard spawn Dodge(shooter=player, roll=0.5, choice=0.0);
    assert guard.duck_wait == 0.0;
    guard spawn Dodge(shooter=player, roll=0.1, choice=0.0);
    assert guard.duck_wait > 0.0 and crouching(guard);
    # A shot at eye level passes over the lowered box.
    shot = world spawn Aim(start=Vec3(z=22.0), finish=Vec3(x=600.0, z=22.0), height=22.0);
    assert shot.target is None;
    for i in range(10) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    }
    assert crouching(guard) and guard.visual.first == 1;
    for i in range(5) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    }
    assert guard.duck_wait == 0.0 and not crouching(guard);
    shot = world spawn Aim(start=Vec3(z=22.0), finish=Vec3(x=600.0, z=22.0), height=22.0);
    assert shot.target is guard;
    # Only a monster facing the shooter is warned.
    guard.yaw = 0.0;
    assert check_dodge(world, player, Vec3(x=1.0), collision, state) is None;
    guard.yaw = math.pi;
    assert check_dodge(world, player, Vec3(x=1.0), collision, state) is guard;
}

test "Q2 soldiers on medium sometimes crouch and fire instead of ducking" {
    rule = enemy_rule("q2", "monster_soldier_light");
    assert rule is not None;
    world = World();
    player = Player(health=100, pos=Vec3(z=22.0));
    collision = CollisionMap();
    state = CombatState();
    soldier = Opponent(
        rule=rule, game="q2", health=20, pos=Vec3(x=300.0, z=22.0), yaw=math.pi,
        skill=1, attack_wait=10.0, duck_animation=[0, 1, 2, 3, 4]
    );
    world +>:HasOpponent:+> soldier;
    soldier spawn Dodge(shooter=player, roll=0.1, choice=0.2);
    assert soldier.duck_wait == 0.0 and soldier.attack_clock == 0.0;
    assert soldier.profiles[soldier.attack_profile].name == "crouch";
    assert not crouching(soldier);
    for i in range(3) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    }
    assert crouching(soldier);
    assert len([world->:HasProjectile:->][?:Projectile]) == 1;
    for i in range(5) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    }
    assert len([world->:HasProjectile:->][?:Projectile]) >= 1;
    for i in range(4) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    }
    assert not crouching(soldier);
    # Easy soldiers always duck.
    soldier.skill = 0;
    soldier.attack_clock = -1.0;
    soldier spawn Dodge(shooter=player, roll=0.1, choice=0.2);
    assert soldier.duck_wait > 0.0 and soldier.attack_clock < 0.0;
    # Hard gunners lob a grenade half the time as they duck.
    gunner_rule = enemy_rule("q2", "monster_gunner");
    assert gunner_rule is not None;
    gunner = Opponent(
        rule=gunner_rule, game="q2", health=175, pos=Vec3(x=-300.0, z=22.0),
        skill=2, attack_wait=10.0, duck_animation=[0, 1, 2, 3, 4, 5, 6, 7]
    );
    world +>:HasOpponent:+> gunner;
    before = len([world->:HasProjectile:->][?:Projectile]);
    gunner spawn Dodge(shooter=player, roll=0.1, choice=0.0, grenade_roll=0.4, world=world);
    assert gunner.duck_wait > 0.0;
    assert len([world->:HasProjectile:->][?:Projectile]) == before;
    gunner.duck_wait = 0.0;
    gunner spawn Dodge(shooter=player, roll=0.1, choice=0.0, grenade_roll=0.9, world=world);
    grenades = [p for p in [world->:HasProjectile:->][?:Projectile] if p.effect == "q2_grenade"];
    assert len(grenades) == 1 and grenades[0].gravity;
}
