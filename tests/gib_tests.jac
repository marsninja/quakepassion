import from games.enemies { enemy_rule }
import from games.gibs { gib_rule }
import from engine.world.world { World, Area, move_to_area }
import from engine.world.combat { Opponent, HasOpponent, Aim, damage_opponent }
import from engine.world.gibs { Gib, HasGib, GibsInto, GibTick, throw_gibs }
import from engine.world.models { ModelResource, GatherModels }
import from engine.formats.animated { AnimatedModel }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }

def monster(game: str, kind: str) -> Opponent {
    rule = enemy_rule(game, kind, 0);
    assert rule is not None;
    enemy = Opponent(rule=rule, kind=kind, game=game, health=rule.health, max_health=rule.health);
    enemy.gib_rule = gib_rule(game, kind);
    return enemy;
}

def link_models(enemy: Opponent) {
    rule = enemy.gib_rule;
    assert rule is not None;
    head = ModelResource(name="head", model=AnimatedModel(), skins=[]);
    piece = ModelResource(name="piece", model=AnimatedModel(), skins=[]);
    enemy +>:GibsInto:count=1, head=True:+> head;
    enemy +>:GibsInto:count=3:+> piece;
}

test "only a hit far enough past zero health gibs, at each game's threshold" {
    grunt = monster("q1", "monster_army");
    damage_opponent(grunt, grunt.health + 35);
    assert grunt.health == 0 and not grunt.gibbed and grunt.remains == -35;
    grunt = monster("q1", "monster_army");
    damage_opponent(grunt, grunt.health + 36);
    assert grunt.gibbed and not grunt.visual.visible and grunt.pending_gibs == 36;
    # Q2 soldiers gib at exactly their gib_health of -30.
    soldier = monster("q2", "monster_soldier");
    damage_opponent(soldier, soldier.health + 30);
    assert soldier.gibbed;
    # Q1 zombies always come apart; monsters without gib models never do.
    zombie = monster("q1", "monster_zombie");
    damage_opponent(zombie, zombie.health);
    assert zombie.gibbed;
    fish = monster("q1", "monster_fish");
    assert fish.gib_rule is None;
    damage_opponent(fish, 1000);
    assert fish.health == 0 and not fish.gibbed;
}

test "Q2 corpses soak damage until they gib, Q1 corpses take none" {
    soldier = monster("q2", "monster_soldier");
    damage_opponent(soldier, soldier.health + 10);
    assert soldier.health == 0 and not soldier.gibbed;
    damage_opponent(soldier, 15);
    assert soldier.remains == -25 and not soldier.gibbed;
    damage_opponent(soldier, 5);
    assert soldier.gibbed and soldier.pending_gibs == 30;
    knight = monster("q1", "monster_knight");
    damage_opponent(knight, knight.health + 10);
    damage_opponent(knight, 500);
    assert knight.remains == -10 and not knight.gibbed;
    # Shots stop at a Q2 corpse's low box but pass over a Q1 corpse.
    world = World();
    body = monster("q2", "monster_infantry");
    body.pos = Vec3(x=100.0);
    body.eye_height = 22.0;
    damage_opponent(body, body.health);
    world +>:HasOpponent:+> body;
    low = world spawn Aim(start=Vec3(z=-40.0), finish=Vec3(x=300.0, z=-40.0), height=22.0);
    assert low.target is body;
    high = world spawn Aim(start=Vec3(), finish=Vec3(x=300.0), height=22.0);
    assert high.target is None;
}

test "gibs fly from their linked models, settle on the floor and fade" {
    world = World();
    area = Area(name="room", bounds=AABB(mins=Vec3(x=-1000.0, y=-1000.0, z=-1000.0), maxs=Vec3(x=1000.0, y=1000.0, z=1000.0)));
    world ++> area;
    collision = CollisionMap();
    collision.add_box(Vec3(x=-1000.0, y=-1000.0, z=-64.0), Vec3(x=1000.0, y=1000.0, z=0.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    grunt = monster("q1", "monster_army");
    grunt.pos = Vec3(z=24.0);
    move_to_area(grunt, area);
    link_models(grunt);
    rule = grunt.gib_rule;
    assert rule is not None;
    assert throw_gibs(world, grunt, rule, Vec3(z=24.0), 60, 7) == 4;
    gibs = [world->:HasGib:->][?:Gib];
    assert len(gibs) == 4 and len([gib for gib in gibs if gib.lasting]) == 1;
    assert len((world spawn GatherModels()).draws) == 4;
    for tick in range(240) {
        world spawn GibTick(collision=collision, dt=1.0 / 60.0);
    }
    for gib in [world->:HasGib:->][?:Gib] {
        assert gib.resting and gib.pos.z >= 0.0 and gib.pos.z < 1.0;
    }
    # Only the Q1 head outlasts the 10 to 20 second fade.
    for tick in range(21 * 4) {
        world spawn GibTick(collision=collision, dt=0.25);
    }
    left = [world->:HasGib:->][?:Gib];
    assert len(left) == 1 and left[0].lasting;
    assert len((world spawn GatherModels()).draws) == 1;
}
