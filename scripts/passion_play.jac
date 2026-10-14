"""Play a Passion expedition's logic through in the real game: every
objective in the mission's order, then the way out.

    jac build scripts/passion_play.jac --native -o .jac/qp-play
    QP_GAME=passion QP_SEEDS="1 2 3" DYLD_LIBRARY_PATH=vendor .jac/qp-play

The game loads each seed (QP_SEEDS, default 42) through the App, as the menu
does, with god mode on. For each objective in progression order the player
is set down on its stage and the game steps on: a key must be in the
inventory, a switch's plate must open the doors it names, a guardian (slain)
must open its gate. Then every locked door is walked up to and must open,
and the player is set in the way out, which must complete the expedition.
Walking between them is the yardstick's to prove (passion_tests.jac); this
proves the wiring. A line `PLAY seed=... PASS` or `FAIL <why>` per seed;
the exit is photographed as play_<seed>.png."""
import os;
import math;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, damage_opponent }
import from engine.world.doors { Door, HasDoor }
import from engine.world.inventory { quantity }
import from engine.world.pickups { Pickup, HasPickup }
import from engine.world.signals { Signal, Targets }
import from engine.input.input { Intent }
import from engine.math.vec3 { Vec3 }
import from games.passion.generate { survey_of, Survey }
import from games.passion.mission { beats_of }
import from games.passion.arrange { estate_spaces }
import from games.passion.massing { CELL, LIFT }
import from games.passion.cast { token_name }

def:priv play_tick(app: App) {
    app.scripted = Intent(move=Vec3());
    app.skip_time = True;
    app.physics_clock.accumulator = app.physics_clock.tick_rate;
    app.step();
}

def:priv play_ticks(app: App, count: int) {
    for frame in range(count) {
        play_tick(app);
    }
}

"""Set the player down with his feet at a point."""
def:priv stand_at(app: App, x: float, y: float, z: float) {
    app.player.pos = Vec3(x=x, y=y, z=z + app.level.collision.eye_height);
    app.player.velocity = Vec3();
}

"""Doors named by a token's trigger that are no longer shut."""
def:priv doors_moved(app: App, name: str) -> int {
    count = 0;
    for door in [app.world->:HasDoor:->][?:Door] {
        if name in door.names and door.state != "closed" {
            count += 1;
        }
    }
    return count;
}

def:priv doors_named(app: App, name: str) -> int {
    return len([door for door in [app.world->:HasDoor:->][?:Door] if name in door.names]);
}

"""Slay every foe whose death fires a door named `name`."""
def:priv slay_for(app: App, name: str) -> int {
    gates = [door.activation for door in [app.world->:HasDoor:->][?:Door] if name in door.names];
    slain = 0;
    for enemy in [app.world->:HasOpponent:->][?:Opponent] {
        fired = [signal for signal in [enemy.activation->:Targets:->][?:Signal] if signal in gates];
        if enemy.health > 0 and fired {
            damage_opponent(enemy, 100000);
            slain += 1;
        }
    }
    return slain;
}

"""Play one seed; the reason it failed, or ""."""
def:priv play_seed(app: App, renderer: Renderer, seed: int) -> str {
    app.load_destination("passion", "v3-" + str(seed));
    if app.menu.opened {
        return "load: " + app.menu.message;
    }
    app.player.god_mode = True;
    found = survey_of(app.world);
    if found is None {
        return "no survey";
    }
    record: Survey = found;
    plan = record.plan;
    estate = record.estate;
    casting = record.casting;
    if plan is None or estate is None or casting is None {
        return "survey incomplete";
    }
    by_beat: dict[int, list[int]] = {};
    for space in estate_spaces(estate) {
        if space.role not in ["corridor", "window"] and space.stage {
            by_beat[space.beat] = space.stage;
        }
    }
    beats = sorted([[beat.order if beat.order >= 0 else 999, beat.id] for beat in beats_of(plan) if beat.grants]);
    lookup: dict[int, list[str]] = {};
    for beat in beats_of(plan) {
        lookup[beat.id] = beat.grants;
    }
    play_ticks(app, 30);
    for pair in beats {
        stage = by_beat.get(pair[1], []);
        if not stage {
            return "beat " + str(pair[1]) + " has no stage";
        }
        x = (float(stage[0]) + 0.5) * CELL;
        y = (float(stage[1]) + 0.5) * CELL;
        z = float(stage[2]) * LIFT + 24.0;
        for token in lookup[pair[1]] {
            name = token_name(token);
            if token.startswith("guardian:") {
                if slay_for(app, name) == 0 and doors_named(app, name) > 0 {
                    return "no guardian opens " + name;
                }
            }
            stand_at(app, x, y, z);
            play_ticks(app, 60);
            if token.startswith("key_") and quantity(app.player.inventory, token) <= 0 {
                for item in [app.world->:HasPickup:->][?:Pickup] {
                    if item.rule.kind.startswith("key") {
                        print(
                            "PLAY   key pickup " + item.rule.kind + " at " + str(int(item.pos.x)) + " " + str(int(item.pos.y)) + " "
                                + str(int(item.pos.z)) + " active=" + str(item.active)
                        );
                    }
                }
                print("PLAY   player at " + str(int(app.player.pos.x)) + " " + str(int(app.player.pos.y)) + " " + str(int(app.player.pos.z)));
                return "key " + token + " not picked up at its stage";
            }
            if (token.startswith("switch:") or token.startswith("relay:") or token.startswith("guardian:"))
                and doors_named(app, name) > 0 and doors_moved(app, name) == 0 {
                for door in [app.world->:HasDoor:->][?:Door] {
                    middle = door.bounds.mins.add(door.bounds.maxs).scale(0.5);
                    if middle.sub(Vec3(x=x, y=y, z=z)).length() < 200.0 or name in door.names {
                        print(
                            "PLAY   near " + door.kind + " state=" + door.state + " names=" + ",".join(door.names) + " at "
                                + str(int(middle.x)) + " " + str(int(middle.y)) + " " + str(int(middle.z)) + " enabled="
                                + str(door.enabled) + " automatic=" + str(door.automatic)
                        );
                    }
                }
                print("PLAY   player at " + str(int(app.player.pos.x)) + " " + str(int(app.player.pos.y)) + " " + str(int(app.player.pos.z)));
                return token + " opened none of its " + str(doors_named(app, name)) + " doors";
            }
        }
    }
    # Every door that wants keys opens to a player who has them.
    for door in [app.world->:HasDoor:->][?:Door] {
        if not door.keys {
            continue;
        }
        middle = door.bounds.mins.add(door.bounds.maxs).scale(0.5);
        stand_at(app, middle.x, middle.y, door.bounds.mins.z + 24.0);
        play_ticks(app, 90);
        if door.state == "closed" {
            return "door needing " + " ".join(door.keys) + " stayed shut";
        }
    }
    low = casting.exit_low;
    high = casting.exit_high;
    stand_at(app, (low[0] + high[0]) * 0.5, (low[1] + high[1]) * 0.5, low[2] + 24.0);
    play_ticks(app, 60);
    for frame in range(3) {
        app.render_frame();
    }
    renderer.screenshot("play_" + str(seed) + ".png");
    if app.level.completion.pending == 0 {
        return "the way out did not complete the expedition";
    }
    return "";
}

with entry {
    seeds = (os.environ.get("QP_SEEDS", "42")).split();
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock());
    app.host.overlay.assign("0");
    failed = 0;
    for word in seeds {
        why = play_seed(app, renderer, int(word));
        if why {
            failed += 1;
            print("PLAY seed=" + word + " FAIL " + why);
        } else {
            print("PLAY seed=" + word + " PASS");
        }
    }
    print("PLAY " + str(len(seeds) - failed) + " of " + str(len(seeds)) + " passed");
}
