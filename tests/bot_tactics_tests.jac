import math;
import from games.botfiles { skill_blocks, values_at, character_from }
import from games.weapons { weapon_rules }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, CombatTick, Projectile, HasProjectile, arm_bot }
import from engine.world.bot_ai { BotTactics }
import from engine.world.bot_tactics { choose_weapon, change_view, steer_view, look_at, bot_fire, rule_for }
import from engine.world.bot_character { BotCharacter, BotState, bot_skill, bot_handicap, bot_aggression, enemy_view, entity_visible, Q3_SKILL_NAMES }
import from engine.world.bot_weights { bot_inventory, battle_inventory }
import from engine.world.bot_tactics { attack_move }
import from engine.formats.botscript { precompile }
import from engine.formats.botconfig { WeightConfig, read_weight_config }
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

# Each weapon's inventory index and its ammo's (botfiles/inv.h), by number.
glob WEAPON_SLOTS: dict[int, tuple[int, int]] = {
    1: (4, 0), 2: (6, 19), 3: (5, 18), 4: (7, 20), 5: (8, 23), 6: (9, 22), 7: (10, 24), 8: (11, 21), 9: (13, 25)
};

"""A character whose weapon weights are fw_weap.c's switches (none without
the weapon or its ammo) returning `weights` by weapon number; the lightning
gun's falls to $evalint(W*0.1) = 0 beyond 768 units."""
def armed_mind(weights: dict[int, int], base: BotCharacter | None = None) -> BotCharacter {
    mind = base if base is not None else BotCharacter();
    text = "";
    for (number, weight) in weights.items() {
        slots = WEAPON_SLOTS[number];
        inner = "return " + str(weight) + ";";
        if number == 6 {
            inner = "switch(200) { case 768: return " + str(weight) + "; default: return $evalint(" + str(weight) + "*0.1); }";
        }
        ammo = inner if slots[1] == 0 else "switch(" + str(slots[1]) + ") { case 1: return 0; default: { " + inner + " } }";
        text += "weight \"W" + str(number) + "\" { switch(" + str(slots[0]) + ") { case 1: return 0; default: { " + ammo + " } } }\n";
    }
    mind.weapon_weights = read_weight_config(precompile("w.c", {"w.c": text}));
    for number in weights.keys() {
        mind.weapon_numbers[number] = mind.weapon_weights.find("W" + str(number));
    }
    return mind;
}


"""BotChooseWeapon against an enemy `gap` units away."""
def pick_weapon(bot: Opponent, mind: BotCharacter, gap: float) -> int {
    inventory = bot_inventory(bot);
    battle_inventory(inventory, bot, bot.eye_height, Player(pos=Vec3(x=gap)), 22.0);
    return choose_weapon(bot, mind, inventory);
}

"""BotAggression holding weapon number `weapon`."""
def keen(bot: Opponent, foe: Player, weapon: int) -> float {
    inventory = bot_inventory(bot);
    battle_inventory(inventory, bot, bot.eye_height, foe, 22.0);
    return bot_aggression(inventory, weapon);
}

test "botlib characters load exact skills and interpolate between them" {
    blocks = skill_blocks(SAMPLE);
    assert sorted(blocks.keys()) == [1, 4];
    assert values_at(blocks, 1.0)["CHARACTERISTIC_AIM_ACCURACY"] == "0.25";
    halfway = values_at(blocks, 2.5);
    assert abs(float(halfway["CHARACTERISTIC_AIM_ACCURACY"]) - 0.55) < 0.0001;
    assert halfway["CHARACTERISTIC_NAME"] == "Sample";
    mind = character_from(SAMPLE, "", 4.0);
    # Characteristic_BFloat clamps to [0, 1]; per-weapon values override.
    assert mind.name == "Sample" and mind.reaction == 1.0;
    assert mind.accuracy_for("railgun") == 0.9 and mind.accuracy_for("shotgun") == 0.85;
    # Normal is Q3's default Bring It On; handicaps from G_AddBot.
    assert bot_skill(0) == 1.0 and bot_skill(1) == 2.0 and bot_skill(3) == 4.0;
    assert bot_handicap(1.0) == 50 and bot_handicap(2.0) == 70 and bot_handicap(3.0) == 90 and bot_handicap(4.0) == 100;
    # The fifth setting is Nightmare!: the character's own skill 5 block and
    # no handicap.
    assert bot_skill(4) == 5.0 and bot_handicap(bot_skill(4)) == 100;
    assert Q3_SKILL_NAMES[int(bot_skill(4)) - 1] == "Nightmare!" and Q3_SKILL_NAMES[int(bot_skill(2)) - 1] == "Hurt Me Plenty";
    nightmare = skill_blocks(SAMPLE + "skill 5\n{\n\tCHARACTERISTIC_AIM_ACCURACY\t\t0.95\n}\n");
    assert values_at(nightmare, 5.0)["CHARACTERISTIC_AIM_ACCURACY"] == "0.95";
}

test "bots pick their heaviest loaded weapon and shun a distant lightning gun" {
    bot = Opponent(arena=True);
    arm_bot(bot);
    mind = armed_mind({1: 10, 2: 30, 5: 100, 6: 80});
    assert pick_weapon(bot, mind, 300.0) == 2;
    bot.inventory spawn AdjustInventory(kind="weapon_lightning", amount=1, capacity=1);
    bot.inventory spawn AdjustInventory(kind="lightning", amount=50, capacity=200);
    assert pick_weapon(bot, mind, 300.0) == 6;
    assert pick_weapon(bot, mind, 1000.0) == 2;
    # A launcher without rockets is not a choice.
    bot.inventory spawn AdjustInventory(kind="weapon_rocketlauncher", amount=1, capacity=1);
    assert pick_weapon(bot, mind, 300.0) == 6;
    bot.inventory spawn AdjustInventory(kind="rockets", amount=5, capacity=200);
    assert pick_weapon(bot, mind, 300.0) == 5;
    # No switching while a weapon is still coming up.
    bot.weapon_change = 0.1;
    assert pick_weapon(bot, mind, 300.0) == bot.weapon_slot;
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
    assert keen(bot, foe, 2) == 0.0;
    bot.inventory spawn AdjustInventory(kind="weapon_rocketlauncher", amount=1, capacity=1);
    bot.inventory spawn AdjustInventory(kind="rockets", amount=10, capacity=200);
    assert keen(bot, foe, 5) == 90.0;
    # Hurt without armor, or below an enemy far overhead, it would rather not.
    bot.health = 70;
    assert keen(bot, foe, 5) == 0.0;
    bot.health = 100;
    foe.pos = Vec3(x=300.0, z=260.0);
    assert keen(bot, foe, 5) == 0.0;
}

test "bots hold fire for their reaction time, then shoot what they face" {
    world = World();
    collision = CollisionMap();
    state = CombatState(game="q3");
    human = Player(health=100, pos=Vec3(x=-5000.0));
    rules = weapon_rules("q3");
    shooter = Opponent(arena=True, health=100, character=armed_mind({2: 30}, BotCharacter(reaction=0.5, fire_throttle=1.0)));
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

test "unskilled bots stand, mediocre ones only close or open the distance, good ones strafe" {
    collision = arena_floor();
    foe = Opponent(arena=True, health=100, pos=Vec3(x=600.0, z=22.0));
    bot = Opponent(arena=True, health=100, pos=Vec3(z=22.0), grounded=True);
    arm_bot(bot);
    attack_move(bot, BotCharacter(attack_skill=0.1), foe, collision);
    assert bot.steering.length() == 0.0;
    attack_move(bot, BotCharacter(attack_skill=0.3), foe, collision);
    assert bot.steering.x > 0.99 and abs(bot.steering.y) < 0.001;
    # At the ideal distance BotAttackMove strafes sideways (or backs off).
    foe.pos = Vec3(x=140.0, z=22.0);
    attack_move(bot, BotCharacter(attack_skill=0.9), foe, collision);
    assert abs(bot.steering.y) > 0.5 and bot.steering.x <= 0.001;
}

test "bots find enemies as BotFindEnemy does: in view, seen, closer, or when hurt" {
    # The view widens from 90 degrees up close to 180 at 810 units, and is
    # all round for a hurt bot or a firing enemy.
    assert abs(enemy_view(90.0, False) - 91.111) < 0.01;
    assert enemy_view(810.0, False) == 180.0 and enemy_view(2000.0, False) == 180.0;
    assert enemy_view(300.0, True) == 360.0;
    # BotEntityVisible sees the middle, bottom or top of a player's box.
    collision = arena_floor();
    collision.add_box(Vec3(x=100.0, y=-100.0, z=0.0), Vec3(x=120.0, y=100.0, z=50.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    assert entity_visible(collision, Vec3(z=50.0), Vec3(x=300.0, z=24.0));
    assert not entity_visible(collision, Vec3(z=20.0), Vec3(x=300.0, z=24.0));
    # A bot facing away from a quiet enemy does not notice it, until hurt.
    world = World();
    bot = Opponent(arena=True, health=100, pos=Vec3(z=22.0), eye_height=22.0, yaw=0.0,
        character=BotCharacter(alertness=0.5));
    behind = Opponent(arena=True, health=100, pos=Vec3(x=-400.0, z=22.0), eye_height=22.0, yaw=0.0);
    world +>:HasOpponent:+> bot;
    world +>:HasOpponent:+> behind;
    far = Player(health=0, pos=Vec3(x=5000.0, z=22.0));
    world spawn CombatTick(player=far, collision=CollisionMap(), state=CombatState(), dt=0.2, arena_live=True);
    assert bot.foe is None;
    bot.health = 80;
    world spawn CombatTick(player=far, collision=CollisionMap(), state=CombatState(), dt=0.2, arena_live=True);
    assert bot.foe is behind;
    # Only a closer enemy replaces the current one.
    ahead = Opponent(arena=True, health=100, pos=Vec3(x=600.0, z=22.0), eye_height=22.0);
    world +>:HasOpponent:+> ahead;
    world spawn CombatTick(player=far, collision=CollisionMap(), state=CombatState(), dt=0.2, arena_live=True);
    assert bot.foe is behind;
}

test "the reaction time runs from finding an enemy, not from each glimpse" {
    rules = weapon_rules("q3");
    world = World();
    collision = arena_floor();
    human = Player(health=100, pos=Vec3(x=-5000.0));
    shooter = Opponent(arena=True, health=100, pos=Vec3(z=22.0), character=armed_mind({2: 30}, BotCharacter(reaction=0.5, fire_throttle=1.0)));
    target = Opponent(arena=True, health=100, pos=Vec3(x=300.0, z=22.0));
    arm_bot(shooter);
    world +>:HasOpponent:+> shooter;
    world +>:HasOpponent:+> target;
    shooter.foe = target;
    for tick in range(30) {
        world spawn BotTactics(player=human, collision=collision, state=CombatState(game="q3"), rules=rules, dt=0.01);
    }
    assert shooter.bot_state.battle != "" and abs(shooter.enemy_sight - 0.3) < 0.02;
    # A new enemy replacing a living one counts as seen two seconds ago.
    other = Opponent(arena=True, health=100, pos=Vec3(x=-300.0, z=22.0));
    world +>:HasOpponent:+> other;
    shooter.foe = other;
    for tick in range(10) {
        world spawn BotTactics(player=human, collision=collision, state=CombatState(game="q3"), rules=rules, dt=0.01);
    }
    assert shooter.bot_state.enemy is other and shooter.enemy_sight > 2.0;
    # Lost from sight, a bot not keen to chase gives its enemy up; found
    # again, its reaction time starts afresh (enemysight_time = now).
    wall = arena_floor();
    wall.add_box(Vec3(x=-120.0, y=-100.0, z=0.0), Vec3(x=-100.0, y=100.0, z=200.0), Vec3(), Vec3(), Vec3());
    wall.reindex();
    for tick in range(10) {
        world spawn BotTactics(player=human, collision=wall, state=CombatState(game="q3"), rules=rules, dt=0.01);
    }
    assert shooter.bot_state.enemy is None;
    for tick in range(10) {
        world spawn BotTactics(player=human, collision=collision, state=CombatState(game="q3"), rules=rules, dt=0.01);
    }
    assert shooter.bot_state.enemy is other and shooter.enemy_sight < 0.2;
}
