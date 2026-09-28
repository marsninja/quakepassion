"""Q3 bot AI: goals by fuzzy item weights (be_ai_goal.c), the ai_dmnet.c node
graph, and chats (ai_chat.c)."""
import from engine.formats.aas { TRAVEL_WALK, TFL_DEFAULT, TFL_ROCKETJUMP }
import from engine.formats.botscript { precompile }
import from engine.formats.botconfig { ItemInfo, WeightDice, read_weight_config, read_initial_chat, read_random_strings }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, arm_bot }
import from engine.world.arena { ArenaMatch, HasMatch, Competes }
import from engine.world.pickups { Pickup, PickupRule, HasPickup }
import from engine.world.inventory { AdjustInventory }
import from engine.world.bot_routes { build_navmesh }
import from engine.world.bot_goals { BotItems, HasBotItems, GoalState, LevelItem, add_level_item, choose_item_goal }
import from engine.world.bot_weights { bot_inventory }
import from engine.world.bot_character { BotCharacter, bot_travel_flags }
import from engine.world.bot_ai { BotTactics, AINode, Leads, build_bot_brain }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }
import from games.weapons { weapon_rules }
import from tests.bot_travel_tests { strip_aas }

glob ITEM_WEIGHTS: str = """
weight "item_armor_body" { return 300; }
weight "item_health" { switch(29) { case 100: return 50; default: return 0; } }
""";

glob WEAPON_WEIGHTS: str = """
weight "Machinegun" { switch(6) { case 1: return 0; default: { switch(19) { case 1: return 0; default: return 30; } } } }
weight "Rocket Launcher" { switch(8) { case 1: return 0; default: { switch(23) { case 1: return 0; default: return 100; } } } }
""";

glob CHATS: str = """
chat "tester"
{
	type "kill_praise" { "Nice one, ", 0, "."; }
	type "kill_insult" { "Nice one, ", 0, "."; }
	type "death_praise" { "You got me, ", 0, "."; }
	type "death_insult" { "You got me, ", 0, "."; }
	type "death_rail" { "You got me, ", 0, "."; }
}
""";

def tester() -> BotCharacter {
    return BotCharacter(
        name="Tester",
        attack_skill=0.9,
        weapon_jumping=0.75,
        item_weights=read_weight_config(precompile("i.c", {"i.c": ITEM_WEIGHTS})),
        item_numbers={"item_armor_body": 0, "item_health": 1},
        weapon_weights=read_weight_config(precompile("w.c", {"w.c": WEAPON_WEIGHTS})),
        weapon_numbers={2: 0, 5: 1},
        chats=read_initial_chat(precompile("t.c", {"t.c": CHATS}), "tester"),
        chat_kill=1.0,
        chat_death=1.0,
        chat_insult=0.5
    );
}

def pickup(classname: str, kind: str, x: float) -> Pickup {
    return Pickup(pos=Vec3(x=x, z=0.0), rule=PickupRule(kind=kind, amount=25, capacity=200, model="", classname=classname));
}

test "bots choose goals by fuzzy item weight over travel time and avoid them after" {
    walks = [(i, i + 1, TRAVEL_WALK) for i in range(1, 8)] + [(i + 1, i, TRAVEL_WALK) for i in range(1, 8)];
    mesh = build_navmesh(World(), strip_aas(8, walks));
    items = BotItems(infos=[
        ItemInfo(classname="item_armor_body", respawntime=25.0, mins=Vec3(x=-15.0, y=-15.0, z=-15.0), maxs=Vec3(x=15.0, y=15.0, z=15.0)),
        ItemInfo(classname="item_health", respawntime=35.0, mins=Vec3(x=-15.0, y=-15.0, z=-15.0), maxs=Vec3(x=15.0, y=15.0, z=15.0))
    ]);
    collision = CollisionMap();
    armor = add_level_item(items, pickup("item_armor_body", "armor", 448.0), mesh, collision, 0);
    health = add_level_item(items, pickup("item_health", "health", 192.0), mesh, collision, 0);
    assert armor is not None and health is not None and armor.goal_area == 7 and health.goal_area == 3;
    for item in [armor, health] {
        item.linked = True;
        mesh.times_to(item.goal_area);
    }
    mind = tester();
    bot = Opponent(arena=True, health=50, pos=Vec3(x=64.0, z=26.0));
    goals = GoalState();
    dice = WeightDice(state=3);
    # 300 for the armor, far off, beats 50 for health close by.
    assert choose_item_goal(items, mind.item_weights, mind.item_numbers, bot_inventory(bot), dice, goals, mesh, Vec3(x=64.0), TFL_DEFAULT);
    top = goals.top();
    assert top is not None and top.item is armor;
    # The chosen item is avoided for its respawn time: the health is next.
    assert goals.avoid_time(armor.number, items.clock) == 25.0;
    assert choose_item_goal(items, mind.item_weights, mind.item_numbers, bot_inventory(bot), dice, goals, mesh, Vec3(x=64.0), TFL_DEFAULT);
    second = goals.top();
    assert second is not None and second.item is health;
    # Healthy, with both avoided, nothing is worth going for.
    bot.health = 125;
    assert not choose_item_goal(items, mind.item_weights, mind.item_numbers, bot_inventory(bot), dice, goals, mesh, Vec3(x=64.0), TFL_DEFAULT);
    # A nearby goal must be within its travel time.
    goals.reset_avoid();
    assert not choose_item_goal(items, mind.item_weights, mind.item_numbers, bot_inventory(bot), dice, GoalState(), mesh, Vec3(x=64.0), TFL_DEFAULT, 10.0);
}

test "the ai_dmnet.c nodes are a graph of the switches between them" {
    brain = build_bot_brain();
    fight = brain.nodes["battle_fight"];
    targets = [node.name for node in [fight->:Leads:->][?:AINode]];
    assert sorted(targets) == ["battle_chase", "battle_retreat", "respawn", "seek_ltg", "stand"];
    assert [node.name for node in [brain.nodes["respawn"]->:Leads:->][?:AINode]] == ["seek_ltg"];
}

"""A bot and a rival on an open floor, in a match that names them."""
def arena_pair(mind: BotCharacter) -> tuple[World, Opponent, Opponent, ArenaMatch] {
    world = World();
    bot = Opponent(arena=True, health=100, pos=Vec3(z=26.0), eye_height=26.0, grounded=True, character=mind);
    rival = Opponent(arena=True, health=100, pos=Vec3(x=300.0, z=26.0), eye_height=26.0, grounded=True);
    arm_bot(bot);
    world +>:HasOpponent:+> bot;
    world +>:HasOpponent:+> rival;
    contest = ArenaMatch();
    world +>:HasMatch:+> contest;
    contest +>:Competes(name="Tester"):+> bot;
    contest +>:Competes(name="Mr Rival"):+> rival;
    return (world, bot, rival, contest);
}

def floor_collision() -> CollisionMap {
    collision = CollisionMap();
    collision.add_box(Vec3(x=-2000.0, y=-2000.0, z=-64.0), Vec3(x=2000.0, y=2000.0, z=0.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    return collision;
}

def think(world: World, collision: CollisionMap, state: CombatState, seconds: float) {
    rules = weapon_rules("q3");
    steps = int(seconds / 0.1 + 0.5);
    for i in range(steps) {
        world spawn BotTactics(player=Player(health=0, pos=Vec3(x=9000.0)), collision=collision, state=state, rules=rules, dt=0.1);
    }
}

test "an outgunned bot with nowhere to retreat fights it out; an armed one fights" {
    collision = floor_collision();
    state = CombatState(game="q3");
    parts = arena_pair(tester());
    world = parts[0];
    bot = parts[1];
    rival = parts[2];
    # Only a machine gun: BotWantsToRetreat, but with no goal to retreat to
    # (AIEnter_Battle_SuicidalFight) it fights in place.
    bot.foe = rival;
    think(world, collision, state, 0.1);
    assert bot.bot_state.enemy is rival and bot.bot_state.ainode == "battle_fight";
    assert bot.bot_state.suicidal and bot.fighting;
    # With a rocket launcher it picks the launcher by its weapon weights.
    bot.inventory spawn AdjustInventory(kind="weapon_rocketlauncher", amount=1, capacity=1);
    bot.inventory spawn AdjustInventory(kind="rockets", amount=10, capacity=200);
    think(world, collision, state, 0.5);
    assert bot.bot_state.ainode == "battle_fight" and bot.fighting and bot.weapon_slot == 5;
    # With rockets and health to spare it may rocket jump.
    mind = bot.character;
    assert mind is not None and bot_travel_flags(bot, mind, 0) & TFL_ROCKETJUMP;
}

test "a bot that killed its enemy says so, standing while it types" {
    collision = floor_collision();
    state = CombatState(game="q3");
    parts = arena_pair(tester());
    world = parts[0];
    bot = parts[1];
    rival = parts[2];
    contest = parts[3];
    bot.inventory spawn AdjustInventory(kind="weapon_rocketlauncher", amount=1, capacity=1);
    bot.inventory spawn AdjustInventory(kind="rockets", amount=10, capacity=200);
    bot.foe = rival;
    # Past the game-enter chat window.
    think(world, collision, state, 0.1);
    mind = bot.character;
    assert mind is not None;
    mind.chat_state.last_chat = -1000.0;
    think(world, collision, state, 0.3);
    assert bot.bot_state.ainode == "battle_fight";
    rival.health = 0;
    bot.foe = None;
    contest.announce_death(rival, bot, "plasmagun");
    think(world, collision, state, 0.3);
    assert bot.bot_state.last_killed_player is rival and bot.bot_state.enemy_death_time > 0.0;
    # A second on: kill_praise or kill_insult, typed for two seconds.
    think(world, collision, state, 1.2);
    assert bot.bot_state.ainode == "stand" and not state.messages;
    think(world, collision, state, 2.2);
    assert state.messages == ["Tester^7: ^2Nice one, rival."];
    assert "sound/player/talk.wav" in state.cues;
    assert bot.bot_state.ainode != "stand";
}

test "a dead bot may say what killed it, and respawns once it has" {
    collision = floor_collision();
    state = CombatState(game="q3");
    parts = arena_pair(tester());
    world = parts[0];
    bot = parts[1];
    rival = parts[2];
    contest = parts[3];
    think(world, collision, state, 0.1);
    mind = bot.character;
    assert mind is not None;
    mind.chat_state.last_chat = -1000.0;
    bot.health = 0;
    bot.respawn_wait = 1.7;
    contest.announce_death(bot, rival, "railgun");
    think(world, collision, state, 0.2);
    assert bot.bot_state.ainode == "respawn" and bot.respawn_wait > 100.0;
    # Two seconds of typing, then the line and the respawn (the game's 1.7 s
    # have passed).
    think(world, collision, state, 2.2);
    assert state.messages == ["Tester^7: ^2You got me, rival."];
    assert bot.respawn_wait <= 0.0;
}

"""A strip of eight AAS areas along x in `world`, walkable both ways, with
a heavy armor at its far end (a goal to retreat to)."""
def strip_world(world: World) -> LevelItem {
    walks = [(i, i + 1, TRAVEL_WALK) for i in range(1, 8)] + [(i + 1, i, TRAVEL_WALK) for i in range(1, 8)];
    mesh = build_navmesh(world, strip_aas(8, walks));
    items = BotItems(infos=[ItemInfo(classname="item_armor_body", respawntime=25.0, mins=Vec3(x=-15.0, y=-15.0, z=-15.0), maxs=Vec3(x=15.0, y=15.0, z=15.0))]);
    world +>:HasBotItems:+> items;
    armor = pickup("item_armor_body", "armor", 512.0);
    world +>:HasPickup:+> armor;
    item = add_level_item(items, armor, mesh, CollisionMap(), 0);
    assert item is not None;
    item.linked = True;
    mesh.times_to(item.goal_area);
    return item;
}

test "a retreating bot heads for its goal and aims back only when skilled enough" {
    for skill in [0.2, 0.9] {
        collision = floor_collision();
        state = CombatState(game="q3");
        mind = tester();
        mind.attack_skill = skill;
        parts = arena_pair(mind);
        world = parts[0];
        bot = parts[1];
        rival = parts[2];
        bot.pos = Vec3(x=64.0, z=26.0);
        rival.pos = Vec3(x=-300.0, z=26.0);
        item = strip_world(world);
        bot.foe = rival;
        think(world, collision, state, 0.3);
        memory = bot.bot_state;
        assert memory.ainode == "battle_retreat" and not bot.fighting;
        goal = memory.move_goal;
        assert goal is not None and goal.item is item and bot.arena_goal is not None;
        # AINode_Battle_Retreat aims above 0.3 attack skill, else looks ahead.
        assert (memory.view_mode == "enemy") == (skill > 0.3);
    }
}

test "a keen bot chases an enemy out of sight to where it was last seen" {
    collision = floor_collision();
    state = CombatState(game="q3");
    parts = arena_pair(tester());
    world = parts[0];
    bot = parts[1];
    rival = parts[2];
    bot.pos = Vec3(x=64.0, z=26.0);
    rival.pos = Vec3(x=320.0, z=26.0);
    strip_world(world);
    bot.inventory spawn AdjustInventory(kind="weapon_rocketlauncher", amount=1, capacity=1);
    bot.inventory spawn AdjustInventory(kind="rockets", amount=10, capacity=200);
    bot.foe = rival;
    think(world, collision, state, 0.3);
    assert bot.bot_state.ainode == "battle_fight" and bot.bot_state.last_enemy_area == 5;
    collision.add_box(Vec3(x=200.0, y=-2000.0, z=0.0), Vec3(x=220.0, y=2000.0, z=6000.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    think(world, collision, state, 0.1);
    memory = bot.bot_state;
    assert memory.ainode == "battle_chase" and memory.view_mode == "chase";
    goal = memory.move_goal;
    assert goal is not None and goal.area == 5 and memory.goal_area == 5;
}
