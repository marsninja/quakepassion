import from games.passion.supplies {
    supply_rule,
    health_after,
    progression_weapon,
    fight_rounds,
    ammo_class
}
import from games.passion.experience {
    Experience,
    Encounter,
    CombatPosition,
    Reward,
    Stages,
    HoldsPosition,
    Supplies,
    ReviewExperience,
    experience_measures,
    encounters,
    clear_sight,
    body_clear,
    detail_boxes
}
import from games.passion.critic { critic_score }
import from games.passion.massing { Massing }
import from games.passion.spaces { Space, Doorway }
import from games.passion.arrange { Estate, Encloses, Corridor }
import from games.passion.mission { Expedition, Beat, Holds, Link }
import from games.passion.progression { validate_progression, locks_realised }
import from games.passion.dress { plain_box }
import from games.passion.generate { survey }
import from games.passion.cast { Director3 }
import from games.passion.random { stream_for }
import from games.weapons { lead_game }
import from engine.world.objectives { Objective }
import from engine.world.player_bot { PlayerBot, AutoThink }
import from engine.world.bot_routes { build_navmesh, BotRoute }
import from engine.world.world { World, Player }
import from engine.world.level { Level }
import from engine.world.combat { CombatState }
import from engine.world.doors { Door, HasDoor }
import from engine.math.aabb { AABB }
import from engine.formats.aas { AREACONTENTS_MOVER, TRAVEL_WALK }
import from tests.bot_fixtures { strip_aas }
import from engine.math.vec3 { Vec3 }
import from editor.formats.map { MapItem }

test "supply forecasts use the actual game pickup and health cap" {
    assert health_after(60.0, supply_rule("q2", "item_health")) == 70.0;
    assert health_after(60.0, supply_rule("q3", "item_health_small")) == 65.0;
    assert health_after(60.0, supply_rule("q1", "item_health", "1")) == 75.0;
    assert health_after(95.0, supply_rule("q2", "item_health_large")) == 100.0;
    assert health_after(100.0, supply_rule("q3", "item_health_small")) == 105.0;
}

test "each planned weapon has a real matching ammunition pickup" {
    for source in ["q1", "q2", "q3"] {
        ammo: set[str] = set();
        for tier in range(3) {
            weapon = progression_weapon(source, tier);
            rule = supply_rule(source, ammo_class(source, weapon.ammo));
            assert rule.kind == weapon.ammo and rule.amount > 0;
            assert supply_rule(source, "weapon_" + weapon.key).ammo == weapon.ammo;
            ammo.add(rule.kind);
            assert fight_rounds(weapon, 600) > 0;
        }
        assert len(ammo) >= 2;
    }
    # A reward from another game cannot change the generator's starting kit.
    assert lead_game(["q3", "q3", "q3", "q1"], "q1") == "q1";
    assert lead_game(["q2"], "unknown") == "q2";
}

test "the experience walker detects false recovery and unsafe supplies" {
    experience = Experience();
    quiet = Encounter(room=0, order=0, pattern="quiet", quiet=True, foes=1);
    fight = Encounter(
        room=1,
        order=1,
        pattern="crossfire",
        foes=2,
        ammo_ready=0,
        ammo_needed=20,
        health_after=10.0
    );
    experience +>:Stages:+> quiet;
    experience +>:Stages:+> fight;
    position = CombatPosition(
        point=[300.0, 300.0, 24.0],
        role="ranged",
        foe="monster_army",
        sees_entry=True,
        cover=1
    );
    fight +>:HoldsPosition:+> position;
    review = experience spawn ReviewExperience();
    assert review.quiet_violations == 1 and review.supplied == 0 and review.lanes == 1;
    unsafe = experience_measures(experience);
    quiet.foes = 0;
    fight.ammo_ready = 20;
    fight.health_after = 50.0;
    safe = experience_measures(experience);
    assert critic_score(safe) > critic_score(unsafe);
}

test "thin decoration blocks a firing lane and a body's placement" {
    mass = Massing(nx=20, ny=20, nz=12);
    mass.carve(1, 1, 1, 19, 19, 10, 0);
    one = [80.0, 160.0, 40.0];
    two = [400.0, 160.0, 40.0];
    assert clear_sight(mass, one, two);
    boxes = detail_boxes(
        [
            plain_box(
                Vec3(x=200.0, y=148.0, z=16.0),
                Vec3(x=208.0, y=172.0, z=120.0),
                "wall",
                1.0
            )
        ]
    );
    assert not clear_sight(mass, one, two, boxes);
    assert not body_clear([208.0, 160.0, 40.0], boxes);
    assert body_clear([256.0, 160.0, 40.0], boxes);
}

test "pickups can occupy a walk kept clear of blocking enemies" {
    mass = Massing(nx=14, ny=14, nz=14);
    mass.carve(2, 2, 2, 10, 10, 10, 0);
    room = Space(id=0, x=2, y=2, z=2, w=8, d=8, h=8, stage=[5, 5, 2]);
    room.kept = [[x, y, 2] for x in range(2, 10) for y in range(2, 10)];
    director = Director3(
        estate=Estate(),
        mass=mass,
        plan=Expedition(seed=1),
        dice=stream_for(1, "supplies")
    );
    ground = director.ground(room);
    assert not ground.spots and len(ground.supply_spots) == 63;
    encounter = Encounter(
        room=0, order=0, pattern="quiet", quiet=True, approach=[176.0, 176.0, 56.0]
    );
    reward = director.pack(room, encounter, "q2", "ammo_shells");
    assert reward is not None and reward.kind == "shells" and not encounter.issues;
    assert reward.point != encounter.approach;
}

test "objective progress recognises vertical detours without crediting loops" {
    objective = Objective(kind="pickup", point=Vec3(x=1000.0));
    objective.reset_progress(0.0);
    objective.note_progress(500.0, 1, 900, 1.0);
    # Walking away in Euclidean space along a route is still progress.
    objective.note_progress(800.0, 2, 700, 20.0);
    assert objective.nearer_at == 20.0;
    objective.note_progress(900.0, 3, 800, 40.0);
    assert objective.nearer_at == 40.0;
    objective.note_progress(800.0, 2, 700, 60.0);
    objective.note_progress(500.0, 1, 900, 80.0);
    assert objective.nearer_at == 40.0;
    objective.note_progress(450.0, 0, 0, 90.0);
    assert objective.nearer_at == 90.0;
    objective.reset_progress(100.0);
    assert not objective.progress_areas and objective.nearer_at == 100.0;
}

test "a distant lowered plat does not disconnect a partial route" {
    world = World();
    aas = strip_aas(
        8,
        [(i, i + 1, TRAVEL_WALK) for i in range(1, 8)]
            + [(i + 1, i, TRAVEL_WALK) for i in range(1, 8)]
    );
    aas.areas[5].contents = AREACONTENTS_MOVER | (1 << 24);
    mesh = build_navmesh(world, aas);
    player = Player();
    level = Level();
    platform = Door(
        model=1,
        trigger=AABB(mins=Vec3(), maxs=Vec3()),
        travel=Vec3(z=256.0),
        speed=100.0,
        hold_time=2.0,
        kind="platform"
    );
    world +>:HasDoor:+> platform;
    bot = PlayerBot(mesh=mesh, level=level);
    bot.route.add(Vec3(x=128.0), 2);
    bot.route.add(Vec3(x=320.0), 5);
    think = AutoThink(
        bot=bot,
        world=world,
        level=level,
        player=player,
        state=CombatState(),
        origin=Vec3(x=64.0),
        eye_height=22.0
    );
    assert not think.check_movers();
    assert 5 not in mesh.disabled and bot.route.points;
    bot.route.abandon();
    bot.route.add(Vec3(x=320.0), 5);
    assert not think.check_movers();
    assert 5 in mesh.disabled;
}

test "physical progression checks gate wiring and a broken corridor" {
    plan = Expedition(seed=1);
    estate = Estate();
    mass = Massing(nx=42, ny=14, nz=14);
    rooms: list[Space] = [];
    beats: list[Beat] = [];
    for index in range(3) {
        role = ["start", "key", "goal"][index];
        room = Space(
            id=index,
            beat=index,
            role=role,
            x=2 + index * 13,
            y=2,
            z=2,
            w=8,
            d=8,
            h=8,
            stage=[5 + index * 13, 5, 2]
        );
        estate +>:Encloses:+> room;
        mass.carve(room.x, 2, 2, room.x + 8, 10, 10, room.id);
        beat = Beat(id=index, kind=role, grants=["key_silver"] if index == 1 else []);
        plan +>:Holds:+> beat;
        rooms.append(room);
        beats.append(beat);
    }
    routes: list[Corridor] = [];
    for index in range(2) {
        needs = ["key_silver"] if index == 1 else [];
        mode = "locked" if needs else "open";
        beats[index] +>:Link(
            id=index + 1, mode=mode, needs=needs, tail=index, head=index + 1
        ):+> beats[index + 1];
        blocks = [[x, 5, 2] for x in range(10 + index * 13, 15 + index * 13)];
        tail = rooms[index];
        head = rooms[index + 1];
        tail +>:Corridor(
            link=index + 1,
            tail=index,
            head=index + 1,
            mode=mode,
            needs=needs,
            blocks=blocks,
            air=3 + index,
            out_door=Doorway(side=0, along=3, level=2),
            in_door=Doorway(side=1, along=3, level=2)
        ):+> rooms[index + 1];
        routes.append([edge tail->:Corridor:->][0]);
        mass.carve(10 + index * 13, 5, 2, 15 + index * 13, 7, 8, 3 + index);
    }
    gate = MapItem(
        fields={"classname": "func_door", "key": "key_silver", "_mission_link": "2"}
    );
    assert not locks_realised(routes[1], []);
    assert validate_progression(plan, estate, mass, [gate]) == 2;
    mass.fill(11, 5, 2, 12, 7, 8);
    refused = False;
    try {
        validate_progression(plan, estate, mass, [gate]);
    } except AssertionError {
        refused = True;
    }
    assert refused;
}

test "generated experiences keep recovery quiet and supply their fights" {
    for seed in [4, 25, 84, 100] {
        record = survey(seed);
        casting = record.casting;
        plan = record.plan;
        estate = record.estate;
        mass = record.mass;
        assert casting is not None
            and plan is not None
            and estate is not None
            and mass is not None;
        assert not casting.issues , str(seed) + ": " + str(casting.issues);
        measures = experience_measures(casting.experience);
        assert measures["play_quiet_violations"] == 0.0;
        assert measures["play_weapons"] >= 3.0;
        assert measures["play_weapons"] == float(casting.placed_weapons);
        assert measures["play_ammo_types"] >= 2.0;
        assert measures["play_supplied"] == 1.0;
        # A later room or an optional branch cannot fund this fight.
        for encounter in encounters(casting.experience) {
            if encounter.foes == 0 {
                continue;
            }
            local_ammo = sum(
                [
                    reward.amount
                    for reward in [encounter->:Supplies:->][?:Reward]
                    if reward.kind == "shells"
                ]
            );
            assert local_ammo >= encounter.ammo_needed;
            assert encounter.health_before <= 35.0 and encounter.health_after >= 35.0;
        }
        assert record.items[0].fields["_passion_kit"] == casting.lead;
        assert validate_progression(plan, estate, mass, casting.items) > 0;
    }
}
