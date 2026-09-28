"""Native asset-backed movement checks; select Q1/Q2/Q3 with QP_GAME."""
import os;
import math;
import from engine.world.level { Level, load_level, spawn_player }
import from engine.world.world { World, Player }
import from engine.physics.collision { CollisionMap }
import from engine.formats.bsp { Face }
import from engine.physics.movement { MovePlayer }
import from engine.math.vec3 { Vec3 }

"""Whether `point` lies within `reach` of a patch's rendered outline (the
tessellation's outer rows and columns, `steps` segments per quadratic piece)."""
def near_patch_outline(face: Face, point: Vec3, reach: float, steps: int = 8) -> bool {
    across = (face.patch_width - 1) // 2;
    down = (face.patch_height - 1) // 2;
    side = steps + 1;
    for py in range(down) {
        for px in range(across) {
            base = (py * across + px) * side * side;
            for y in range(side) {
                for x in range(side) {
                    if ((px == 0 and x == 0)
                        or (px == across - 1 and x == steps)
                        or (py == 0 and y == 0)
                        or (py == down - 1 and y == steps))
                        and face.vertices[base + y * side + x].sub(point).length() <= reach {
                        return True;
                    }
                }
            }
        }
    }
    return False;
}

"""Whether a shot along -`normal` from 20 units in front of `point` stops on
a patch facet no further than SUBDIVIDE_DISTANCE from it."""
def patch_shot_lands(collision: CollisionMap, point: Vec3, normal: Vec3) -> bool {
    shot = collision.trace_point(point.add(normal.scale(20.0)), point.sub(normal.scale(24.0)));
    return shot.fraction < 1.0
        and collision.hulls[shot.hull].facet
        and shot.end.sub(point).length() <= 16.5;
}

"""Q3 curved surfaces (cm_patch.c facets). Rendered triangles spread over each
solid patch are shot at from 20 units in front: the shot must stop on a facet
(or other geometry) within SUBDIVIDE_DISTANCE of the rendered curve, or, where
it slips past the facets' chords of a curved outline or crease, lie by the
outline or land 12 units across. Shot from
behind, facets let it through (another patch there is counted). A player
dropped on up to 24 walkable spots walks off each four ways and must never
start solid (sink into a facet) or stall with open space ahead (stick on a
seam)."""
def check_patches(level: Level, name: str) {
    collision = level.collision;
    probes = 0;
    chorded = 0;
    behind = 0;
    walks = 0;
    stalls = 0;
    frames = 0;
    for face in level.bsp.faces {
        if not face.patch or level.bsp.textures[face.texture].contents & 1 == 0 {
            continue;
        }
        # A few rendered triangles per patch, spread over it.
        stride = max(3, (len(face.indices) // 3 // 4) * 3);
        for i in range(0, len(face.indices), stride) {
            a = face.vertices[face.indices[i]];
            b = face.vertices[face.indices[i + 1]];
            c = face.vertices[face.indices[i + 2]];
            normal = b.sub(a).cross(c.sub(a));
            if normal.length() < 0.5 {
                continue;
            }
            normal = normal.normalized();
            center = a.add(b).add(c).scale(1.0 / 3.0);
            probes += 1;
            front = collision.trace_point(center.add(normal.scale(20.0)), center.sub(normal.scale(24.0)));
            # Other geometry in front may stop it first. Facets are chords of
            # the curve, so a shot can slip past them where the curve bows
            # over an outline or crease: then it must be by the outline, or a
            # shot a little way across must land.
            if front.fraction >= 1.0
                or (
                    collision.hulls[front.hull].facet
                    and front.end.sub(center).length() > 16.5
                ) {
                across = b.sub(a).normalized();
                along = normal.cross(across);
                landed = near_patch_outline(face, center, 17.0);
                for offset in [across, across.scale(-1.0), along, along.scale(-1.0)] {
                    landed = landed or patch_shot_lands(collision, center.add(offset.scale(12.0)), normal);
                }
                assert landed;
                chorded += 1;
            }
            back = collision.trace_point(center.sub(normal.scale(8.0)), center.add(normal.scale(24.0)));
            if back.fraction < 1.0 and collision.hulls[back.hull].facet {
                behind += 1;
            }
            if normal.z < 0.7 or walks >= 24 {
                continue;
            }
            origin = center.add(Vec3(z=40.0));
            if collision.trace(origin, origin).start_solid {
                continue;
            }
            walks += 1;
            for turn in range(4) {
                player = Player(pos=origin.add(Vec3(z=collision.eye_height)));
                for step in range(48) {
                    player spawn MovePlayer(collision=collision, game="q3");
                }
                assert player.grounded;
                angle = float(turn) * math.pi / 2.0 + 0.3;
                wish = Vec3(x=math.cos(angle), y=math.sin(angle));
                for step in range(60) {
                    before = player.pos;
                    player spawn MovePlayer(collision=collision, game="q3", wish=wish);
                    body = player.pos.sub(Vec3(z=collision.eye_height));
                    assert not collision.trace(body, body).start_solid;
                    if step > 20 and player.grounded {
                        frames += 1;
                        moved = Vec3(x=player.pos.x - before.x, y=player.pos.y - before.y);
                        if moved.length() < 0.05
                            and collision.trace(body, body.add(wish.scale(8.0))).fraction >= 1.0 {
                            stalls += 1;
                        }
                    }
                }
            }
        }
    }
    assert probes > 0 and walks > 0 and stalls == 0;
    print(
        name,
        probes,
        "patch probes,",
        chorded,
        "past a chord (by an outline or landing beside it),",
        behind,
        "stopped behind by another facet;",
        walks,
        "patch walks,",
        frames,
        "grounded frames, none stalled"
    );
}

with entry {
    game = os.getenv("QP_GAME", "q1");
    folder = "id1" if game == "q1" else ("baseq2" if game == "q2" else "baseq3");
    directory = os.getenv(
        "QP_ASSETS", os.getenv("HOME", "") + "/quake-assets/" + folder
    );
    maps = ["e1m1", "start", "e1m2", "e2m1", "e3m1", "e4m1"];
    if game == "q2" {
        maps = ["base1", "base2", "base3"];
    }
    if game == "q3" {
        maps = ["q3dm1", "q3dm7", "q3dm17", "q3tourney2"];
    }
    for name in maps {
        level = load_level(World(), directory, name, game);
        if game == "q3" {
            check_patches(level, name);
        }
        player = spawn_player(level);
        origin = player.pos.sub(Vec3(z=level.collision.eye_height));
        assert not level.collision.trace(origin, origin).start_solid;
        for i in range(240) {
            player spawn MovePlayer(collision=level.collision);
        }
        print(
            name,
            "settled",
            player.pos.x,
            player.pos.y,
            player.pos.z,
            "vz",
            player.velocity.z,
            "ground",
            player.grounded
        );
        assert player.grounded;
        grounded_height = player.pos.z;
        player spawn MovePlayer(collision=level.collision, jump=True);
        assert player.pos.z > grounded_height and player.velocity.z > 0.0;
        for i in range(240) {
            player spawn MovePlayer(collision=level.collision);
        }
        assert player.grounded;
        for i in range(480) {
            angle = float(i // 120) * math.pi / 2.0;
            player spawn MovePlayer(
                collision=level.collision,
                wish=Vec3(x=math.cos(angle), y=math.sin(angle))
            );
            origin = player.pos.sub(Vec3(z=level.collision.eye_height));
            assert not level.collision.trace(origin, origin).start_solid;
            assert math.isfinite(player.pos.z);
        }
        print(name, "collision, landing, jump, and four-direction movement passed");
    }
}
