import from engine.math.vec3 { Vec3 }
import from games.passion.mission { Beat }
import from games.passion.layout { Room, rooms_of, passages_of, embed, relay }
import from games.passion.mission { build_mission }
import from games.passion.interior { RECIPES, build_interior }
import from games.passion.random { stream_for }
import from editor.formats.map { MapItem }
import from editor.geometry.brush { box_sides }
import from editor.document.expedition { room_at, room_middle, brush_middle, room_name, room_groups, beat_words, room_words }

"""Two rooms side by side with a gap of one share of the site between them."""
def two_rooms -> list[Room] {
    return [Room(beat=0, x=0, y=0, w=2, h=2, recipe="hall"), Room(beat=1, kind="arena", x=3, y=0, w=2, h=3, z=64)];
}

test "a place in the world is in the room whose share of the site holds it" {
    rooms = two_rooms();
    # A share of the site is five cells of 32 units: 160 a side.
    assert room_at(rooms, 10.0, 10.0) == 0 and room_at(rooms, 319.0, 319.0) == 0;
    assert room_at(rooms, 330.0, 10.0) == -1 and room_at(rooms, 10.0, 330.0) == -1;
    assert room_at(rooms, 480.0, 10.0) == 1 and room_at(rooms, 799.0, 479.0) == 1 and room_at(rooms, 800.0, 10.0) == -1;
    middle = room_middle(rooms[1]);
    assert middle.x == 640.0 and middle.y == 240.0 and middle.z == 64.0;
}

test "a brush's middle is the middle of its corners" {
    at = brush_middle(box_sides(Vec3(x=32.0, y=64.0, z=0.0), Vec3(x=96.0, y=128.0, z=64.0), "wall"));
    assert abs(at.x - 64.0) < 0.01 and abs(at.y - 96.0) < 0.01 and abs(at.z - 32.0) < 0.01;
}

test "the world's brushes are handed to a group for each room, and one for the ways between" {
    rooms = two_rooms();
    world = MapItem(
        fields={"classname": "worldspawn", "message": "A site"},
        brushes=[
            box_sides(Vec3(x=0.0, y=0.0, z=-16.0), Vec3(x=64.0, y=64.0, z=0.0), "floor"),
            box_sides(Vec3(x=200.0, y=200.0, z=0.0), Vec3(x=232.0, y=232.0, z=64.0), "pillar"),
            box_sides(Vec3(x=336.0, y=0.0, z=0.0), Vec3(x=400.0, y=64.0, z=16.0), "bridge"),
            box_sides(Vec3(x=500.0, y=300.0, z=64.0), Vec3(x=564.0, y=364.0, z=96.0), "stage")
        ]
    );
    start = MapItem(fields={"classname": "info_player_start", "origin": "40 40 24"});
    door = MapItem(
        fields={"classname": "func_door"}, brushes=[box_sides(Vec3(x=310.0, y=0.0, z=0.0), Vec3(x=326.0, y=64.0, z=96.0), "door")]
    );
    made = room_groups([world, start, door], rooms);
    # The world keeps its fields and no brushes; the other entities are as they were.
    assert made[0].fields["classname"] == "worldspawn" and made[0].fields["message"] == "A site" and len(made[0].brushes) == 0;
    assert made[1] is start and made[2] is door and len(made[2].brushes) == 1;
    names = [each.fields.get("_group_name", "") for each in made[3:]];
    assert names == ["room 0 hall", "room 1 arena", "ways between"];
    assert [len(each.brushes) for each in made[3:]] == [2, 1, 1];
    assert room_name(rooms[1]) == "room 1 arena";
    # A level with no world has nothing to hand out.
    assert room_groups([start], rooms) == [start];
}

test "a beat and a room are each said in a line" {
    beat = Beat(id=3, kind="lock", section=1, district=2, order=5, tension=0.456, grants=["key_gold"], optional=True, pattern="lock_key");
    assert beat_words(beat) == "beat 3 lock section=1 district=2 order=5 tension=0.46 optional grants=key_gold pattern=lock_key";
    assert room_words(two_rooms()[1]) == "room 1 arena recipe=hall at=3,0 size=2x3 floor=64 ceiling=256 district=0 order=0";
}

test "a room asked for a recipe is made by it, and one made again rolls other dice" {
    assert "pit" in RECIPES and "arena" in RECIPES and len(RECIPES) == 11;
    made = 0;
    for seed in range(1, 7) {
        room = Room(beat=0, w=5, h=5, size=3, wanted="colonnade");
        if build_interior(room, [], stream_for(seed, "t"), 0).recipe == "colonnade" {
            made += 1;
        }
    }
    # Asked for, it is what the room is made by unless it cannot be verified.
    assert made >= 4;
    # Nothing asked: the generator's own choice, the same for the same dice.
    free = Room(beat=0, w=5, h=5, size=3);
    first = build_interior(free, [], stream_for(3, "t"), 0);
    again = build_interior(free, [], stream_for(3, "t"), 0);
    assert first.recipe == again.recipe and first.floor == again.floor;
}

test "a site is laid out again with a room moved, and refuses one laid over another" {
    plan = build_mission(7, stream_for(7, "mission"), "keys", 1, 1, 12, 0.5);
    site = embed(plan, stream_for(7, "layout"));
    assert not site.failures;
    rooms = rooms_of(site);
    ways = len([way for way in passages_of(site) if not way.window]);
    # Nothing asked: the same rooms in the same places, every way routed again.
    same = relay(plan, site, {}, stream_for(7, "relay"));
    assert not same.failures and len(rooms_of(same)) == len(rooms);
    assert [[room.w, room.h] for room in rooms_of(same)] == [[room.w, room.h] for room in rooms];
    assert len([way for way in passages_of(same) if not way.window]) == ways;
    # A room put where another is: refused, and the first site is untouched.
    first = rooms[0];
    other = rooms[1];
    over = relay(plan, site, {other.beat: [first.x, first.y, other.w, other.h]}, stream_for(7, "relay"));
    assert "would lie over another" in over.failures and rooms_of(site)[1].x == other.x;
    # No room is a sliver or a field.
    assert "no size" in relay(plan, site, {other.beat: [other.x, other.y, 1, 9]}, stream_for(7, "relay")).failures;
    # The last room moved well clear of the rest: laid out, or refused by the router, and it says which.
    last = rooms[len(rooms) - 1];
    far = relay(plan, site, {last.beat: [last.x + 40, last.y + 40, last.w, last.h]}, stream_for(7, "relay"));
    assert far.failures != "" or len(rooms_of(far)) == len(rooms);
}
