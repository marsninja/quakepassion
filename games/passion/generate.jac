"""Compile a mission into a bounded, traversable twenty-room expedition."""
import from .plan { make_plan, seed_from, Contains, Chamber, Passage }
import from .geometry { Builder, partition }
import from engine.formats.bsp { Bsp, Texture, Model, Leaf, MapEntity }
import from engine.math.vec3 { Vec3 }
import from engine.world.level { Level, prepare_level }
import from engine.world.world { World }
import from engine.world.exits { LevelExit, HasExit }
import from engine.world.signals { HasSignal }
import from engine.physics.collision { CollisionMap }

def origin(point: Vec3) -> str {
    return str(point.x) + " " + str(point.y) + " " + str(point.z);
}

def entity(bsp: Bsp, kind: str, point: Vec3, source: str) {
    bsp.entities.append(MapEntity(fields={"classname": kind, "origin": origin(point), "asset_game": source}));
}

def generate(world: World, name: str, textures: list[Texture]) -> Level {
    plan = make_plan(seed_from(name));
    rooms = [plan->:Contains:->][?:Chamber];
    builder = Builder();
    bsp = builder.bsp;
    bsp.textures = textures;
    bsp.models.append(Model(head=0, first_face=0, face_count=0, vis_leaf_count=19));
    bsp.entities.append(MapEntity(fields={"classname": "worldspawn", "generator": "passion-v1"}));
    for room in rooms {
        bsp.leaves.append(Leaf(contents=0, vis_offset=0, cluster=-1,
            mins=Vec3(x=float(room.x) * 640.0, y=float(room.y) * 640.0, z=-64.0),
            maxs=Vec3(x=float(room.x + 1) * 640.0, y=float(room.y + 1) * 640.0, z=512.0)));
    }
    for room in rooms {
        builder.owner = room.index;
        x = float(room.x) * 640.0; y = float(room.y) * 640.0; z = float(room.y) * 32.0;
        material = room.theme * 2;
        ceiling = 320.0 if room.shape == 0 else (224.0 if room.shape == 1 else 384.0);
        builder.box(Vec3(x=x, y=y, z=z-32.0), Vec3(x=x+640.0, y=y+640.0, z=z), material);
        builder.box(Vec3(x=x, y=y, z=z+ceiling), Vec3(x=x+640.0, y=y+640.0, z=z+ceiling+16.0), material+1);
        neighbors = [room->:Passage:->][?:Chamber];
        for side in range(4) {
            dx = 1 if side == 0 else (-1 if side == 1 else 0);
            dy = 1 if side == 2 else (-1 if side == 3 else 0);
            opening = False;
            for neighbor in neighbors {
                if neighbor.x == room.x + dx and neighbor.y == room.y + dy { opening = True; }
            }
            across_x = side >= 2;
            wall = y + (640.0 if side == 2 else 0.0) if across_x else x + (640.0 if side == 0 else 0.0);
            for segment in range(3 if opening else 1) {
                first = 0.0; last = 640.0; bottom = z;
                if opening {
                    first = 0.0 if segment == 0 else (448.0 if segment == 1 else 192.0);
                    last = 192.0 if segment == 0 else (640.0 if segment == 1 else 448.0);
                    if segment == 2 { bottom = z + 176.0; }
                }
                inner_low = wall - 8.0 if side in [0, 2] else wall;
                inner_high = wall if side in [0, 2] else wall + 8.0;
                low = Vec3(x=x+first, y=inner_low, z=bottom) if across_x else Vec3(x=inner_low,y=y+first,z=bottom);
                high = Vec3(x=x+last,y=inner_high,z=z+ceiling) if across_x else Vec3(x=inner_high,y=y+last,z=z+ceiling);
                builder.box(low, high, material+1);
            }
            if opening and side == 2 {
                for step in range(4) {
                    builder.box(Vec3(x=x+192.0,y=y+512.0+float(step)*32.0,z=z),
                        Vec3(x=x+448.0,y=y+640.0,z=z+float(step+1)*8.0), material);
                }
            }
        }
        # Cover stays out of the central cross and all connector clearance.
        if room.role not in ["arrival", "extraction"] and room.index != 7 {
            for corner in range(2 if room.shape == 0 or room.role == "secret" else 4) {
                cx = x + (128.0 if corner % 2 == 0 else 512.0);
                cy = y + (512.0 if room.role == "secret" else (128.0 if corner < 2 else 512.0));
                height = 64.0 if room.shape == 1 else ceiling;
                builder.box(Vec3(x=cx-24.0,y=cy-24.0,z=z), Vec3(x=cx+24.0,y=cy+24.0,z=z+height), material+1);
            }
        }
        if room.role == "secret" {
            # Raised cache and stairs occupy a corner, preserving the route cross.
            builder.box(Vec3(x=x+48.0,y=y+32.0,z=z),Vec3(x=x+240.0,y=y+112.0,z=z+64.0),material);
            for stair in range(8) {
                builder.box(Vec3(x=x+96.0,y=y+112.0+float(stair)*16.0,z=z),
                    Vec3(x=x+192.0,y=y+128.0+float(stair)*16.0,z=z+float(8-stair)*8.0),material);
            }
            builder.box(Vec3(x=x+232.0,y=y+32.0,z=z+64.0),Vec3(x=x+240.0,y=y+112.0,z=z+112.0),material+1);
        }
        source = "q1" if room.theme == 0 else ("q2" if room.theme == 1 else "q3");
        if room.shape == 0 {
            for rib in [128.0, 512.0] {
                builder.box(Vec3(x=x+rib-12.0,y=y,z=z+ceiling-48.0),
                    Vec3(x=x+rib+12.0,y=y+640.0,z=z+ceiling),material);
            }
        }
        if room.index == 7 {
            # A climbable bridge crosses above the critical route, with an optional reward.
            builder.box(Vec3(x=x+96.0,y=y+288.0,z=z+112.0),Vec3(x=x+544.0,y=y+352.0,z=z+128.0),material);
            for stair in range(8) {
                builder.box(Vec3(x=x+96.0,y=y+32.0+float(stair)*32.0,z=z),
                    Vec3(x=x+192.0,y=y+64.0+float(stair)*32.0,z=z+float(stair+1)*16.0),material);
                builder.box(Vec3(x=x+448.0,y=y+352.0+float(stair)*32.0,z=z),
                    Vec3(x=x+544.0,y=y+384.0+float(stair)*32.0,z=z+float(8-stair)*16.0),material);
            }
            entity(bsp, "item_armor_combat", Vec3(x=x+320.0,y=y+320.0,z=z+152.0), "q2");
        }
        center = Vec3(x=x+320.0,y=y+320.0,z=z+24.0);
        if room.index == 0 {
            entity(bsp, "info_player_start", center, "q1");
            bsp.entities[-1].fields["angle"] = "90" if neighbors[0].y > room.y else "0";
        }
        elif room.role == "objective" {
            kind = "item_key2" if room.index == plan.key_rooms[0] else "item_key1";
            entity(bsp, kind, center, "q1");
        } elif room.role == "secret" {
            entity(bsp, "item_shells", Vec3(x=x+144.0,y=y+72.0,z=z+88.0), "q1");
            entity(bsp, "item_health", center, source);
        } elif room.role == "recovery" {
            entity(bsp, "item_health", center, source);
        } elif room.role == "encounter" {
            kind = "monster_army" if source == "q1" else ("monster_soldier" if source == "q2" else "info_player_deathmatch");
            entity(bsp, kind, center.add(Vec3(x=80.0)), source);
            entity(bsp, "item_shells" if source == "q1" else "ammo_shells", center.add(Vec3(x=-80.0)), source);
        }
    }
    # Extraction has one physical entrance, secured by both expedition keys.
    goal = rooms[19];
    parent = [goal->:Passage:->][?:Chamber][0];
    builder.owner = 19;
    z = float(goal.y) * 32.0;
    x = float(goal.x) * 640.0; y = float(goal.y) * 640.0;
    low = Vec3(x=x-8.0,y=y+192.0,z=z) if parent.x < goal.x else Vec3(x=x+192.0,y=y-8.0,z=z);
    high = Vec3(x=x+8.0,y=y+448.0,z=z+176.0) if parent.x < goal.x else Vec3(x=x+448.0,y=y+8.0,z=z+176.0);
    bsp.models.append(Model(head=-20,first_face=len(bsp.faces),face_count=0));
    builder.box(low, high, 5, 1);
    if parent.x < goal.x {
        builder.panel([Vec3(x=low.x-0.125,y=y+272.0,z=z+72.0),Vec3(x=low.x-0.125,y=y+272.0,z=z+120.0),
            Vec3(x=low.x-0.125,y=y+368.0,z=z+120.0),Vec3(x=low.x-0.125,y=y+368.0,z=z+72.0)],6,1);
    } else {
        builder.panel([Vec3(x=x+368.0,y=low.y-0.125,z=z+72.0),Vec3(x=x+368.0,y=low.y-0.125,z=z+120.0),
            Vec3(x=x+272.0,y=low.y-0.125,z=z+120.0),Vec3(x=x+272.0,y=low.y-0.125,z=z+72.0)],6,1);
    }
    bsp.entities.append(MapEntity(fields={"classname":"func_door", "model":"*1", "angle":"-1",
        "key":"key_gold key_silver", "wait":"-1", "speed":"160"}));
    bsp.models[0].head = partition(bsp, 0, 0, 5, 4);
    level = Level(active=True, name=name, bsp=bsp);
    level.asset_manifest = "|".join([texture.name for texture in textures]);
    if textures {
        level.asset_manifest += "|" + "|".join([
            ent.fields.get("asset_game", "passion") + ":" + ent.fields.get("classname", "")
            for ent in bsp.entities
        ]);
    }
    prepare_level(world, level);
    volume = CollisionMap();
    volume.add_box(Vec3(x=x+248.0,y=y+248.0,z=z), Vec3(x=x+392.0,y=y+392.0,z=z+96.0),
        Vec3(), Vec3(), Vec3());
    extraction = LevelExit(destination="passion_complete", contact=True, volume=volume);
    world +>:HasExit:+> extraction;
    world +>:HasSignal:+> extraction.activation;
    world +>:HasSignal:+> level.completion;
    validate_geometry(level, rooms);
    return level;
}

def validate_geometry(level: Level, rooms: list[Chamber]) {
    for room in rooms {
        center = Vec3(x=float(room.x)*640.0+320.0,y=float(room.y)*640.0+320.0,z=float(room.y)*32.0+46.125);
        if level.collision.trace(center, center).start_solid {
            raise ValueError("Blocked generated room center");
        }
        for neighbor in [room->:Passage:->][?:Chamber] {
            if neighbor.index <= room.index or neighbor.index == 19 { continue; }
            target = Vec3(x=float(neighbor.x)*640.0+320.0,y=float(neighbor.y)*640.0+320.0);
            previous = float(room.y)*32.0;
            for sample in range(41) {
                point = center.lerp(target, float(sample)/40.0);
                top = Vec3(x=point.x,y=point.y,z=float(max(room.y,neighbor.y))*32.0+64.0);
                bottom = Vec3(x=point.x,y=point.y,z=float(min(room.y,neighbor.y))*32.0-8.0);
                floor = level.collision.trace_point(top, bottom);
                if floor.start_solid or floor.fraction >= 1.0 {
                    raise ValueError("Unsupported passage " + str(room.index) + "-" + str(neighbor.index)
                        + " sample " + str(sample) + " solid=" + str(floor.start_solid) + " hit=" + str(floor.fraction));
                }
                standing = top.lerp(bottom,floor.fraction).add(Vec3(z=46.125));
                height = standing.z - 46.125;
                if abs(height-previous) > 18.1 or level.collision.trace(standing,standing).start_solid {
                    raise ValueError("Unwalkable generated passage");
                }
                previous = height;
            }
        }
    }
}
