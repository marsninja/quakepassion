import math;
import from games.botfiles { skill_blocks, values_at, weapon_weights, character_from }
import from games.weapons { weapon_rules }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, Projectile, HasProjectile, arm_bot }
import from engine.world.bot_tactics { BotTactics, choose_weapon, turn_view, bot_fire, rule_for }
import from engine.world.bot_character { BotCharacter, bot_skill }
import from engine.world.inventory { quantity, AdjustInventory }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

glob SAMPLE: str = '''
#include "chars.h"
skill 1
{
	CHARACTERISTIC_NAME							"Sample"
	CHARACTERISTIC_AIM_ACCURACY					0.25
	CHARACTERISTIC_REACTIONTIME					2.0
	CHARACTERISTIC_WEAPONWEIGHTS				"bots/sample_w.c"
}
skill 4
{
	CHARACTERISTIC_NAME							"Sample"
	CHARACTERISTIC_AIM_ACCURACY					0.85
	CHARACTERISTIC_REACTIONTIME					1.0
	CHARACTERISTIC_AIM_ACCURACY_RAILGUN			0.9 // a comment
}
''';

glob WEIGHTS: str = '''
#define W_GAUNTLET				10
#define W_MACHINEGUN			30
#define W_ROCKETLAUNCHER		100
#define W_LIGHTNING				80
#include "fw_weap.c"
''';

test "botlib characters load exact skills and interpolate between them" {
    blocks = skill_blocks(SAMPLE);
    assert sorted(blocks.keys()) == [1, 4];
    assert values_at(blocks, 1.0)["CHARACTERISTIC_AIM_ACCURACY"] == "0.25";
    halfway = values_at(blocks, 2.5);
    assert abs(float(halfway["CHARACTERISTIC_AIM_ACCURACY"]) - 0.55) < 0.0001;
    assert halfway["CHARACTERISTIC_NAME"] == "Sample";
    assert weapon_weights(WEIGHTS) == {"gauntlet": 10, "machinegun": 30, "rocketlauncher": 100, "lightning": 80};
    mind = character_from(SAMPLE, "", WEIGHTS, 4.0);
    # Characteristic_BFloat clamps to [0, 1]; per-weapon values override.
    assert mind.name == "Sample" and mind.reaction == 1.0;
    assert mind.accuracy_for("railgun") == 0.9 and mind.accuracy_for("shotgun") == 0.85;
    assert bot_skill(0) == 2.0 and bot_skill(1) == 3.0 and bot_skill(3) == 5.0;
}

test "bots pick their heaviest loaded weapon and shun a distant lightning gun" {
    rules = weapon_rules("q3");
    bot = Opponent(arena=True);
    arm_bot(bot);
    mind = BotCharacter(weights={"gauntlet": 10, "machinegun": 30, "rocketlauncher": 100, "lightning": 80});
    assert choose_weapon(bot, mind, rules, 300.0) == 2;
    bot.inventory spawn AdjustInventory(kind="weapon_lightning", amount=1, capacity=1);
    bot.inventory spawn AdjustInventory(kind="lightning", amount=50, capacity=200);
    assert choose_weapon(bot, mind, rules, 300.0) == 6;
    assert choose_weapon(bot, mind, rules, 1000.0) == 2;
    # A launcher without rockets is not a choice.
    bot.inventory spawn AdjustInventory(kind="weapon_rocketlauncher", amount=1, capacity=1);
    assert choose_weapon(bot, mind, rules, 300.0) == 6;
    bot.inventory spawn AdjustInventory(kind="rockets", amount=5, capacity=200);
    assert choose_weapon(bot, mind, rules, 300.0) == 5;
}

test "bot views turn at their characters' limited speed" {
    bot = Opponent(arena=True, yaw=0.0);
    slow = BotCharacter(view_factor=0.5, view_maxchange=90.0);
    turn_view(bot, slow, Vec3(y=100.0), 0.1);
    # A quarter turn is capped at 9 degrees per 0.1 s think.
    assert abs(bot.yaw - math.radians(9.0)) < 0.0001;
    fast = BotCharacter(view_factor=0.5, view_maxchange=3600.0);
    bot.yaw = 0.0;
    turn_view(bot, fast, Vec3(y=100.0), 0.1);
    assert abs(bot.yaw - math.pi / 4.0) < 0.0001;
}

test "bots hold fire for their reaction time, then shoot what they face" {
    world = World();
    collision = CollisionMap();
    state = CombatState(game="q3");
    human = Player(health=100, pos=Vec3(x=-5000.0));
    rules = weapon_rules("q3");
    shooter = Opponent(arena=True, health=100, character=BotCharacter(reaction=0.5, fire_throttle=1.0, weights={"machinegun": 30}));
    target = Opponent(arena=True, health=100, pos=Vec3(x=300.0));
    arm_bot(shooter);
    shooter.weapon_change = 1.0;
    world +>:HasOpponent:+> shooter;
    world +>:HasOpponent:+> target;
    shooter.foe = target;
    for tick in range(48) {
        world spawn BotTactics(player=human, collision=collision, state=state, rules=rules, dt=0.01);
    }
    assert target.health == 100 and shooter.enemy_sight > 0.4;
    for tick in range(60) {
        world spawn BotTactics(player=human, collision=collision, state=state, rules=rules, dt=0.01);
    }
    assert target.health < 100 and quantity(shooter.inventory, "bullets") < 100;
    assert target.foe is shooter;
}

test "bot rockets fly as owned projectiles and use up ammo" {
    world = World();
    collision = CollisionMap();
    state = CombatState(game="q3");
    rules = weapon_rules("q3");
    bot = Opponent(arena=True, health=100, character=BotCharacter());
    arm_bot(bot);
    bot.inventory spawn AdjustInventory(kind="weapon_rocketlauncher", amount=1, capacity=1);
    bot.inventory spawn AdjustInventory(kind="rockets", amount=10, capacity=200);
    rule = rule_for(rules, 5);
    assert rule is not None;
    bot_fire(world, bot, rule, Player(), collision, state);
    missiles = [world->:HasProjectile:->][?:Projectile];
    assert len(missiles) == 1 and missiles[0].owner is bot and missiles[0].hostile;
    assert missiles[0].velocity.length() > 899.0 and missiles[0].splash == 100;
    assert quantity(bot.inventory, "rockets") == 9 and bot.weapon_wait == 0.8;
}
