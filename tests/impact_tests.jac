"""Shots striking walls: each game's ricochet sounds and Q3's impact marks,
their pool and fading, their cut to the faces they lie on, and the sky taking
nothing."""
import from games.weapons { equip_player }
import from engine.world.particles {
    ImpactMark,
    HasMark,
    ImpactSound,
    HasImpactSound,
    Explosion,
    HasExplosion,
    ParticleTick,
    impact_spray,
    missile_hit_flesh,
    ricochet_sound,
    wall_impact,
    impact_mark,
    MAX_MARK_POLYS,
    HasMarkSurfaces,
    mark_axes
}
import from engine.world.particle_field { particle_field }
import from engine.world.level { Split, BspArea, Front, Back, BspMarkSurfaces }
import from engine.formats.bsp { Face, Texture }
import from engine.math.aabb { AABB }
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
    # A door (brush model 3) and SURF_NOMARKS take the burst but no mark;
    # the sky takes nothing at all.
    wall_impact(world, "q3", "q3_rocket", Vec3(x=100.0, y=80.0), Vec3(x=-1.0), model=3);
    wall_impact(world, "q3", "q3_rocket", Vec3(x=100.0, y=80.0), Vec3(x=-1.0), surface=1);
    wall_impact(world, "q3", "machinegun", Vec3(x=100.0, y=80.0), Vec3(x=-1.0), surface=2);
    assert len([world->:HasMark:->]) == 2;
    assert len([world->:HasImpactSound:->]) == 4;
    assert len([blast for blast in [world->:HasExplosion:->][?:Explosion] if blast.kind == "q3_rocket_explosion"]) == 2;
    for game in ["q1", "q2"] {
        quiet = World();
        wall_impact(quiet, game, "machinegun", Vec3(x=100.0), Vec3(x=-1.0));
        assert not [quiet->:HasMark:->];
    }
}

test "Q3 hits burst as CG_MissileHitWall makes each weapon's" {
    wall = Vec3(x=-1.0);
    # weapon: explosion, sprite (16 out from the wall), life, light, sound, mark.
    expected = {
        "machinegun": ("q3_bullet_explosion", False, 0.6, 0.0, "sound/weapons/machinegun/ric", "gfx/damage/bullet_mrk"),
        "shotgun": ("q3_bullet_explosion", False, 0.6, 0.0, "", "gfx/damage/bullet_mrk"),
        "lightning": ("", False, 0.0, 0.0, "sound/weapons/lightning/lg_hit", "gfx/damage/hole_lg_mrk"),
        "railgun": ("q3_rail_explosion", False, 0.6, 0.0, "sound/weapons/plasma/plasmx1a.wav", "gfx/damage/plasma_mrk"),
        "q3_plasma": ("q3_plasma_explosion", False, 0.6, 0.0, "sound/weapons/plasma/plasmx1a.wav", "gfx/damage/plasma_mrk"),
        "q3_grenade": ("q3_grenade_explosion", True, 0.6, 300.0, "sound/weapons/rocket/rocklx1a.wav", "gfx/damage/burn_med_mrk"),
        "q3_rocket": ("q3_rocket_explosion", True, 1.0, 300.0, "sound/weapons/rocket/rocklx1a.wav", "gfx/damage/burn_med_mrk"),
        "q3_bfg": ("q3_bfg_explosion", True, 0.6, 0.0, "sound/weapons/rocket/rocklx1a.wav", "gfx/damage/burn_med_mrk")
    };
    for (weapon, look) in expected.items() {
        world = World();
        wall_impact(world, "q3", weapon, Vec3(x=100.0, y=7.0, z=3.0), wall);
        blasts = [world->:HasExplosion:->][?:Explosion];
        if look[0] {
            assert len(blasts) == 1 and blasts[0].kind == look[0] , weapon;
            blast = blasts[0];
            assert blast.pos.x == (84.0 if look[1] else 100.0) and blast.lifetime == look[2] , weapon;
            assert blast.light_radius == look[3] and blast.direction.x == -1.0 and not blast.sound , weapon;
            # CG_MakeExplosion skews its start back by up to 63 ms.
            assert 0.0 <= blast.age < 0.064 and 0.0 <= blast.rotation < 360.0 , weapon;
        } else {
            assert not blasts , weapon;
        }
        sounds = [world->:HasImpactSound:->][?:ImpactSound];
        if look[4] {
            assert len(sounds) == 1 and sounds[0].sound.startswith(look[4]) , weapon;
        } else {
            assert not sounds , weapon;
        }
        marks = [world->:HasMark:->][?:ImpactMark];
        assert len(marks) == 1 and marks[0].shader == look[5] , weapon;
    }
    rocket = World();
    wall_impact(rocket, "q3", "q3_rocket", Vec3(x=100.0), wall);
    light = [rocket->:HasExplosion:->][?:Explosion][0].light;
    assert light.x == 1.0 and light.y == 0.75 and light.z == 0.0;
}

test "Q3 blood spurts from bodies, never the rail's or the viewer's own" {
    world = World();
    particle_field(world, "q3");
    impact_spray(world, Vec3(x=5.0), Vec3(x=-1.0), True, "machinegun");
    blood = [world->:HasExplosion:->][?:Explosion];
    assert len(blood) == 1 and blood[0].kind == "q3_blood" and blood[0].lifetime == 0.5 and blood[0].age == 0.0;
    impact_spray(world, Vec3(x=5.0), Vec3(x=-1.0), True, "railgun");
    impact_spray(world, Vec3(x=5.0), Vec3(x=-1.0), False, "machinegun");
    assert len([world->:HasExplosion:->]) == 1;
    # A rocket striking someone bleeds and bursts; a plasma bolt only bleeds.
    struck = World();
    missile_hit_flesh(struck, "q3", "q3_rocket", Vec3(), Vec3(x=-1.0));
    kinds = sorted([blast.kind for blast in [struck->:HasExplosion:->][?:Explosion]]);
    assert kinds == ["q3_blood", "q3_rocket_explosion"];
    plasma = World();
    missile_hit_flesh(plasma, "q3", "q3_plasma", Vec3(), Vec3(x=-1.0));
    assert [blast.kind for blast in [plasma->:HasExplosion:->][?:Explosion]] == ["q3_blood"];
    viewer = World();
    missile_hit_flesh(viewer, "q3", "q3_rocket", Vec3(), Vec3(x=-1.0), viewer=True);
    assert [blast.kind for blast in [viewer->:HasExplosion:->][?:Explosion]] == ["q3_rocket_explosion"];
    other = World();
    missile_hit_flesh(other, "q2", "q2_rocket", Vec3(), Vec3(x=-1.0));
    assert not [other->:HasExplosion:->];
}

test "marks wear away after ten seconds and the oldest gives way to a new one" {
    world = World();
    # Without a level's surfaces each mark is one polygon, its own square.
    for i in range(MAX_MARK_POLYS) {
        impact_mark(world, "gfx/damage/bullet_mrk", Vec3(x=100.0, y=float(i)), Vec3(x=-1.0), 8.0);
        world spawn ParticleTick(dt=0.01);
    }
    marks = [world->:HasMark:->][?:ImpactMark];
    first = [mark for mark in marks if mark.pos.y == 0.0];
    assert len(marks) == MAX_MARK_POLYS and len(first) == 1 and len(first[0].fragments[0]) == 4;
    impact_mark(world, "gfx/damage/bullet_mrk", Vec3(x=100.0, y=-50.0), Vec3(x=-1.0), 8.0);
    marks = [world->:HasMark:->][?:ImpactMark];
    assert len(marks) == MAX_MARK_POLYS and not [mark for mark in marks if mark.pos.y == 0.0];
    for step in range(10) {
        world spawn ParticleTick(dt=1.0);
    }
    assert not [world->:HasMark:->];
}

"""A wall at x = 100 facing -x, standing on the floor z = 0, and the floor
itself, in one leaf; `nomarks` gives the wall SURF_NOMARKS."""
def mark_world(nomarks: bool = False) -> World {
    wall = Face(
        planar=True,
        normal=Vec3(x=-1.0),
        plane_dist=-100.0,
        texture=0,
        vertices=[Vec3(x=100.0, y=-200.0), Vec3(x=100.0, y=200.0), Vec3(x=100.0, y=200.0, z=200.0), Vec3(x=100.0, y=-200.0, z=200.0)],
        indices=[0, 1, 2, 0, 2, 3]
    );
    floor = Face(
        planar=True,
        normal=Vec3(z=1.0),
        plane_dist=0.0,
        texture=1,
        vertices=[Vec3(x=-200.0, y=-200.0), Vec3(x=100.0, y=-200.0), Vec3(x=100.0, y=200.0), Vec3(x=-200.0, y=200.0)],
        indices=[0, 1, 2, 0, 2, 3]
    );
    box = AABB(mins=Vec3(), maxs=Vec3());
    split = Split(normal=Vec3(z=1.0), distance=-1000.0);
    split +>:Front:+> BspArea(name="room", bounds=box, faces=[0, 1]);
    split +>:Back:+> BspArea(name="below", bounds=box);
    world = World();
    world +>:HasMarkSurfaces:+> BspMarkSurfaces(
        head=split,
        faces=[wall, floor],
        textures=[Texture(name="wall", flags=32 if nomarks else 0), Texture(name="floor")]
    );
    return world;
}

test "a mark is cut to the faces it lies on, as R_MarkFragments cuts it" {
    world = mark_world();
    # 10 units above the floor a 16-unit mark would hang below the wall.
    impact_mark(world, "gfx/damage/bullet_mrk", Vec3(x=100.0, z=10.0), Vec3(x=-1.0), 16.0);
    marks = [world->:HasMark:->][?:ImpactMark];
    assert len(marks) == 1 and marks[0].fragments;
    axes = mark_axes(marks[0].normal, marks[0].angle);
    lowest = 1000.0;
    for fragment in marks[0].fragments {
        assert len(fragment) >= 3;
        for point in fragment {
            # On the wall, and inside the mark's turned square.
            delta = point.sub(marks[0].pos);
            assert abs(point.x - 100.0) < 0.01;
            assert abs(delta.dot(axes[0])) <= 16.01 and abs(delta.dot(axes[1])) <= 16.01;
            lowest = min(lowest, point.z);
        }
    }
    # Cut at the wall's foot; the floor, square to the shot, takes none.
    assert abs(lowest) < 0.01;
    # Nothing behind the square: no mark is left.
    impact_mark(world, "gfx/damage/bullet_mrk", Vec3(z=500.0), Vec3(x=-1.0), 16.0);
    assert len([world->:HasMark:->]) == 1;
    # A SURF_NOMARKS wall takes none.
    quiet = mark_world(True);
    impact_mark(quiet, "gfx/damage/bullet_mrk", Vec3(x=100.0, z=10.0), Vec3(x=-1.0), 16.0);
    assert not [quiet->:HasMark:->];
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
