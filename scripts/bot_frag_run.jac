"""A longer headless arena match to judge how hard bots fight. Every map in
QP_MAPS (default q3dm7, q3dm6, q3dm12) runs QP_SECONDS (default 180) of bot
against bot at the game skill QP_SKILL (0-4, default 2: Hurt Me Plenty), and
prints the frags, deaths and shots of each bot, the share of time it spent in
each battle node and with its enemy in sight, and how the frags were made."""
import os;
import from engine.core.menu { game_directory }
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, CombatTick, ProjectileTick }
import from engine.world.arena { MatchTick, Competes, match_of, standings }
import from engine.world.arena_navigation { ArenaNavigationTick, ArenaContactIndex, prepare_arena_links }
import from engine.world.bot_tactics { BotTactics }
import from engine.world.pickups { PickupTick }
import from engine.world.doors { DoorTick }
import from engine.world.models { PlayerRig }
import from games.opponents { populate_opponents }
import from games.items { populate_pickups }
import from games.weapons { equip_player }
import from engine.math.vec3 { Vec3 }

with entry {
    maps = os.getenv("QP_MAPS", "q3dm7,q3dm6,q3dm12").split(",");
    seconds = float(os.getenv("QP_SECONDS", "180"));
    skill = int(os.getenv("QP_SKILL", "2"));
    # QP_SEED varies the bots' dice between runs of the same code.
    seed = int(os.getenv("QP_SEED", "0"));
    dt = 1.0 / 120.0;
    grand = 0;
    for name in maps {
        world = World();
        level = load_level(world, game_directory("q3"), name, "q3", skill);
        populate_pickups(world, level, game_directory("q3"));
        populate_opponents(world, level, game_directory("q3"));
        prepare_arena_links(world, level.collision);
        contest = match_of(world);
        assert contest is not None;
        contest.warmup = 0.0;
        # No frag limit: the run measures the pace of a whole stretch of play.
        contest.fraglimit = 100000;
        bots = [bot for bot in [world->:HasOpponent:->][?:Opponent] if bot.arena];
        for bot in bots {
            bot.shot_random = (bot.shot_random + seed * 7919) % 2147483647 + 1;
        }
        player = Player(health=0, pos=Vec3(z=-100000.0));
        state = CombatState(game="q3");
        equip_player(player, state, "q3");
        contacts = ArenaContactIndex();
        nodes: dict[str, dict[str, float]] = {};
        sighted: dict[str, float] = {};
        alive: dict[str, float] = {};
        means: dict[str, int] = {};
        down: dict[str, bool] = {};
        health: dict[str, int] = {};
        cells: dict[str, list[str]] = {};
        damage = 0;
        for bot in bots {
            key = bot.character.name if bot.character is not None else "?";
            nodes[key] = {};
            sighted[key] = 0.0;
            alive[key] = 0.0;
            down[key] = False;
            health[key] = bot.health;
            cells[key] = [];
        }
        ticks = int(seconds / dt);
        for tick in range(ticks) {
            world spawn PickupTick(player=player, start=player.pos, finish=player.pos, dt=dt);
            world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt);
            # Bots open doors by walking into their trigger fields (Touch_DoorTrigger).
            world spawn DoorTick(bsp=level.bsp, collision=level.collision, player_origin=player.pos, dt=dt, touching=False);
            world spawn CombatTick(player=player, collision=level.collision, state=state, dt=dt, arena_live=True);
            world spawn BotTactics(player=player, collision=level.collision, state=state, rules=state.rules, dt=dt);
            world spawn ProjectileTick(player=player, collision=level.collision, state=state, dt=dt);
            world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt, contacts=True);
            contest spawn MatchTick(dt=dt);
            for bot in bots {
                mind = bot.character;
                if mind is None {
                    continue;
                }
                key = mind.name;
                if bot.health < health[key] {
                    damage += health[key] - max(bot.health, -40);
                }
                health[key] = bot.health;
                if bot.health <= 0 {
                    if not down[key] {
                        down[key] = True;
                        cause = bot.death_means or "world";
                        if bot.killer is bot {
                            cause = "self:" + cause;
                        }
                        means[cause] = means.get(cause, 0) + 1;
                    }
                    continue;
                }
                down[key] = False;
                alive[key] += dt;
                if tick % 60 == 0 {
                    spot = str(int(bot.pos.x // 256.0)) + ":" + str(int(bot.pos.y // 256.0)) + ":" + str(int(bot.pos.z // 128.0));
                    if spot not in cells[key] {
                        cells[key].append(spot);
                    }
                }
                phase = bot.bot_state.battle or "seek";
                nodes[key][phase] = nodes[key].get(phase, 0.0) + dt;
                foe = bot.foe;
                if foe is not None and foe.health > 0 and tick % 12 == 0 {
                    sight = level.collision.trace_point(bot.pos, foe.pos);
                    if not sight.start_solid and sight.fraction >= 1.0 {
                        sighted[key] += dt * 12.0;
                    }
                }
            }
            if tick % int(60.0 / dt) == 0 and tick > 0 {
                print("MINUTE", name, int(float(tick) * dt / 60.0), [row.name + ":" + str(row.frags) for row in standings(contest)]);
            }
        }
        entries = [edge contest->:Competes:->];
        actors = [contest->:Competes:->];
        frags = 0;
        for i in range(len(actors)) {
            bot = actors[i];
            if not isinstance(bot, Opponent) or bot.character is None {
                continue;
            }
            key = bot.character.name;
            score = entries[i];
            frags += max(0, score.frags);
            shots = bot.visual.shots if isinstance(bot.visual, PlayerRig) else 0;
            shares = [
                phase + " " + str(int(100.0 * value / max(0.001, alive[key]))) + "%"
                for (phase, value) in nodes[key].items()
            ];
            print("BOT", name, key, "skill", bot.character.skill, "frags", score.frags, "deaths", score.deaths,
                "shots", shots, "cells", len(cells[key]), "at", [int(bot.pos.x), int(bot.pos.y), int(bot.pos.z)], "sighted", str(int(100.0 * sighted[key] / max(0.001, alive[key]))) + "%", shares);
        }
        print("MEANS", name, means, "damage taken", damage);
        print("FRAGS", name, "skill", skill, "seconds", int(seconds), "total", frags,
            "per minute", round(float(frags) * 60.0 / seconds, 2));
        grand += frags;
    }
    print("FRAG RUN DONE", grand);
}
