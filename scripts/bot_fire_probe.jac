"""Headless trace of why arena bots do or do not shoot: per think, each bot's
battle node, enemy and sight, weapon, view error to its aim point and the
BotCheckAttack gates, at the default Normal skill. q3dm1 pits Ranger against
an unkillable human standing at the player start; q3dm7 lets its bots fight
each other. Every bot that sees its enemy for three seconds must shoot."""
import math;
import from engine.core.menu { game_directory }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, CombatTick, ProjectileTick, WEAPON_SWITCH_TIME }
import from engine.world.arena { MatchTick, match_of }
import from engine.world.arena_navigation { ArenaNavigationTick, ArenaContactIndex, prepare_arena_links }
import from engine.world.bot_tactics { BotTactics, turn_between }
import from engine.world.pickups { PickupTick }
import from engine.world.models { PlayerRig }
import from games.opponents { populate_opponents }
import from games.items { populate_pickups }
import from games.weapons { equip_player }
import from engine.math.vec3 { Vec3 }

with entry {
    for name in ["q3dm1", "q3dm7"] {
        world = World();
        level = load_level(world, game_directory("q3"), name, "q3");
        level.skill = 1;
        populate_pickups(world, level, game_directory("q3"));
        populate_opponents(world, level, game_directory("q3"));
        prepare_arena_links(world, level.collision);
        contest = match_of(world);
        assert contest is not None;
        contest.warmup = 0.0;
        player = Player(health=0, pos=Vec3(z=-100000.0));
        if name == "q3dm1" {
            player = spawn_player(level);
            player.health = 100;
            player.god_mode = True;
        }
        state = CombatState(game="q3");
        equip_player(player, state, "q3");
        bots = [bot for bot in [world->:HasOpponent:->][?:Opponent] if bot.arena];
        for bot in bots {
            mind = bot.character;
            assert mind is not None;
            print("BOT", name, mind.name, "skill", mind.skill, "attack", round(mind.attack_skill, 3), "reaction", mind.reaction,
                "throttle", mind.fire_throttle, "view", mind.view_factor, mind.view_maxchange, "max health", bot.max_health);
        }
        contacts = ArenaContactIndex();
        shots: dict[str, int] = {};
        visible_time: dict[str, float] = {};
        dt = 1.0 / 120.0;
        for tick in range(120 * 40) {
            world spawn PickupTick(player=player, start=player.pos, finish=player.pos, dt=dt);
            world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt);
            world spawn CombatTick(player=player, collision=level.collision, state=state, dt=dt, arena_live=True);
            world spawn BotTactics(player=player, collision=level.collision, state=state, rules=state.rules, dt=dt);
            world spawn ProjectileTick(player=player, collision=level.collision, state=state, dt=dt);
            world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt, contacts=True);
            contest spawn MatchTick(dt=dt);
            if tick % 60 != 0 {
                continue;
            }
            for bot in bots {
                mind = bot.character;
                rig = bot.visual;
                if mind is None or not isinstance(rig, PlayerRig) or bot.health <= 0 {
                    continue;
                }
                key = mind.name;
                shots[key] = rig.shots;
                foe = bot.foe;
                seen = False;
                if foe is not None and foe.health > 0 {
                    sight = level.collision.trace_point(bot.pos, foe.pos);
                    seen = not sight.start_solid and sight.fraction == 1.0;
                }
                if seen {
                    visible_time[key] = visible_time.get(key, 0.0) + 0.5;
                }
                toward = bot.aim_target.sub(bot.pos);
                yaw_error = math.degrees(abs(turn_between(bot.yaw, math.atan2(toward.y, toward.x))));
                foe_error = -1.0;
                if foe is not None {
                    gap = foe.pos.sub(bot.pos);
                    foe_error = math.degrees(abs(turn_between(bot.yaw, math.atan2(gap.y, gap.x))));
                }
                print("T", name, round(float(tick) / 120.0, 1), key, "hp", bot.health, "battle", bot.bot_state.battle or "-",
                    "foe", "none" if foe is None else ("human" if foe is player else "bot"), "seen", seen,
                    "sight", round(bot.enemy_sight, 2), "weapon", bot.shown_weapon, "wait", round(bot.weapon_wait, 2),
                    "switch", round(bot.weapon_change, 2), "throttle", round(bot.throttle_wait, 2),
                    "aim err", round(yaw_error, 1), "foe err", round(foe_error, 1), "shots", rig.shots);
            }
        }
        for (key, count) in shots.items() {
            print("SUMMARY", name, key, "shots", count, "enemy visible s", visible_time.get(key, 0.0));
            # A bot that saw its enemy for a few seconds must have shot at it.
            assert visible_time.get(key, 0.0) < 3.0 or count > 0;
        }
        if name == "q3dm1" {
            assert shots.get("Ranger", 0) >= 10;
        }
    }
    print("BOT FIRE PROBE PASS");
}
