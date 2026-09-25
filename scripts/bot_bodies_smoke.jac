"""Original arenas: Q3 bots fight with bodies on the three-part rig, and each
pose the audit asked for is captured from beside the bot: running, strafing,
backpedalling, firing with a muzzle flash, aiming up and down, dying, a corpse
left behind after the respawn, a quad damage shell and an item dropped on
death."""
import math;
import from engine.core.menu { game_directory }
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World, Player, Entity }
import from engine.world.combat { Opponent, HasOpponent, CombatTick, ProjectileTick }
import from engine.world.arena { MatchTick, match_of }
import from engine.world.arena_navigation { ArenaNavigationTick, ArenaContactIndex, prepare_arena_links }
import from engine.world.bot_tactics { BotTactics }
import from engine.world.pickups { PickupTick, Pickup, HasPickup }
import from engine.world.powerups { GrantPowerup }
import from engine.world.models { PlayerRig }
import from engine.world.body_queue { Corpse, HasCorpse }
import from engine.world.player_rig {
    ANIM_LEGS_RUN,
    ANIM_LEGS_BACK,
    ANIM_BOTH_DEATH1
}
import from games.opponents { populate_opponents }
import from games.items { populate_pickups }
import from games.weapons { equip_player }
import from engine.math.vec3 { Vec3 }
import from engine.physics.collision { CollisionMap }

"""A camera spot beside `target` with a clear view of it, looking at its
middle, or None."""
def camera_for(collision: CollisionMap, target: Entity, eye_height: float, side: float) -> list[Vec3] | None {
    middle = target.pos.sub(Vec3(z=eye_height * 0.5));
    for step in range(12) {
        angle = target.yaw + side + float(step) * math.pi / 6.0;
        for reach in [110.0, 80.0] {
            spot = middle.add(Vec3(x=math.cos(angle) * reach, y=math.sin(angle) * reach, z=14.0));
            ray = collision.trace_point(middle, spot);
            if ray.start_solid or ray.fraction < 1.0 {
                continue;
            }
            toward = middle.sub(spot);
            flat = math.sqrt(toward.x * toward.x + toward.y * toward.y);
            return [spot, Vec3(x=math.atan2(toward.y, toward.x), y=math.atan2(toward.z, flat))];
        }
    }
    return None;
}

def capture(app: App, collision: CollisionMap, target: Entity, eye_height: float, side: float, name: str) -> bool {
    view = camera_for(collision, target, eye_height, side);
    if view is None {
        return False;
    }
    app.player.pos = view[0];
    app.player.yaw = view[1].x;
    app.player.pitch = view[1].y;
    for frame in range(2) {
        app.render_frame();
    }
    app.renderer.screenshot(name);
    print("CAPTURE", name);
    return True;
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    for name in ["q3dm7", "q3dm1"] {
        world = World();
        level = load_level(world, game_directory("q3"), name, "q3");
        populate_pickups(world, level, game_directory("q3"));
        populate_opponents(world, level, game_directory("q3"));
        prepare_arena_links(world, level.collision);
        contest = match_of(world);
        assert contest is not None;
        contest.warmup = 0.0;
        # The camera is its own dead player. On q3dm7 the bots fight each
        # other; q3dm1's lone Ranger gets an unkillable human to fight.
        camera = Player(health=0, pos=Vec3(z=-100000.0));
        player = Player(health=0, pos=Vec3(z=-100000.0));
        if name == "q3dm1" {
            player = spawn_player(level);
            player.health = 100;
            player.god_mode = True;
        }
        app = App(world=world, player=camera, level=level, renderer=renderer, clock=Clock(), smoke=True, culling=False);
        equip_player(player, app.combat, "q3");
        app.quake.upload(level);
        app.models.upload(world);
        bots = [bot for bot in [world->:HasOpponent:->][?:Opponent] if bot.arena];
        for bot in bots {
            assert isinstance(bot.visual, PlayerRig);
        }
        eye = level.collision.eye_height;
        wanted = ["run", "strafe", "back", "fire", "aim_up", "aim_down", "death", "corpse", "quad", "drop"]
            if name == "q3dm7"
            else ["run", "strafe", "back", "fire"];
        # One bot carries a quad damage, to show its shell (and drop it).
        if name == "q3dm7" {
            bots[0] spawn GrantPowerup(kind="quad", duration=60.0);
        }
        taken: list[str] = [];
        contacts = ArenaContactIndex();
        dt = 1.0 / 120.0;
        tick = 0;
        while tick < 120 * 90 and len(taken) < len(wanted) {
            tick += 1;
            world spawn PickupTick(player=player, start=player.pos, finish=player.pos, dt=dt);
            world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt);
            world spawn CombatTick(player=player, collision=level.collision, state=app.combat, dt=dt, arena_live=True);
            world spawn BotTactics(player=player, collision=level.collision, state=app.combat, rules=app.combat.rules, dt=dt);
            world spawn ProjectileTick(player=player, collision=level.collision, state=app.combat, dt=dt);
            world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt, contacts=True);
            contest spawn MatchTick(dt=dt);
            app.simulation_time += dt;
            # A shot is caught on its own tick, while its flash shows (sampling
            # every few ticks would miss flashes fired in step with them).
            if "fire" not in taken and "fire" in wanted {
                for bot in bots {
                    rig = bot.visual;
                    if isinstance(rig, PlayerRig) and rig.alive and rig.clock - rig.flash_time < 0.005 {
                        if capture(app, level.collision, bot, eye, math.pi / 4.0, "qp_bot_" + name + "_fire.png") {
                            taken.append("fire");
                            print("  tick", tick, "fire", rig.weapon, "battle", bot.bot_state.battle);
                            break;
                        }
                    }
                }
            }
            if tick % 6 != 0 {
                continue;
            }
            for bot in bots {
                rig = bot.visual;
                if not isinstance(rig, PlayerRig) {
                    continue;
                }
                state = "";
                if rig.alive and rig.legs_anim == ANIM_LEGS_BACK {
                    state = "back";
                } elif rig.alive and rig.legs_anim == ANIM_LEGS_RUN and rig.move_dir in [1, 2, 6, 7] {
                    state = "strafe";
                } elif rig.alive and rig.legs_anim == ANIM_LEGS_RUN {
                    state = "run";
                }
                if rig.alive and bot.fighting and bot.pitch > 0.3 and "aim_up" not in taken {
                    state = "aim_up";
                }
                if rig.alive and bot.fighting and bot.pitch < -0.3 and "aim_down" not in taken {
                    state = "aim_down";
                }
                # Mid-fall: a third of a second to a second into the death.
                if not rig.alive and rig.visible
                    and rig.legs_anim in [ANIM_BOTH_DEATH1, ANIM_BOTH_DEATH1 + 2, ANIM_BOTH_DEATH1 + 4]
                    and bot.respawn_wait < 1.35 and bot.respawn_wait > 0.7 {
                    state = "death";
                }
                if rig.alive and bot is bots[0] and "quad" not in taken and tick > 240 {
                    state = "quad";
                }
                if state and state in wanted and state not in taken {
                    side = math.pi / 2.0 if state in ["strafe", "aim_up", "aim_down", "death"] else math.pi / 4.0;
                    if capture(app, level.collision, bot, eye, side, "qp_bot_" + name + "_" + state + ".png") {
                        taken.append(state);
                        print("  tick", tick, "bot", bot.kind, "legs", rig.legs_anim, "torso", rig.torso_anim, "dir", rig.move_dir,
                            "pitch", round(math.degrees(bot.pitch), 1), "weapon", rig.weapon, "battle", bot.bot_state.battle);
                    }
                }
            }
            if "drop" not in taken and "drop" in wanted {
                for item in [world->:HasPickup:->][?:Pickup] {
                    if item.dropped and item.lifetime < 29.0
                        and capture(app, level.collision, item, 15.0, math.pi / 3.0, "qp_bot_" + name + "_drop.png") {
                        taken.append("drop");
                        print("  dropped", item.rule.kind);
                        break;
                    }
                }
            }
            if "corpse" not in taken {
                for corpse in [world->:HasCorpse:->][?:Corpse] {
                    if corpse.age > 1.0 and corpse.age < 4.0
                        and capture(app, level.collision, corpse, eye, math.pi / 3.0, "qp_bot_" + name + "_corpse.png") {
                        taken.append("corpse");
                        break;
                    }
                }
            }
        }
        print("BOT BODIES", name, "captured", taken, "after", round(float(tick) / 120.0, 1), "s");
        app.models.close();
        app.quake.close();
    }
    renderer.close();
    print("BOT BODIES PASS");
}
