"""Q3 bots and what stands in their way (ai_dmq3.c BotAIPredictObstacles,
BotGetActivateGoal, BotAIBlocked; be_ai_move.c BotCheckBlocked)."""
import from engine.formats.aas { Aas, AREACONTENTS_MOVER, TRAVEL_WALK, TFL_DEFAULT }
import from engine.formats.bsp { Bsp, Model, MapEntity }
import from engine.formats.botconfig { ItemInfo }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, arm_bot }
import from engine.world.arena { ArenaMatch, HasMatch, Competes }
import from engine.world.doors { Door, HasDoor }
import from engine.world.signals { Signal, Targets }
import from engine.world.triggers { TouchTrigger, HasTrigger, TriggerTick }
import from engine.world.pickups { Pickup, PickupRule, HasPickup }
import from engine.world.bot_routes { NavMesh, BotRoute, build_navmesh, predict_mover, plan_route, UNREACHED }
import from engine.world.bot_travel { FollowRoute, TravelResult, check_blocked }
import from engine.world.bot_goals { BotItems, HasBotItems, BotGoal, add_level_item }
import from engine.world.bot_character { BotCharacter, ActivateGoal, ActivateState }
import from engine.world.bot_obstacles { FindActivator, activate_weapon }
import from engine.world.bot_ai { BotTactics, BotThink, bot_brain }
import from engine.world.level { Level }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }
import from games.weapons { weapon_rules }
import from tests.bot_travel_tests { strip_aas }
import from tests.bot_ai_tests { tester, floor_collision }

"""Eight areas in a row, walked both ways, with area 5 inside the door with
BSP model 1."""
def door_strip() -> Aas {
    walks = [(i, i + 1, TRAVEL_WALK) for i in range(1, 8)] + [(i + 1, i, TRAVEL_WALK) for i in range(1, 8)];
    aas = strip_aas(8, walks);
    aas.areas[5].contents = AREACONTENTS_MOVER | (1 << 24);
    return aas;
}

"""The map of the door strip: a door (model 1, named "gate") across area 5
and a button (model 2) in area 2, pressed toward -x, that fires the relay
"relay", which opens the door. `health` makes the button one to shoot."""
def door_map(health: str = "0") -> Bsp {
    return Bsp(
        game="q3",
        models=[
            Model(head=0, first_face=0, face_count=0),
            Model(head=0, first_face=0, face_count=0, mins=Vec3(x=300.0, y=-32.0, z=0.0), maxs=Vec3(x=316.0, y=32.0, z=96.0)),
            Model(head=0, first_face=0, face_count=0, mins=Vec3(x=120.0, y=-16.0, z=20.0), maxs=Vec3(x=128.0, y=16.0, z=60.0))
        ],
        entities=[
            MapEntity(fields={"classname": "worldspawn"}),
            MapEntity(fields={"classname": "func_door", "model": "*1", "targetname": "gate"}),
            MapEntity(fields={"classname": "target_relay", "targetname": "relay", "target": "gate"}),
            MapEntity(fields={"classname": "func_button", "model": "*2", "target": "relay", "angle": "180", "health": health})
        ]
    );
}

"""The door and button of door_map as the level loads them: the button's
signal fires the relay's, which fires the door's."""
def door_world(world: World) -> Door {
    box = AABB(mins=Vec3(), maxs=Vec3());
    door = Door(model=1, trigger=box, travel=Vec3(z=96.0), speed=100.0, hold_time=2.0, automatic=False);
    door.activation = Signal(entities=[1]);
    button = Door(model=2, trigger=box, travel=Vec3(x=-4.0), speed=40.0, hold_time=1.0, kind="button");
    button.activation = Signal(entities=[3]);
    relay = Signal(entities=[2], relay=True);
    button.activation +>:Targets:+> relay;
    relay +>:Targets:+> door.activation;
    world +>:HasDoor:+> door;
    world +>:HasDoor:+> button;
    return door;
}

def find_activator(world: World, bsp: Bsp, mesh: NavMesh, top: ActivateGoal | None = None) -> FindActivator {
    return world spawn FindActivator(
        model=1,
        bsp=bsp,
        collision=CollisionMap(),
        mesh=mesh,
        origin=Vec3(x=64.0),
        eye=Vec3(x=64.0, z=26.0),
        area=1,
        flags=TFL_DEFAULT,
        now=100.0,
        top=top
    );
}

test "a route is predicted up to the mover it runs into, and keeps out of areas closed to routing" {
    mesh = build_navmesh(World(), door_strip());
    opened = mesh.times_to(8);
    assert opened[1] < UNREACHED;
    # AAS_PredictRoute: the route from area 1 to area 8 enters the door's.
    assert predict_mover(mesh, 1, Vec3(x=64.0), 8, TFL_DEFAULT) == 1;
    assert predict_mover(mesh, 1, Vec3(x=64.0), 3, TFL_DEFAULT) == 0;
    assert predict_mover(mesh, 6, Vec3(x=384.0), 8, TFL_DEFAULT) == 0;
    # AAS_EnableRoutingArea: closed, nothing routes through it.
    assert mesh.enable_area(5, False) and 5 in mesh.disabled;
    shut = mesh.times_to(8);
    assert shut[1] >= UNREACHED and shut[6] < UNREACHED;
    assert not plan_route(mesh, Vec3(x=64.0), Vec3(x=512.0)).found;
    mesh.times_to(3);
    assert plan_route(mesh, Vec3(x=64.0), Vec3(x=192.0)).found;
    # Open again, the tables built before it shut serve as they were.
    assert not mesh.enable_area(5, True) and 5 not in mesh.disabled;
    assert mesh.times_to(8) is opened;
    assert plan_route(mesh, Vec3(x=64.0), Vec3(x=512.0)).found;
}

test "a bot finds the button behind a relay that opens the door in its way" {
    world = World();
    mesh = build_navmesh(world, door_strip());
    door = door_world(world);
    bsp = door_map();
    search = find_activator(world, bsp, mesh);
    found = search.found;
    # The button entity, to be walked into from its +x side, in area 2.
    assert search.entity == 3 and found.entity == 2 and not found.shoot;
    assert found.goal.area == 2 and abs(found.goal.origin.x - 124.0) < 0.001 and abs(found.goal.origin.z - 40.0) < 0.001;
    assert abs(found.goal.maxs.x - 5.0) < 0.001 and abs(found.goal.mins.x + 4.0) < 0.001;
    # The door's areas are closed to routing, and the bot has the travel
    # time to the button and five seconds more.
    assert found.areas == [5] and found.areas_disabled and 5 in mesh.disabled;
    assert found.time > 105.0 and found.time < 107.0;
    found.enable_areas(mesh, True);
    assert 5 not in mesh.disabled;
    # A button it has been at for over two seconds is passed over.
    stale = ActivateGoal(goal=found.goal, entity=2, time=110.0, start_time=97.0);
    again = find_activator(world, bsp, mesh, stale);
    assert again.entity == 0;
    again.found.enable_areas(mesh, True);
    # An open door needs nothing, nor does one that opens by itself.
    door.position = 1.0;
    door.state = "open";
    assert find_activator(world, bsp, mesh).entity == 0 and not mesh.disabled;
    door.position = 0.0;
    door.state = "closed";
    bsp.entities[1].fields.pop("targetname");
    assert find_activator(world, bsp, mesh).entity == 0 and not mesh.disabled;
}

test "a button with health is shot from where the bot sees it, a door with health at its middle" {
    world = World();
    mesh = build_navmesh(world, door_strip());
    door_world(world);
    bsp = door_map("5");
    search = find_activator(world, bsp, mesh);
    found = search.found;
    # The button's face is in sight: the bot shoots from where it stands.
    assert search.entity == 3 and found.shoot and found.entity == 2 and found.goal.area == 1;
    assert abs(found.target.x - 128.0) < 0.001 and abs(found.target.z - 40.0) < 0.001;
    found.enable_areas(mesh, True);
    # BotFuncDoorActivateGoal.
    bsp.entities[1].fields["health"] = "20";
    shot = find_activator(world, bsp, mesh);
    assert shot.entity == 1 and shot.found.shoot and shot.found.entity == 1;
    assert abs(shot.found.target.x - 308.0) < 0.001 and abs(shot.found.target.z - 48.0) < 0.001;
    assert not mesh.disabled;
    # BotSelectActivateWeapon: the machine gun first, the BFG last.
    assert activate_weapon([1, 2, 5]) == 2 and activate_weapon([1, 5, 9]) == 5 and activate_weapon([1, 4]) == -1;
}

def spot_goal() -> BotGoal {
    return BotGoal(origin=Vec3(), area=1);
}

test "the activate stack keeps what a bot is going for and what it just let go" {
    mesh = build_navmesh(World(), door_strip());
    stack = ActivateState();
    task = ActivateGoal(goal=spot_goal(), entity=2, time=20.0, areas=[5]);
    task.enable_areas(mesh, False);
    assert stack.push(task) and stack.top() is task and 5 in mesh.disabled;
    assert stack.going_to(2, 10.0) and not stack.going_to(2, 21.0) and not stack.going_to(7, 10.0);
    # Popped, its door's areas are routed through again; for two seconds
    # the bot still counts as going for it.
    assert stack.pop(mesh, 30.0) and stack.top() is None and 5 not in mesh.disabled;
    assert stack.going_to(2, 31.0) and not stack.going_to(2, 32.5);
    assert not stack.pop(mesh, 33.0);
    for i in range(8) {
        assert stack.push(ActivateGoal(goal=spot_goal(), entity=10 + i));
    }
    assert not stack.push(ActivateGoal(goal=spot_goal(), entity=99));
    stack.clear(mesh, 40.0);
    assert stack.top() is None;
}


"""A wall of the mover with BSP model 9 two units ahead of the origin along
+x, on the open floor."""
def mover_ahead() -> CollisionMap {
    collision = floor_collision();
    collision.models.append(0);
    collision.add_box(Vec3(x=2.0, y=-64.0, z=-64.0), Vec3(x=40.0, y=64.0, z=128.0), Vec3(), Vec3(), Vec3());
    collision.models.append(9);
    collision.reindex();
    return collision;
}

test "BotCheckBlocked: a mover or another player within 3 units along the move blocks it" {
    collision = mover_ahead();
    result = TravelResult();
    check_blocked(collision, Vec3(), Vec3(x=1.0), [], result);
    assert result.blocked and result.block_model == 9;
    # The world itself never blocks, nor does a mover out of reach.
    clear = TravelResult();
    check_blocked(collision, Vec3(), Vec3(x=-1.0), [], clear);
    assert not clear.blocked;
    # Another player's box 3 units on.
    bumped = TravelResult();
    check_blocked(floor_collision(), Vec3(), Vec3(y=1.0), [Vec3(y=32.0)], bumped);
    assert bumped.blocked and bumped.block_model == 0;
    apart = TravelResult();
    check_blocked(floor_collision(), Vec3(), Vec3(y=1.0), [Vec3(y=40.0)], apart);
    assert not apart.blocked;
}

test "a blocked leg runs out ten times as fast, and a bot on a mover without reachabilities is on top of an obstacle" {
    walks = [(1, 2, TRAVEL_WALK), (2, 1, TRAVEL_WALK)];
    mesh = build_navmesh(World(), strip_aas(2, walks));
    mesh.times_to(2);
    collision = mover_ahead();
    bot = Opponent(arena=True, health=100, pos=Vec3(z=26.0), eye_height=26.0, grounded=True);
    route = plan_route(mesh, Vec3(), Vec3(x=128.0));
    assert route.found;
    route.leg_started = 10.0;
    travel = bot spawn FollowRoute(mesh=mesh, collision=collision, route=route, eye_height=26.0, clock=10.0, dt=0.1);
    assert travel.result.blocked and travel.result.block_model == 9 and not travel.result.on_top;
    assert abs(route.leg_started - 9.0) < 0.0001;
    # Standing on a mover: the areas here have reachabilities, so it rides.
    under = CollisionMap();
    under.add_box(Vec3(x=-64.0, y=-64.0, z=-8.0), Vec3(x=64.0, y=64.0, z=0.0), Vec3(), Vec3(), Vec3());
    under.models.append(7);
    under.reindex();
    riding = bot spawn FollowRoute(mesh=mesh, collision=under, route=plan_route(mesh, Vec3(), Vec3(x=128.0)), eye_height=26.0, clock=10.0, dt=0.1);
    assert not riding.result.blocked;
    # With none under it the bot is on top of an obstacle and stands.
    mesh.aas.areas[1].reach_count = 0;
    stuck = bot spawn FollowRoute(mesh=mesh, collision=under, route=route, eye_height=26.0, clock=10.0, dt=0.1);
    assert stuck.result.blocked and stuck.result.on_top and stuck.result.block_model == 7 and stuck.result.speed == 0.0;
    # On another player's head.
    mesh.aas.areas[1].reach_count = 1;
    perched = bot spawn FollowRoute(mesh=mesh, collision=floor_collision(), route=route, eye_height=26.0, clock=10.0, dt=0.1, bodies=[Vec3(z=-56.0)]);
    assert perched.result.blocked and perched.result.on_top and perched.result.block_model == 0;
}

"""A bot alone in a match on the door strip's floor."""
def lone_bot(world: World) -> Opponent {
    bot = Opponent(arena=True, health=100, pos=Vec3(x=64.0, z=26.0), eye_height=26.0, grounded=True, character=tester());
    arm_bot(bot);
    world +>:HasOpponent:+> bot;
    contest = ArenaMatch();
    world +>:HasMatch:+> contest;
    contest +>:Competes(name="Tester"):+> bot;
    return bot;
}

"""The move a bot's last think made round an obstacle."""
def detour_of(bot: Opponent) -> Vec3 {
    step = bot.bot_state.detour;
    if step is None {
        raise ValueError("no detour");
    }
    return step;
}

test "BotAIBlocked sidesteps what blocks the bot, to the other side when it cannot, and gives a goal up after 0.4 s" {
    world = World();
    bot = lone_bot(world);
    bot.pos = Vec3(z=26.0);
    mind = bot.character;
    assert mind is not None;
    collision = floor_collision();
    # A wall along the bot's right (-y): no step that way.
    collision.add_box(Vec3(x=-200.0, y=-60.0, z=0.0), Vec3(x=200.0, y=-20.0, z=128.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    memory = bot.bot_state;
    brain = bot_brain(world);
    seeking = brain.nodes["seek_ltg"];
    thinker = BotThink(bot=bot, mind=mind, memory=memory, collision=collision, rules=weapon_rules("q3"), now=5.0, human=Player(), state=CombatState(game="q3"));
    # Not blocked: the time is noted.
    thinker.ai_blocked(seeking, True);
    assert memory.notblocked_time == 5.0 and memory.detour is None;
    # Blocked by another player moving along +x: the first side is
    # CrossProduct(hordir, up), -y, into the wall; so the other way round
    # from now on, this time to the same side and backwards.
    memory.travel = TravelResult(direction=Vec3(x=1.0), blocked=True);
    memory.ltg_time = 99.0;
    thinker.now = 5.1;
    thinker.ai_blocked(seeking, True);
    assert memory.avoid_right and memory.detour is None and memory.ltg_time == 99.0;
    thinker.now = 5.2;
    thinker.ai_blocked(seeking, True);
    detour = detour_of(bot);
    assert abs(detour.y - 1.0) < 0.001 and abs(detour.x) < 0.001;
    # Still blocked 0.4 s after it last was not: the long-term goal goes.
    thinker.now = 5.5;
    thinker.ai_blocked(seeking, True);
    assert memory.ltg_time == 0.0;
    # Stuck in solid: any direction (BotRandomMove).
    memory.detour = None;
    memory.travel = TravelResult(blocked=True, in_solid=True, failure=True);
    thinker.ai_blocked(seeking, True);
    assert abs(detour_of(bot).length() - 1.0) < 0.001;
}

test "a bot whose route runs into a shut door goes and presses its button first" {
    world = World();
    mesh = build_navmesh(world, door_strip());
    door_world(world);
    level = Level(active=True, bsp=door_map());
    items = BotItems(infos=[ItemInfo(classname="item_armor_body", respawntime=25.0, mins=Vec3(x=-15.0, y=-15.0, z=-15.0), maxs=Vec3(x=15.0, y=15.0, z=15.0))]);
    world +>:HasBotItems:+> items;
    armor = Pickup(pos=Vec3(x=512.0), rule=PickupRule(kind="armor", amount=25, capacity=200, model="", classname="item_armor_body"));
    world +>:HasPickup:+> armor;
    item = add_level_item(items, armor, mesh, CollisionMap(), 0);
    assert item is not None and item.goal_area == 8;
    item.linked = True;
    mesh.times_to(8);
    bot = lone_bot(world);
    collision = floor_collision();
    state = CombatState(game="q3");
    rules = weapon_rules("q3");
    human = Player(health=0, pos=Vec3(x=9000.0));
    world spawn BotTactics(player=human, collision=collision, state=state, rules=rules, dt=0.1, level=level);
    memory = bot.bot_state;
    # BotAIPredictObstacles in Seek_LTG: on to AINode_Seek_ActivateEntity.
    task = memory.obstacles.top();
    assert memory.ainode == "seek_activate" and task is not None and task.entity == 2 and not task.shoot;
    assert memory.move_goal is task.goal and memory.goal_area == 2 and 5 in mesh.disabled;
    assert abs(task.start_time - memory.clock) < 0.2 and task.time > task.start_time + 5.0;
    # Touching the button's box: done, the door's areas open to routing
    # again, and back by the nearby-goal node to the long-term goal.
    bot.pos = Vec3(x=140.0, z=26.0);
    world spawn BotTactics(player=human, collision=collision, state=state, rules=rules, dt=0.1, level=level);
    assert memory.obstacles.top() is None and 5 not in mesh.disabled;
    assert memory.ainode == "seek_ltg" and memory.obstacles.going_to(2, memory.clock);
    # A dead bot lets its activate goals go.
    held = ActivateGoal(goal=task.goal, entity=2, time=1000.0, areas=[5]);
    held.enable_areas(mesh, False);
    memory.obstacles.push(held);
    memory.ainode = "seek_activate";
    bot.health = 0;
    world spawn BotTactics(player=human, collision=collision, state=state, rules=rules, dt=0.1, level=level);
    assert memory.ainode == "respawn" and memory.obstacles.top() is None and 5 not in mesh.disabled;
}

test "a Q3 trigger fires for an arena bot standing in it" {
    world = World();
    volume = CollisionMap(hull_mins=Vec3(), hull_maxs=Vec3());
    volume.add_box(Vec3(x=-32.0, y=-32.0, z=-32.0), Vec3(x=32.0, y=32.0, z=64.0), Vec3(), Vec3(), Vec3());
    volume.reindex();
    trigger = TouchTrigger(model=4, volume=volume, interval=2.0);
    world +>:HasTrigger:+> trigger;
    bot = Opponent(arena=True, health=100, pos=Vec3(x=500.0, z=26.0), eye_height=26.0);
    world +>:HasOpponent:+> bot;
    far = Vec3(x=9000.0);
    world spawn TriggerTick(start=far, finish=far, dt=0.1);
    assert trigger.activations == 0;
    bot.pos = Vec3(z=26.0);
    world spawn TriggerTick(start=far, finish=far, dt=0.1);
    assert trigger.activations == 1 and trigger.cooldown == 2.0;
    # A campaign monster does not (only Q2's MONSTER triggers do).
    trigger.cooldown = 0.0;
    bot.arena = False;
    world spawn TriggerTick(start=far, finish=far, dt=0.1);
    assert trigger.activations == 1;
}
