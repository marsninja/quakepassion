import from engine.math.vec3 { Vec3 }
import from games.passion.mission { Beat }
import from games.passion.layout { Room }
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
