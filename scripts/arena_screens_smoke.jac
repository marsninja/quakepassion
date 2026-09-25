"""Q3 arena presentation captures on q3dm7: the scoreboard with heads, skill
marks and awards; a bot beside a wall lit from the light grid and, for
comparison, full bright as before; a body left behind and its gibs once shot
apart; items thrown from a dying bot in flight and landed; the five-skill
settings row; and the postgame menu's three phases over the podium. Run
with HOME pointing somewhere disposable (the postgame logs career awards
there) and QP_GAME=q3 QP_ASSETS=<baseq3>."""
import math;
import from engine.core.menu { game_directory }
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World, Player, Entity, Area, move_to_area }
import from engine.world.combat { Opponent, HasOpponent, CombatTick, ProjectileTick, damage_opponent }
import from engine.world.arena { MatchTick, Competes, match_of, join_match }
import from engine.world.arena_navigation { ArenaNavigationTick, ArenaContactIndex, prepare_arena_links }
import from engine.world.bot_tactics { BotTactics }
import from engine.world.pickups { PickupTick, Pickup, HasPickup }
import from engine.world.powerups { GrantPowerup }
import from engine.world.inventory { AdjustInventory }
import from engine.world.models { PlayerRig }
import from engine.world.body_queue { Corpse, HasCorpse, damage_corpse }
import from engine.world.drops { TossTick, in_flight }
import from engine.world.gibs { Gib, HasGib, GibTick }
import from games.opponents { populate_opponents }
import from games.items { populate_pickups }
import from games.weapons { equip_player }
import from engine.math.vec3 { Vec3 }
import from engine.physics.collision { CollisionMap }

"""A camera spot `reach` from `middle` with a clear view of it, looking at
it, or None."""
def camera_at(collision: CollisionMap, middle: Vec3, start: float, reach: float) -> list[Vec3] | None {
    for step in range(12) {
        angle = start + float(step) * math.pi / 6.0;
        spot = middle.add(Vec3(x=math.cos(angle) * reach, y=math.sin(angle) * reach, z=16.0));
        ray = collision.trace_point(middle, spot);
        if ray.start_solid or ray.fraction < 1.0 {
            continue;
        }
        toward = middle.sub(spot);
        flat = math.sqrt(toward.x * toward.x + toward.y * toward.y);
        return [spot, Vec3(x=math.atan2(toward.y, toward.x), y=math.atan2(toward.z, flat))];
    }
    return None;
}

def shoot(app: App, name: str) {
    for frame in range(3) {
        app.render_frame();
    }
    app.renderer.screenshot(name);
    print("CAPTURE", name);
}

def look(app: App, collision: CollisionMap, middle: Vec3, start: float, reach: float, name: str) -> bool {
    view = camera_at(collision, middle, start, reach);
    if view is None {
        return False;
    }
    app.player.pos = view[0];
    app.player.yaw = view[1].x;
    app.player.pitch = view[1].y;
    shoot(app, name);
    return True;
}

def tick_world(app: App, player: Player, contacts: ArenaContactIndex, seconds: float) {
    world = app.world;
    level = app.level;
    dt = 1.0 / 120.0;
    contest = match_of(world);
    for tick in range(int(seconds * 120.0)) {
        world spawn PickupTick(player=player, start=player.pos, finish=player.pos, dt=dt);
        world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt);
        world spawn CombatTick(player=player, collision=level.collision, state=app.combat, dt=dt, arena_live=True);
        world spawn BotTactics(player=player, collision=level.collision, state=app.combat, rules=app.combat.rules, dt=dt);
        world spawn ProjectileTick(player=player, collision=level.collision, state=app.combat, dt=dt);
        world spawn TossTick(collision=level.collision, dt=dt);
        world spawn GibTick(collision=level.collision, dt=dt);
        world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt, contacts=True);
        if contest is not None and not contest.finished {
            contest spawn MatchTick(dt=dt);
        }
        app.simulation_time += dt;
    }
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    world = World();
    level = load_level(world, game_directory("q3"), "q3dm7", "q3");
    populate_pickups(world, level, game_directory("q3"));
    populate_opponents(world, level, game_directory("q3"));
    prepare_arena_links(world, level.collision);
    contest = match_of(world);
    assert contest is not None;
    contest.warmup = 0.0;
    contest.fraglimit = 1000;
    human = spawn_player(level);
    human.god_mode = True;
    app = App(world=world, player=human, level=level, renderer=renderer, clock=Clock(), culling=False, overlay=False, walking=True);
    join_match(world, human);
    equip_player(human, app.combat, "q3");
    app.quake.upload(level);
    app.models.upload(world);
    app.prepare_presentation();
    assert app.hud.ready and app.hud.has_pic("tab_score") and app.hud.has_pic("font_prop");
    bots = [bot for bot in [world->:HasOpponent:->][?:Opponent] if bot.arena];
    for bot in bots {
        rig = bot.visual;
        assert isinstance(rig, PlayerRig) and app.hud.has_pic("icon:" + rig.character);
    }
    contacts = ArenaContactIndex();
    tick_world(app, human, contacts, 40.0);
    # Awards to show on the scoreboard lines.
    entries = [edge contest->:Competes:->];
    entries[0].excellent += 2;
    entries[1].impressive += 1;
    entries[-1].humiliation += 3;
    entries[-1].excellent += 1;
    app.show_scores = True;
    shoot(app, "qp_arena_scoreboard.png");
    app.show_scores = False;

    # A bot beside a wall, lit from the light grid, then full bright.
    subject = bots[0];
    for bot in bots {
        if bot.health > 0 {
            subject = bot;
        }
    }
    middle = subject.pos.sub(Vec3(z=subject.eye_height * 0.5));
    if look(app, level.collision, middle, subject.yaw + math.pi / 4.0, 90.0, "qp_arena_bot_lit.png") {
        grid = level.lighting.grid;
        level.lighting.grid = None;
        shoot(app, "qp_arena_bot_fullbright.png");
        level.lighting.grid = grid;
        lit = level.lighting.sample(subject.pos.sub(Vec3(z=10.0)));
        print("LIGHT at bot", round(lit.ambient.x, 3), round(lit.ambient.y, 3), round(lit.ambient.z, 3),
            "directed", round(lit.directed.x, 3), round(lit.directed.y, 3), round(lit.directed.z, 3));
    }

    # A bot dies holding a railgun and a quad: its drops are thrown.
    victim = subject;
    victim.inventory spawn AdjustInventory(kind="weapon_railgun", amount=1, capacity=1);
    victim.inventory spawn AdjustInventory(kind="slugs", amount=10, capacity=200);
    victim.shown_weapon = "railgun";
    victim spawn GrantPowerup(kind="quad", duration=30.0);
    damage_opponent(victim, 1000, attacker=bots[-1] if bots[-1] is not victim else bots[0], means="railgun");
    tick_world(app, human, contacts, 0.2);
    thrown = [item for item in [world->:HasPickup:->][?:Pickup] if item.dropped];
    print("THROWN", len(thrown), [in_flight(item) for item in thrown]);
    if thrown {
        look(app, level.collision, thrown[0].pos, victim.yaw + math.pi / 2.0, 140.0, "qp_arena_drop_flying.png");
        tick_world(app, human, contacts, 1.5);
        print("LANDED", [in_flight(item) for item in thrown], [round(item.pos.z, 1) for item in thrown]);
        look(app, level.collision, thrown[0].pos, victim.yaw + math.pi / 2.0, 120.0, "qp_arena_drop_landed.png");
    }
    # The body stays when the bot respawns; shot apart, it bursts into gibs.
    tick_world(app, human, contacts, 1.8);
    bodies = [world->:HasCorpse:->][?:Corpse];
    if bodies {
        body = bodies[-1];
        spot = body.pos.sub(Vec3(z=body.eye_height));
        look(app, level.collision, spot.add(Vec3(z=4.0)), body.yaw + math.pi / 3.0, 110.0, "qp_arena_corpse.png");
        assert damage_corpse(world, body, 100);
        tick_world(app, human, contacts, 0.25);
        print("GIBS", len([world->:HasGib:->][?:Gib]));
        look(app, level.collision, spot.add(Vec3(z=4.0)), body.yaw + math.pi / 3.0, 130.0, "qp_arena_gibbed.png");
    }

    # The skill row at its fifth step.
    app.skill = 4;
    app.menu.opened = True;
    app.menu.settings_open = True;
    app.menu.setting_selected = 10;
    shoot(app, "qp_arena_skill_menu.png");
    app.menu.opened = False;

    # The player wins; the podium and postgame menu follow.
    for score in [edge contest->:Competes:->] {
        if score.human {
            score.frags = contest.fraglimit;
            score.deaths = 0;
            score.impressive = 2;
            score.excellent = 3;
            score.humiliation = 1;
        }
    }
    app.combat.accuracy_shots = 40;
    app.combat.accuracy_hits = 27;
    contest.finished = True;
    app.begin_podium(contest);
    board = app.postgame;
    assert board is not None;
    print("MEDALS", board.medals, board.amounts);
    app.postgame_clock = 2.0;
    board.update(app.postgame_clock);
    shoot(app, "qp_arena_postgame_podium.png");
    app.postgame_clock = 6.5;
    board.update(app.postgame_clock);
    shoot(app, "qp_arena_postgame_awards.png");
    app.postgame_clock = 30.0;
    board.update(app.postgame_clock);
    assert board.phase == 3;
    shoot(app, "qp_arena_postgame_menu.png");
    app.models.close();
    app.quake.close();
    renderer.close();
    print("ARENA SCREENS PASS");
}
