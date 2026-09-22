"""Validate authored attack poses against original Q1 assets and native timing."""
import os;
import from engine.assets.library { AssetLibrary }
import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    HasProjectile,
    Projectile,
    CombatState,
    CombatTick
}
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

with entry {
    library = AssetLibrary(game="q1");
    library.open(os.getenv("HOME", "") + "/quake-assets/id1");
    try {
        for kind in [
            "monster_army",
            "monster_hell_knight",
            "monster_dog",
            "monster_knight",
            "monster_enforcer",
            "monster_ogre",
            "monster_ogre_marksman"
        ] {
            rule = enemy_rule("q1", kind);
            assert rule is not None;
            model = library.model(rule.model).model;
            names = [frame.name for frame in model.surfaces[0].frames];
            for name in rule.attack_frames
                + rule.melee_frames
                + rule.alternate_melee_frames {
                assert name in names;
            }
            assert len(rule.attack_frames) == int(rule.attack_duration * 10.0);
            for path in [rule.attack_sound, rule.melee_sound] {
                if path {
                    assert len(library.read(path)) > 44;
                }
            }
            print("ATTACK ASSET PASS " + kind);
        }
        assert library.model("progs/k_spike.mdl").model.surfaces;
    } finally {
        library.close();
    }
    world = World();
    player = Player(pos=Vec3(x=120.0));
    state = CombatState();
    collision = CollisionMap();
    rule = enemy_rule("q1", "monster_enforcer");
    assert rule is not None;
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.4);
    assert not [world->:HasProjectile:->];
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    assert len([world->:HasProjectile:->]) == 1;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.4);
    assert len([world->:HasProjectile:->]) == 2;
    print("NATIVE ATTACK TIMING PASS");
    volley = World();
    knight_rule = enemy_rule("q1", "monster_hell_knight");
    assert knight_rule is not None;
    volley +>:HasOpponent:+> Opponent(rule=knight_rule, attack_wait=0.0);
    volley spawn CombatTick(player=player, collision=collision, state=state, dt=1.0);
    shots = [volley->:HasProjectile:->][?:Projectile];
    assert len(shots) == 6 and shots[0].velocity.y < 0.0 and shots[5].velocity.y > 0.0;
    print("NATIVE HELL KNIGHT VOLLEY PASS");
}
