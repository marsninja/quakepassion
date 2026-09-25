import math;
import from games.botfiles { skill_blocks, values_at, weapon_weights, character_from }
import from games.weapons { weapon_rules }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, Projectile, HasProjectile, arm_bot }
import from engine.world.bot_tactics { BotTactics, choose_weapon, change_view, steer_view, look_at, bot_fire, rule_for, bot_aggression }
import from engine.world.bot_character { BotCharacter, BotState, bot_skill, bot_handicap }
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
    # Normal is Q3's default Bring It On; handicaps from G_AddBot.
    assert bot_skill(0) == 1.0 and bot_skill(1) == 2.0 and bot_skill(3) == 4.0;
    assert bot_handicap(1.0) == 50 and bot_handicap(2.0) == 70 and bot_handicap(3.0) == 90 and bot_handicap(4.0) == 100;
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
    look_at(bot, Vec3(y=100.0));
    assert abs(bot.bot_state.ideal_yaw - 90.0) < 0.0001;
    slow = BotCharacter(view_factor=0.5, view_maxchange=90.0);
    change_view(bot.bot_state, slow, True, 0.05);
    # BotChangeViewAngles: a quarter turn is capped at 240 degrees a second.
    assert abs(bot.bot_state.yaw - 12.0) < 0.0001;
    fast = BotCharacter(view_factor=0.5, view_maxchange=3600.0);
    state = BotState(ideal_yaw=90.0);
    change_view(state, fast, True, 0.05);
    assert abs(state.yaw - 45.0) < 0.0001;
    # With no enemy the view drifts toward the movement at a slow 0.05.
    state = BotState(ideal_yaw=90.0);
    change_view(state, fast, False, 0.05);
    assert abs(state.yaw - 4.5) < 0.0001;
    # The drawn view moves every tick, between 50 ms server frames.
    bot = Opponent(arena=True, yaw=0.0);
    look_at(bot, Vec3(y=100.0));
    seen: list[float] = [];
    for tick in range(20) {
        steer_view(bot, fast, True, 0.01);
        seen.append(bot.yaw);
    }
    assert len(set(seen)) >= 12;
    # The "over reaction" model overshoots, then settles on the target.
    for tick in range(100) {
        steer_view(bot, fast, True, 0.01);
    }
    assert abs(math.degrees(bot.yaw) - 90.0) < 1.0;
}

test "outgunned bots want to retreat and well-armed ones to fight" {
    bot = Opponent(arena=True, health=100);
    arm_bot(bot);
    foe = Player(health=100, pos=Vec3(x=300.0));
    assert bot_aggression(bot, foe, "machinegun") == 0.0;
    bot.inventory spawn AdjustInventory(kind="weapon_rocketlauncher", amount=1, capacity=1);
    bot.inventory spawn AdjustInventory(kind="rockets", amount=10, capacity=200);
    assert bot_aggression(bot, foe, "rocketlauncher") == 90.0;
    # Hurt without armor, or below an enemy far overhead, it would rather not.
    bot.health = 70;
    assert bot_aggression(bot, foe, "rocketlauncher") == 0.0;
    bot.health = 100;
    foe.pos = Vec3(x=300.0, z=260.0);
    assert bot_aggression(bot, foe, "rocketlauncher") == 0.0;
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

def arena_floor() -> CollisionMap {
    collision = CollisionMap();
    collision.add_box(Vec3(x=-2000.0, y=-2000.0, z=-64.0), Vec3(x=2000.0, y=2000.0, z=0.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    return collision;
}

def duel(mind: BotCharacter, gap: float) -> Opponent {
    world = World();
    collision = arena_floor();
    state = CombatState(game="q3");
    rules = weapon_rules("q3");
    bot = Opponent(arena=True, health=100, pos=Vec3(z=22.0), grounded=True, character=mind);
    foe = Opponent(arena=True, health=100, pos=Vec3(x=gap, z=22.0), grounded=True);
    arm_bot(bot);
    world +>:HasOpponent:+> bot;
    world +>:HasOpponent:+> foe;
    bot.foe = foe;
    bot.arena_goal = Vec3(x=-500.0, z=22.0);
    for tick in range(30) {
        world spawn BotTactics(player=Player(), collision=collision, state=state, rules=rules, dt=0.01);
    }
    return bot;
}

test "outgunned bots retreat while shooting back; armed ones fight with attack moves" {
    # Only a machine gun: BotWantsToRetreat, so the route follower steers.
    wary = duel(BotCharacter(attack_skill=0.9), 300.0);
    assert wary.bot_state.battle == "retreat" and not wary.fighting;
    # A railgun with slugs makes it keen: it fights, strafing across the enemy.
    world = World();
    collision = arena_floor();
    rules = weapon_rules("q3");
    bot = Opponent(arena=True, health=100, pos=Vec3(z=22.0), grounded=True, character=BotCharacter(attack_skill=0.9, weights={"railgun": 100}));
    arm_bot(bot);
    bot.inventory spawn AdjustInventory(kind="weapon_railgun", amount=1, capacity=1);
    bot.inventory spawn AdjustInventory(kind="slugs", amount=10, capacity=200);
    foe = Opponent(arena=True, health=100, pos=Vec3(x=140.0, z=22.0));
    world +>:HasOpponent:+> bot;
    world +>:HasOpponent:+> foe;
    bot.foe = foe;
    for tick in range(30) {
        world spawn BotTactics(player=Player(), collision=collision, state=CombatState(game="q3"), rules=rules, dt=0.01);
    }
    assert bot.bot_state.battle == "fight" and bot.fighting;
    # At the ideal distance BotAttackMove strafes sideways (or backs off).
    assert abs(bot.steering.y) > 0.5 and bot.steering.x <= 0.001;
    # Out of sight, a keen bot chases where the enemy was.
    collision.add_box(Vec3(x=60.0, y=-2000.0, z=0.0), Vec3(x=80.0, y=2000.0, z=6000.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    for tick in range(20) {
        world spawn BotTactics(player=Player(), collision=collision, state=CombatState(game="q3"), rules=rules, dt=0.01);
    }
    assert bot.bot_state.battle == "chase" and bot.bot_state.chase_target.x == 140.0;
}

test "unskilled bots stand, mediocre ones only close or open the distance" {
    world = World();
    collision = arena_floor();
    rules = weapon_rules("q3");
    bot = Opponent(arena=True, health=100, pos=Vec3(z=22.0), grounded=True, character=BotCharacter(attack_skill=0.3));
    arm_bot(bot);
    bot.inventory spawn AdjustInventory(kind="weapon_railgun", amount=1, capacity=1);
    bot.inventory spawn AdjustInventory(kind="slugs", amount=10, capacity=200);
    foe = Opponent(arena=True, health=100, pos=Vec3(x=600.0, z=22.0));
    world +>:HasOpponent:+> bot;
    world +>:HasOpponent:+> foe;
    bot.foe = foe;
    for tick in range(15) {
        world spawn BotTactics(player=Player(), collision=collision, state=CombatState(game="q3"), rules=rules, dt=0.01);
    }
    assert bot.bot_state.battle == "fight";
    assert bot.steering.x > 0.99 and abs(bot.steering.y) < 0.001;
}

# Ranger's botlib character (botfiles/bots/ranger_c.c), the characteristics
# that decide whether and how it shoots.
glob RANGER: str = '''
skill 1
{
	CHARACTERISTIC_NAME							"Ranger"
	CHARACTERISTIC_ATTACK_SKILL					0.0
	CHARACTERISTIC_AIM_ACCURACY					0.2
	CHARACTERISTIC_AIM_SKILL					0.2
	CHARACTERISTIC_VIEW_FACTOR					0.25
	CHARACTERISTIC_VIEW_MAXCHANGE				90
	CHARACTERISTIC_REACTIONTIME					4.0
	CHARACTERISTIC_AGGRESSION					0.25
	CHARACTERISTIC_FIRETHROTTLE					0.5
}
skill 4
{
	CHARACTERISTIC_NAME							"Ranger"
	CHARACTERISTIC_ATTACK_SKILL					0.75
	CHARACTERISTIC_AIM_ACCURACY					0.6
	CHARACTERISTIC_AIM_SKILL					0.6
	CHARACTERISTIC_VIEW_FACTOR					0.75
	CHARACTERISTIC_VIEW_MAXCHANGE				120
	CHARACTERISTIC_REACTIONTIME					2.0
	CHARACTERISTIC_AGGRESSION					0.45
	CHARACTERISTIC_FIRETHROTTLE					0.8
}
skill 5
{
	CHARACTERISTIC_NAME							"Ranger"
	CHARACTERISTIC_ATTACK_SKILL					1.0
	CHARACTERISTIC_AIM_ACCURACY					1.0
	CHARACTERISTIC_AIM_SKILL					1.0
	CHARACTERISTIC_VIEW_FACTOR					1.0
	CHARACTERISTIC_VIEW_MAXCHANGE				360
	CHARACTERISTIC_REACTIONTIME					0.1
	CHARACTERISTIC_AGGRESSION					0.95
	CHARACTERISTIC_FIRETHROTTLE					1.0
}
''';

test "bots of every skill turn on a visible enemy and shoot, even retreating" {
    rules = weapon_rules("q3");
    for level in [1.0, 2.0, 3.0, 4.0, 5.0] {
        world = World();
        collision = arena_floor();
        # Handicapped health and a machine gun only: BotAggression says retreat.
        bot = Opponent(
            arena=True, health=bot_handicap(level), max_health=bot_handicap(level), pos=Vec3(z=22.0),
            yaw=math.pi, grounded=True, character=character_from(RANGER, "", WEIGHTS, level)
        );
        arm_bot(bot);
        # Running away from it, as the route follower would steer.
        bot.steering = Vec3(x=-1.0);
        bot.arena_goal = Vec3(x=-600.0, z=22.0);
        foe = Opponent(arena=True, health=100, pos=Vec3(x=400.0, z=22.0));
        world +>:HasOpponent:+> bot;
        world +>:HasOpponent:+> foe;
        bot.foe = foe;
        fired_at = -1.0;
        for tick in range(300) {
            world spawn BotTactics(player=Player(), collision=collision, state=CombatState(game="q3"), rules=rules, dt=0.01);
            if fired_at < 0.0 and quantity(bot.inventory, "bullets") < 100 {
                fired_at = float(tick) * 0.01;
            }
        }
        # (A sharp enough bot may have killed its enemy by now.)
        assert foe.health <= 0 or bot.bot_state.battle in ["retreat", "nbg"];
        # Within its reaction time and a turn to face the enemy.
        assert fired_at >= 0.0 and fired_at <= 3.0;
    }
}
