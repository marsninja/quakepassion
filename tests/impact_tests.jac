"""Shots striking walls: each game's ricochet sounds and Q3's impact marks,
their pool and fading, their fit on the surface, and the sky taking nothing."""
import from games.weapons { equip_player }
import from engine.world.particles {
    ImpactMark,
    HasMark,
    ImpactSound,
    HasImpactSound,
    ParticleTick,
    ricochet_sound,
    wall_impact,
    impact_mark,
    mark_fit,
    MAX_MARKS
}
import from engine.world.combat { CombatState, fire_weapon }
import from engine.world.world { World, Player }
import from engine.physics.collision { CollisionMap, Trace }
import from engine.math.vec3 { Vec3 }

"""A wall across the +x axis, its face at x = 100."""
def wall_map() -> CollisionMap {
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=100.0, y=-200.0, z=-200.0), Vec3(x=120.0, y=200.0, z=200.0), Vec3(), Vec3(), Vec3()
    );
    return collision;
}

test "each game's shots ricochet with its own odds and sounds" {
    # Q1 TE_SPIKE: tink1 four times in five, else ric1, ric2 or ric3.
    assert ricochet_sound("q1", "q1_nail", 0.5) == "sound/weapons/tink1.wav";
    assert ricochet_sound("q1", "q1_supernail", 0.87) == "sound/weapons/ric1.wav";
    assert ricochet_sound("q1", "q1_nail", 0.99) == "sound/weapons/ric3.wav";
    assert ricochet_sound("q1", "shotgun", 0.9) == "";
    assert ricochet_sound("q1", "q1_laser", 0.1) == "sound/enforcer/enfstop.wav";
    # Q2 TE_GUNSHOT: three times in sixteen; TE_SHOTGUN never.
    assert ricochet_sound("q2", "machinegun", 1.5 / 16.0) == "sound/world/ric1.wav";
    assert ricochet_sound("q2", "bullet", 3.5 / 16.0) == "sound/world/ric3.wav";
    assert ricochet_sound("q2", "chaingun", 0.5) == "";
    assert ricochet_sound("q2", "shotgun", 1.5 / 16.0) == "";
    assert ricochet_sound("q2", "q2_bolt", 0.5) == "sound/weapons/lashit.wav";
    # Q3: the machine gun always ricochets, the shotgun never.
    assert ricochet_sound("q3", "machinegun", 0.1) == "sound/weapons/machinegun/ric1.wav";
    assert ricochet_sound("q3", "machinegun", 0.9) == "sound/weapons/machinegun/ric3.wav";
    assert ricochet_sound("q3", "shotgun", 0.1) == "";
    assert ricochet_sound("q3", "lightning", 0.6) == "sound/weapons/lightning/lg_hit.wav";
}

test "Q3 shots mark the world, never movers or the sky, and other games leave none" {
    world = World();
    wall_impact(world, "q3", "machinegun", Vec3(x=100.0), Vec3(x=-1.0));
    marks = [world->:HasMark:->][?:ImpactMark];
    assert len(marks) == 1 and marks[0].shader == "gfx/damage/bullet_mrk";
    assert marks[0].radius == 8.0 and not marks[0].alpha_fade;
    assert len([world->:HasImpactSound:->]) == 1;
    wall_impact(world, "q3", "q3_plasma", Vec3(x=100.0, y=40.0), Vec3(x=-1.0));
    plasma = [mark for mark in [world->:HasMark:->][?:ImpactMark] if mark.shader == "gfx/damage/plasma_mrk"];
    assert len(plasma) == 1 and plasma[0].alpha_fade and plasma[0].radius == 16.0;
    # A door (brush model 3), SURF_NOMARKS, the sky.
    wall_impact(world, "q3", "q3_rocket", Vec3(x=100.0, y=80.0), Vec3(x=-1.0), model=3);
    wall_impact(world, "q3", "q3_rocket", Vec3(x=100.0, y=80.0), Vec3(x=-1.0), surface=1);
    wall_impact(world, "q3", "machinegun", Vec3(x=100.0, y=80.0), Vec3(x=-1.0), surface=2);
    assert len([world->:HasMark:->]) == 2;
    assert len([world->:HasImpactSound:->]) == 1;
    for game in ["q1", "q2"] {
        quiet = World();
        wall_impact(quiet, game, "machinegun", Vec3(x=100.0), Vec3(x=-1.0));
        assert not [quiet->:HasMark:->];
    }
}

test "marks wear away after ten seconds and the oldest gives way to a new one" {
    world = World();
    for i in range(MAX_MARKS) {
        impact_mark(world, "gfx/damage/bullet_mrk", Vec3(x=100.0, y=float(i)), Vec3(x=-1.0), 8.0);
        world spawn ParticleTick(dt=0.01);
    }
    marks = [world->:HasMark:->][?:ImpactMark];
    first = [mark for mark in marks if mark.pos.y == 0.0];
    assert len(marks) == MAX_MARKS and len(first) == 1;
    impact_mark(world, "gfx/damage/bullet_mrk", Vec3(x=100.0, y=-50.0), Vec3(x=-1.0), 8.0);
    marks = [world->:HasMark:->][?:ImpactMark];
    assert len(marks) == MAX_MARKS and not [mark for mark in marks if mark.pos.y == 0.0];
    for step in range(10) {
        world spawn ParticleTick(dt=1.0);
    }
    assert not [world->:HasMark:->];
}

test "a mark shrinks to stay on its wall near an edge" {
    collision = wall_map();
    face = Vec3(x=-1.0);
    assert mark_fit(collision, Vec3(x=100.0), face, 16.0, 0.3) == 16.0;
    # 10 units from the wall's top edge (z = 200) a 64-unit burn overhangs.
    overhang = mark_fit(collision, Vec3(x=100.0, z=190.0), face, 64.0, 0.0);
    assert overhang < 64.0 and overhang <= 10.0;
}

test "the sky takes no impact and a Q3 machine gun marks the wall it strikes" {
    collision = wall_map();
    hit = collision.trace_point(Vec3(), Vec3(x=200.0));
    assert hit.fraction < 1.0 and collision.surface_class(hit) == 0;
    collision.no_impact[hit.hull] = [Vec3(x=-1.0)];
    assert collision.surface_class(hit) == 2;
    collision.no_impact = {};
    collision.no_marks[hit.hull] = [Vec3(x=-1.0)];
    assert collision.surface_class(hit) == 1;
    collision.no_marks = {};
    world = World();
    player = Player();
    state = CombatState();
    equip_player(player, state, "q3");
    assert fire_weapon(world, player, collision, state);
    marks = [world->:HasMark:->][?:ImpactMark];
    assert len(marks) == 1 and abs(marks[0].pos.x - 100.0) < 0.01;
    assert marks[0].normal.x < -0.99;
    sounds = [world->:HasImpactSound:->][?:ImpactSound];
    assert len(sounds) == 1 and sounds[0].sound.startswith("sound/weapons/machinegun/ric");
}
