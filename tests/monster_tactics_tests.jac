import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    CombatState,
    CombatTick,
    Opponent,
    HasOpponent,
    Mends,
    Drops,
    damage_opponent,
    attack_chance
}
import from games.items { monster_drop }
import from engine.world.pickups { Pickup, HasPickup }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

def floored_map() -> CollisionMap {
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=-4000.0, y=-4000.0, z=-16.0),
        Vec3(x=4000.0, y=4000.0, z=0.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    return collision;
}

def tactics_monster(game: str, kind: str, pos: Vec3) -> Opponent {
    rule = enemy_rule(game, kind, 0);
    assert rule is not None;
    return Opponent(
        rule=rule,
        kind=kind,
        game=game,
        pos=pos,
        health=rule.health,
        max_health=rule.health,
        grounded=True
    );
}

test "attack chances fall with range as Q1 CheckAttack and Q2 M_CheckAttack roll them" {
    grunt = tactics_monster("q1", "monster_army", Vec3());
    assert attack_chance(grunt, 60.0, False) == 0.9;
    assert attack_chance(grunt, 300.0, False) == 0.4;
    assert attack_chance(grunt, 700.0, False) == 0.05;
    assert attack_chance(grunt, 1200.0, False) == 0.0;
    enforcer = tactics_monster("q1", "monster_enforcer", Vec3());
    assert attack_chance(enforcer, 300.0, False) == 0.4;
    assert attack_chance(enforcer, 700.0, False) == 0.1;
    knight = tactics_monster("q1", "monster_hell_knight", Vec3());
    assert attack_chance(knight, 300.0, False) == 0.2;
    assert attack_chance(knight, 50.0, True) == 1.0;
    soldier = tactics_monster("q2", "monster_soldier", Vec3());
    soldier.skill = 1;
    assert attack_chance(soldier, 300.0, False) == 0.1;
    assert attack_chance(soldier, 700.0, False) == 0.02;
    soldier.skill = 0;
    assert attack_chance(soldier, 300.0, False) == 0.05;
    assert attack_chance(soldier, 50.0, True) == 0.25;
    soldier.skill = 2;
    assert attack_chance(soldier, 300.0, False) == 0.2;
    assert attack_chance(soldier, 1200.0, False) == 0.0;
}

test "monsters keep running at the player between attacks" {
    for scenario in [("q1", "monster_army"), ("q2", "monster_soldier_light")] {
        world = World();
        collision = floored_map();
        state = CombatState(game=scenario[0]);
        player = Player(pos=Vec3(x=450.0), health=100000, god_mode=True);
        enemy = tactics_monster(scenario[0], scenario[1], Vec3(z=22.0));
        enemy.alert = 8.0;
        enemy.last_seen = player.pos;
        world +>:HasOpponent:+> enemy;
        attacks = 0;
        attacking = False;
        travelled = 0.0;
        for tick in range(600) {
            before = enemy.pos.add(Vec3());
            world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 60.0);
            step = enemy.pos.sub(before);
            step.z = 0.0;
            travelled += step.length();
            if enemy.attack_clock >= 0.0 and not attacking {
                attacks += 1;
            }
            attacking = enemy.attack_clock >= 0.0;
        }
        # Ten seconds: it closes in and moves around rather than standing to fire.
        assert travelled > 250.0;
        assert attacks >= 1 and attacks <= 8;
    }
}

test "a hit from the player's rockets or nails wakes a monster and turns it on the player" {
    player = Player(pos=Vec3(x=300.0));
    grunt = tactics_monster("q1", "monster_army", Vec3());
    damage_opponent(grunt, 5, attacker=player, means="splash");
    assert grunt.alert > 0.0 and grunt.sighted;
    assert grunt.last_seen.x == 300.0;
    # A newly woken Q1 monster waits a moment before firing (HuntTarget).
    assert grunt.attack_wait >= 1.0;
    rival = tactics_monster("q1", "monster_ogre", Vec3(x=-200.0));
    fighter = tactics_monster("q1", "monster_knight", Vec3(x=50.0));
    fighter.foe = rival;
    fighter.alert = 8.0;
    damage_opponent(fighter, 1, attacker=player);
    assert fighter.foe is None;
}

test "a Q1 monster that has found the player keeps hunting after losing sight" {
    world = World();
    collision = floored_map();
    # A wall between them hides the player.
    collision.add_box(
        Vec3(x=150.0, y=-40.0, z=-100.0),
        Vec3(x=160.0, y=40.0, z=100.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    state = CombatState(game="q1");
    player = Player(pos=Vec3(x=400.0, z=22.0));
    enemy = tactics_monster("q1", "monster_army", Vec3(z=22.0));
    enemy.alert = 8.0;
    enemy.last_seen = Vec3(x=100.0, z=22.0);
    world +>:HasOpponent:+> enemy;
    for tick in range(60 * 12) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 60.0);
    }
    assert enemy.alert > 0.0;
    assert enemy.last_seen.sub(player.pos).length() < 1.0;
}

test "a Q2 medic runs to a corpse and raises it with its cable" {
    world = World();
    collision = floored_map();
    state = CombatState(game="q2");
    player = Player(pos=Vec3(x=-2000.0, z=22.0), health=100000, god_mode=True);
    medic = tactics_monster("q2", "monster_medic", Vec3(z=22.0));
    medic.skill = 1;
    corpse = tactics_monster("q2", "monster_infantry", Vec3(x=400.0, z=22.0));
    corpse.health = 0;
    corpse.death_animation = [0, 1, 2];
    corpse.animation_time = 10.0;
    corpse.visual.visible = True;
    world +>:HasOpponent:+> medic;
    world +>:HasOpponent:+> corpse;
    for tick in range(60 * 8) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 60.0);
        if corpse.health > 0 {
            break;
        }
    }
    assert corpse.health == corpse.rule.health;
    assert corpse.revived;
    assert not [medic->:Mends:->];
    # The cable reaches 256 units at most.
    assert medic.pos.sub(corpse.pos).length() < 260.0;
}

test "dead monsters drop what they carry where they fall" {
    grunt_pack = monster_drop("q1", "monster_army", {});
    assert grunt_pack is not None and grunt_pack.grants == {"shells": 5};
    ogre_pack = monster_drop("q1", "monster_ogre", {});
    assert ogre_pack is not None and ogre_pack.grants == {"rockets": 2};
    assert monster_drop("q1", "monster_knight", {}) is None;
    shard = monster_drop("q2", "monster_soldier", {"item": "item_armor_shard"});
    assert shard is not None and shard.kind == "armor";
    assert monster_drop("q2", "monster_soldier", {}) is None;
    world = World();
    collision = floored_map();
    state = CombatState(game="q1");
    player = Player(pos=Vec3(x=-600.0, z=22.0));
    grunt = tactics_monster("q1", "monster_army", Vec3(x=100.0, z=22.0));
    world +>:HasOpponent:+> grunt;
    backpack = Pickup(rule=grunt_pack, pos=grunt.pos, active=False);
    world +>:HasPickup:+> backpack;
    grunt +>:Drops:+> backpack;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 60.0);
    assert not backpack.active;
    damage_opponent(grunt, 1000, attacker=player);
    world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 60.0);
    assert backpack.active and backpack.dropped;
    assert abs(backpack.pos.z) < 0.5 and abs(backpack.pos.x - 100.0) < 0.5;
    assert not [grunt->:Drops:->];
}
