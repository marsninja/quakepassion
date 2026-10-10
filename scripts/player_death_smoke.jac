"""Kill the player in each game through the real game loop and watch the level
run on around the body: it lies in its game's form touching nothing, a
missile lands, a door opens and closes, an alerted monster goes back to its
stand, saving is refused, and the buttons bring the player back. Captures
qp_death_<game>.png."""
import os;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, Projectile, HasProjectile }
import from engine.world.doors { Door, HasDoor }
import from engine.world.pickups { Pickup, HasPickup }
import from engine.world.arena { match_of }
import from engine.world.demise { Mortality, HasMortality, mortality_of }
import from engine.math.vec3 { Vec3 }
import from scripts.input_events { event, key }
import from engine.input.input { _capture, _release }

"""Run `seconds` of the game at 20 frames a second."""
def run_for(app: App, seconds: float) {
    for frame in range(int(seconds * 20.0 + 0.5)) {
        assert app.step();
    }
}

"""Load `name`, in walk mode, with its opponents holding their fire."""
def enter(app: App, game: str, name: str) {
    app.load_destination(game, name);
    assert not app.menu.opened, app.menu.message;
    assert app.walking;
    contest = match_of(app.world);
    if contest is not None {
        contest.warmup = 0.0;
    }
    for enemy in [app.world->:HasOpponent:->][?:Opponent] {
        enemy.attack_wait = 100000.0;
    }
    run_for(app, 0.5);
}

"""A door the level opens and shuts by itself, if it has one."""
def plain_door(app: App) -> Door | None {
    for door in [app.world->:HasDoor:->][?:Door] {
        if door.kind == "door"
            and door.enabled
            and door.automatic
            and not door.keys
            and not door.toggle
            and door.max_health == 0
            and door.hold_time >= 0.0
            and door.state == "closed" {
            return door;
        }
    }
    return None;
}

with entry {
    assert os.getenv("QP_VALIDATE_HOME", "") == os.getenv("HOME", "missing"),
        "Use a disposable HOME and matching QP_VALIDATE_HOME";
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock());
    app.fixed_dt = 0.05;
    try {
        for game in ["q1", "q2", "q3"] {
            name = "e1m1" if game == "q1" else ("base1" if game == "q2" else "q3dm1");
            enter(app, game, name);
            _capture();
            standing = app.level.collision.eye_height;
            rule = mortality_of(app.player).rule;
            # A monster on the player's trail when the player dies.
            watcher: Opponent | None = None;
            for enemy in [app.world->:HasOpponent:->][?:Opponent] {
                if watcher is None
                    and not enemy.arena
                    and not enemy.dormant
                    and enemy.health > 0
                    and not enemy.rule.inert
                    and not enemy.rule.decoration
                    and not enemy.rule.script {
                    watcher = enemy;
                }
            }
            if watcher is not None {
                watcher.alert = 8.0;
                watcher.sighted = True;
                watcher.last_seen = app.player.pos.add(Vec3());
            }
            origin = app.player.pos.sub(Vec3(z=standing));
            app.player.health = 0;
            before = app.simulation_time;
            run_for(app, 0.25);
            fallen = mortality_of(app.player);
            lying = app.level.collision;
            # The body lies in its game's form, and the level runs on.
            assert fallen.dead and app.simulation_time > before + 0.2;
            assert lying.eye_height == rule.lying.eye_height and lying.top_drop == rule.lying.top_drop;
            assert not app.in_touch();
            print("DEATH", game, "form eye", lying.eye_height, "top drop", lying.top_drop,
                "origin z", app.player.pos.z - lying.eye_height, "was", origin.z);
            # Q1 Host_Savegame_f and Q2 SV_Savegame_f refuse a dead player.
            app.quicksave();
            assert app.notice.startswith("Can't savegame"), app.notice;
            # A monster's missile already in the air lands.
            nail = Projectile(
                pos=app.player.pos.add(Vec3(z=24.0)), velocity=Vec3(z=-400.0), damage=1, hostile=True
            );
            app.world +>:HasProjectile:+> nail;
            run_for(app, 1.0);
            assert nail not in [app.world->:HasProjectile:->][?:Projectile];
            assert app.player.health == 0;
            if watcher is not None {
                # ai_run / ai_checkattack: its enemy dead, it stands again.
                assert watcher.alert == 0.0 and not watcher.pursuing, watcher.kind;
                print("DEATH", game, watcher.kind, "stands, pose", watcher.pose_name);
            }
            # The body lies on an item and takes nothing (the item furthest
            # from anyone else who might).
            item: Pickup | None = None;
            clearance = -1.0;
            for candidate in [app.world->:HasPickup:->][?:Pickup] {
                if not candidate.active or not candidate.visual.visible {
                    continue;
                }
                nearest = 100000.0;
                for other in [app.world->:HasOpponent:->][?:Opponent] {
                    if other.health > 0 and not other.dormant {
                        nearest = min(nearest, other.pos.sub(candidate.pos).length());
                    }
                }
                if nearest > clearance {
                    clearance = nearest;
                    item = candidate;
                }
            }
            if item is not None {
                app.player.pos = item.pos.add(Vec3(z=25.0 + lying.eye_height));
                app.player.velocity = Vec3();
                app.player.grounded = False;
                app.player.tick_pose.settle();
                run_for(app, 0.5);
                assert item.active, item.rule.kind;
                reach = app.player.pos.sub(Vec3(z=lying.eye_height)).sub(item.pos);
                assert abs(reach.x) < 1.0 and abs(reach.y) < 1.0 and abs(reach.z) < 40.0;
                print("DEATH", game, "body left the", item.rule.kind, "where it lay");
            }
            renderer.screenshot("qp_death_" + game + ".png");
            # A door opens and shuts again while the player lies dead.
            door = plain_door(app);
            if door is not None {
                door.requested = True;
                opened = False;
                shut = False;
                for frame in range(800) {
                    assert app.step();
                    opened = opened or door.position >= 1.0;
                    if opened and door.state == "closed" {
                        shut = True;
                        break;
                    }
                }
                assert opened and shut, door.state;
                print("DEATH", game, "a door opened and closed around the body");
            } else {
                print("DEATH", game, "no plain door in", name);
            }
            # Coming back.
            fallen.clock = 5.0;
            if game == "q3" {
                key(app, 32);
                assert app.player.health == app.player.max_health + 25 and not fallen.dead;
                run_for(app, 0.1);
                assert app.in_touch() and app.level.collision.eye_height == standing;
                assert app.level.collision.top_drop == 0.0;
            } else {
                # Q1 wants the buttons let go and then one pressed; Q2 any
                # button going down.
                assert app.step() and app.player.health == 0;
                key(app, 32);
                assert app.player.health > 0 and app.level.name == name and not app.menu.opened;
                assert fallen not in [app.player->:HasMortality:->][?:Mortality];
                run_for(app, 0.1);
                assert app.in_touch() and app.level.collision.eye_height == standing;
            }
            print("DEATH PASS", game);
        }
    } finally {
        _release();
        app.audio.close();
        app.models.close();
        app.quake.close();
        renderer.close();
    }
}
