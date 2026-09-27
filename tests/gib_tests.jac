import from games.enemies { enemy_rule }
import from games.gibs { gib_rule }
import from engine.world.world { World, Area, move_to_area }
import from engine.world.combat { Opponent, HasOpponent, Aim, CombatState, damage_opponent, fire_weapon, blast_actors }
import from engine.world.body_queue { Corpse, HasCorpse, leave_corpse, damage_corpse }
import from engine.world.models { PlayerRig }
import from engine.world.speakers { Speaker }
import from engine.world.world { Player }
import from games.weapons { equip_player }
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

test "Q3 bodies left behind soak shots and splash until they gib" {
    world = World();
    area = Area(name="0", bounds=AABB(mins=Vec3(), maxs=Vec3()));
    world ++> area;
    bot = Opponent(arena=True, game="q3", kind="arena_bot", pos=Vec3(x=200.0, z=26.0), eye_height=26.0, health=0);
    bot.gib_rule = gib_rule("q3", "arena_bot");
    link_models(bot);
    move_to_area(bot, area);
    rig = PlayerRig(alive=False);
    sound = Speaker(path="sound/player/gibsplt1.wav", origin=Vec3());
    # CopyToBodyQue keeps the dead player's health; a body already past
    # GIB_HEALTH takes no more damage.
    spent = leave_corpse(world, bot, rig, -45, bot.gib_rule, sound, 26.0);
    assert spent is not None and spent.gibs is None;
    body = leave_corpse(world, bot, rig, -10, bot.gib_rule, sound, 26.0);
    assert body is not None and body.gibs is not None;
    # Shots meet the body's lowered box: 24 to 8 units below its origin,
    # which is its eye height (26) below the recorded eye.
    low = world spawn Aim(start=Vec3(z=-16.0), finish=Vec3(x=400.0, z=-16.0), height=26.0);
    assert low.corpse is body and low.target is None;
    high = world spawn Aim(start=Vec3(z=0.0), finish=Vec3(x=400.0, z=0.0), height=26.0);
    assert high.corpse is None;
    assert not damage_corpse(world, body, 20) and body.remains == -30;
    # At GIB_HEALTH (-40) it bursts into its gib models and is gone.
    assert damage_corpse(world, body, 10);
    assert len([world->:HasGib:->][?:Gib]) == 4 and sound.requests == 1;
    assert body not in [world->:HasCorpse:->][?:Corpse] and not body.body.visible;
    # A player's machine gun and a rocket's splash reach bodies too.
    shot = leave_corpse(world, bot, PlayerRig(alive=False), -35, bot.gib_rule, sound, 26.0);
    player = Player(pos=Vec3(z=-16.0), health=100);
    state = CombatState(game="q3");
    equip_player(player, state, "q3");
    collision = CollisionMap(eye_height=26.0);
    assert fire_weapon(world, player, collision, state);
    assert shot is not None and shot.remains == -42 and shot not in [world->:HasCorpse:->][?:Corpse];
    blasted = leave_corpse(world, bot, PlayerRig(alive=False), -5, bot.gib_rule, sound, 26.0);
    blast_actors(world, Vec3(x=200.0, z=-10.0), 100, 120.0, False, Player(pos=Vec3(x=-5000.0), health=100), collision, state);
    assert blasted is not None and blasted.remains <= -40 and blasted not in [world->:HasCorpse:->][?:Corpse];
    # The body that was already past GIB_HEALTH is still lying there.
    assert [world->:HasCorpse:->][?:Corpse] == [spent];
}
