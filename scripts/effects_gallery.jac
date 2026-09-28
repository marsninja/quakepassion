"""Effects gallery: one still frame per game with every effect kind posed in
view at fixed ages, for comparing effect renderers by eye. Time does not
advance: the frame is drawn from the posed effects alone. Saves
effects_<game>.png in the working directory.

    jac build scripts/effects_gallery.jac --native -o .jac/effects-gallery
    DYLD_LIBRARY_PATH=vendor .jac/effects-gallery
"""
import math;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.arena { match_of }
import from engine.world.combat { Projectile, HasProjectile }
import from engine.world.particles {
    Explosion,
    HasExplosion,
    ShotTrail,
    HasTrail,
    ImpactParticle,
    HasParticle,
    explode,
    rail_trail,
    beam_trail,
    impact_spray,
    impact_mark
}
import from engine.math.vec3 { Vec3, forward_from, right_from }

glob GALLERY_MAPS: list[str] = ["q1:e1m1", "q2:base1", "q3:q3dm1"];

"""Pose effects `distance` units ahead of the player, spread across the view."""
def pose_effects(app: App, game: str) {
    world = app.world;
    eye = app.player.pos;
    # The longest sightline from the start among the four quarter turns.
    best = 0.0;
    yaw = app.player.yaw;
    for turn in range(4) {
        heading = app.player.yaw + float(turn) * math.pi / 2.0;
        probe = app.level.collision.trace_point(eye, eye.add(forward_from(heading, 0.0).scale(1024.0)));
        if probe.fraction > best {
            best = probe.fraction;
            yaw = heading;
        }
    }
    app.player.yaw = yaw;
    app.player.pitch = 0.0;
    ahead = forward_from(yaw, 0.0);
    side = right_from(yaw);
    reach = max(160.0, best * 1024.0);
    hit = app.level.collision.trace_point(eye, eye.add(ahead.scale(1024.0)));
    near = eye.add(ahead.scale(min(220.0, reach * 0.5)));
    # Explosions: left of centre, half way through their animations.
    kinds = {
        "q1": ["q1_explosion"],
        "q2": ["q2_explosion", "q2_grenade_explosion"],
        "q3": ["q3_rocket_explosion", "q3_grenade_explosion", "q3_plasma_explosion"]
    }.get(game, []);
    for i in range(len(kinds)) {
        explode(world, near.add(side.scale(-70.0 + float(i) * 45.0)).add(Vec3(z=30.0)), kinds[i]);
    }
    for blast in [world->:HasExplosion:->][?:Explosion] {
        blast.age = blast.lifetime * 0.4;
    }
    # Fire embers already flying, and blood and dust sprays.
    for particle in [world->:HasParticle:->][?:ImpactParticle] {
        particle.pos = particle.pos.add(particle.velocity.scale(0.12));
        particle.remaining = particle.lifetime * 0.6;
    }
    impact_spray(world, near.add(side.scale(40.0)).sub(Vec3(z=10.0)), ahead.scale(-1.0), blood=True);
    impact_spray(world, near.add(side.scale(60.0)).sub(Vec3(z=10.0)), ahead.scale(-1.0));
    # Trails from beside the view to the far wall.
    muzzle = eye.add(side.scale(12.0)).sub(Vec3(z=12.0));
    finish = hit.end if hit.fraction < 1.0 else eye.add(ahead.scale(1024.0));
    if game == "q1" {
        beam_trail(world, muzzle, near.add(side.scale(90.0)), "player_lightning");
    } elif game == "q2" {
        rail_trail(world, muzzle, finish.add(side.scale(40.0)), "q2_rail");
    } elif game == "q3" {
        rail_trail(world, muzzle, finish.add(side.scale(40.0)), "q3_rail");
        beam_trail(world, eye.sub(side.scale(12.0)).sub(Vec3(z=12.0)), near.add(side.scale(-120.0)), "lightning");
    }
    for trail in [world->:HasTrail:->][?:ShotTrail] {
        trail.age = 0.08;
        trail.remaining = trail.lifetime - 0.08;
    }
    # Missiles in flight, crossing the view.
    effects = {"q1": ["q1_rocket", "q1_laser"], "q2": ["q2_bfg", "q2_bolt", "q2_rocket"], "q3": ["q3_plasma", "q3_rocket", "q3_bfg"]}.get(game, []);
    for i in range(len(effects)) {
        world +>:HasProjectile:+> Projectile(
            pos=near.add(side.scale(-40.0 + float(i) * 40.0)).sub(Vec3(z=30.0)),
            velocity=side.scale(600.0),
            damage=0,
            effect=effects[i],
            age=0.35
        );
    }
    # Q3 wall marks on the far wall.
    if game == "q3" and hit.fraction < 1.0 {
        shaders = ["gfx/damage/bullet_mrk", "gfx/damage/burn_med_mrk", "gfx/damage/hole_lg_mrk", "gfx/damage/plasma_mrk"];
        radii = [8.0, 32.0, 12.0, 16.0];
        for i in range(4) {
            spot = hit.end.add(side.scale(-90.0 + float(i) * 60.0));
            impact_mark(world, shaders[i], spot, hit.normal, radii[i], alpha_fade=i == 3);
        }
    }
}

"""Q3 wall marks close up: face the nearest wall and mark it."""
def pose_marks(app: App) {
    eye = app.player.pos;
    nearest = 2.0;
    yaw = app.player.yaw;
    for turn in range(8) {
        heading = app.player.yaw + float(turn) * math.pi / 4.0;
        probe = app.level.collision.trace_point(eye, eye.add(forward_from(heading, 0.0).scale(1024.0)));
        if probe.fraction < nearest and probe.fraction * 1024.0 > 96.0 {
            nearest = probe.fraction;
            yaw = heading;
        }
    }
    app.player.yaw = yaw;
    app.player.pitch = 0.0;
    ahead = forward_from(yaw, 0.0);
    side = right_from(yaw);
    hit = app.level.collision.trace_point(eye, eye.add(ahead.scale(1024.0)));
    if hit.fraction >= 1.0 {
        return;
    }
    shaders = ["gfx/damage/bullet_mrk", "gfx/damage/burn_med_mrk", "gfx/damage/hole_lg_mrk", "gfx/damage/plasma_mrk", "gfx/damage/plasma_mrk"];
    radii = [8.0, 32.0, 12.0, 16.0, 24.0];
    for i in range(5) {
        spot = hit.end.add(side.scale(-100.0 + float(i) * 50.0)).add(Vec3(z=float(i % 2) * 20.0 - 10.0));
        impact_mark(world=app.world, shader=shaders[i], origin=spot, normal=hit.normal, radius=radii[i], alpha_fade=i >= 3, color=Vec3(x=1.0, y=0.0, z=1.0) if i == 4 else Vec3(x=1.0, y=1.0, z=1.0));
    }
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock(), smoke=True);
    app.host.overlay.assign("0");
    for spec in GALLERY_MAPS {
        game = spec.split(":")[0];
        name = spec.split(":")[1];
        app.smoke = True;
        app.load_destination(game, name);
        app.smoke = False;
        app.walking = True;
        app.player.god_mode = True;
        contest = match_of(app.world);
        if contest is not None {
            contest.warmup = 0.0;
        }
        for i in range(30) {
            app.step();
        }
        pose_effects(app, game);
        # Draw the posed frame twice (the first may still upload) and keep it.
        app.render_frame();
        app.render_frame();
        renderer.screenshot("effects_" + game + ".png");
        if game == "q3" {
            pose_marks(app);
            app.render_frame();
            app.render_frame();
            renderer.screenshot("effects_q3_marks.png");
        }
    }
    renderer.close();
}
