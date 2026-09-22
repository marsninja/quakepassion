import from games.passion.plan { make_plan, Contains, Chamber, Passage, seed_from }
test "seeded expeditions have connected objectives and stable topology" {
    for seed in range(1, 31) {
        a = make_plan(seed); b = make_plan(seed);
        ar = [a->:Contains:->][?:Chamber]; br = [b->:Contains:->][?:Chamber];
        assert a.key_rooms == b.key_rooms;
        for index in range(20) {
            assert ar[index].theme == br[index].theme;
            assert [r.index for r in [ar[index]->:Passage:->][?:Chamber]]
                == [r.index for r in [br[index]->:Passage:->][?:Chamber]];
        }
    }
}
test "generation versions and invalid seeds are rejected" {
    for value in ["v2-1", "v1-0", "v1-2147483647", "v1-01", "v1--2"] {
        rejected = False;
        try { seed_from(value); } except ValueError { rejected = True; }
        assert rejected;
    }
}

import from games.passion.generate { generate }
import from engine.world.world { World, Player }
import from engine.math.vec3 { Vec3 }
import from engine.physics.movement { MovePlayer }
import from engine.world.doors { Door, HasDoor }

test "generated collision keeps routes open and extraction locked" {
    world = World();
    level = generate(world, "v1-42", []);
    plan = make_plan(42);
    rooms = [plan->:Contains:->][?:Chamber];
    for room in rooms {
        center = Vec3(x=float(room.x)*640.0+320.0,y=float(room.y)*640.0+320.0,z=float(room.y)*32.0+46.0);
        assert level.locate(center) == room.index;
        assert not level.collision.trace(center, center).start_solid;
    }
    door = [world->:HasDoor:->][?:Door][0];
    assert door.keys == ["key_gold", "key_silver"] and not door.unlocked;
    # Exercise real stair stepping in both directions, not only graph reachability.
    tested = False;
    for room in rooms {
        if tested { break; }
        for other in [room->:Passage:->][?:Chamber] {
            if other.y != room.y + 1 or other.index == 19 { continue; }
            for reverse in [False, True] {
                first = other if reverse else room;
                last = room if reverse else other;
                player = Player(pos=Vec3(x=float(first.x)*640.0+320.0,y=float(first.y)*640.0+320.0,z=float(first.y)*32.0+46.0));
                target = Vec3(x=float(last.x)*640.0+320.0,y=float(last.y)*640.0+320.0,z=float(last.y)*32.0+46.0);
                for step in range(400) {
                    delta = target.sub(player.pos);
                    if abs(delta.y) < 8.0 { break; }
                    player spawn MovePlayer(collision=level.collision,wish=Vec3(y=-1.0 if reverse else 1.0),dt=1.0/120.0);
                }
                assert abs(player.pos.y-target.y) < 8.0;
                assert abs(player.pos.z-target.z) < 2.0;
            }
            tested = True; break;
        }
    }
    assert tested;
}

import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.world.combat { CombatState }
test "saved asset manifests must match the generated level" {
    world = World();
    level = Level(asset_manifest="q1:stone|q2:metal|q3:blocks");
    player = Player();
    data = snapshot(world, level, player, CombatState());
    restore(world, level, player, CombatState(), data);
    level.asset_manifest = "changed";
    rejected = False;
    try { restore(world, level, player, CombatState(), data); }
    except ValueError { rejected = True; }
    assert rejected;
}

test "optional bridge can be climbed and crossed above the main route" {
    level = generate(World(), "v1-42", []);
    base = Vec3(x=1280.0,y=640.0,z=32.0);
    player = Player(pos=base.add(Vec3(x=256.0,y=40.0,z=46.0)));
    for waypoint in [Vec3(x=144.0,y=40.0),Vec3(x=144.0,y=320.0),Vec3(x=496.0,y=320.0)] {
        target = base.add(waypoint);
        for tick in range(300) {
            delta = target.sub(player.pos);
            if Vec3(x=delta.x,y=delta.y).length() < 4.0 { break; }
            player spawn MovePlayer(collision=level.collision,wish=Vec3(x=delta.x,y=delta.y).normalized(),dt=1.0/120.0);
        }
        assert Vec3(x=target.x-player.pos.x,y=target.y-player.pos.y).length() < 4.0;
        player.velocity = Vec3();
    }
    assert abs(player.pos.z - 206.0) < 2.0;
}

import from engine.physics.collision { CollisionMap }
test "point traces hit a floor along an adjoining brush seam" {
    collision = CollisionMap();
    for x in [-10.0, 0.0] {
        collision.add_box(Vec3(x=x,y=-10.0,z=-2.0),Vec3(x=x+10.0,y=10.0,z=0.0),
            Vec3(),Vec3(),Vec3());
    }
    hit = collision.trace_point(Vec3(z=10.0),Vec3(z=-10.0));
    assert not hit.start_solid and abs(hit.fraction-0.5) < 0.00001;
    assert hit.normal.z == 1.0;
}
