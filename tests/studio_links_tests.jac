import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene, FaceEdit, scene_map, scene_from_map, planes_meet }
import from editor.geometry.brush { box_sides, brush_volume, Plane3 }
import from editor.formats.map { read_map, write_map }

def about(a: float, b: float, slack: float = 0.01) -> bool {
    return abs(a - b) < slack;
}

"""Three boxes in a row along x, each 64 a side, with their tops in one
plane; and a fourth standing apart, twice as tall."""
def row -> Scene {
    scene = Scene(game="passion", name="studio:test");
    world = scene.world();
    for index in range(3) {
        low = Vec3(x=64.0 * float(index), y=0.0, z=0.0);
        scene.add_solid(world, box_sides(low, low.add(Vec3(x=64.0, y=64.0, z=64.0)), "wall"));
    }
    scene.add_solid(world, box_sides(Vec3(x=0.0, y=128.0, z=0.0), Vec3(x=64.0, y=192.0, z=128.0), "wall"));
    return scene;
}

"""Which side of a brush faces a way."""
def facing(scene: Scene, index: int, way: Vec3) -> int {
    solid = scene.solids()[index];
    for (number, side) in enumerate(solid.sides) {
        if side.plane.normal.dot(way) > 0.99 {
            return number;
        }
    }
    return -1;
}

test "planes are one plane when they lie together, whichever way they face" {
    up = Plane3(normal=Vec3(z=1.0), dist=64.0);
    assert planes_meet(up, Plane3(normal=Vec3(z=1.0), dist=64.0)) and planes_meet(up, Plane3(normal=Vec3(z=-1.0), dist=-64.0));
    assert not planes_meet(up, Plane3(normal=Vec3(z=1.0), dist=65.0)) and not planes_meet(up, Plane3(normal=Vec3(x=1.0), dist=64.0));
    assert not planes_meet(up, Plane3(normal=Vec3(z=-1.0), dist=64.0));
}

test "linked faces are pushed together, through however many links, and undone together" {
    scene = row();
    boxes = scene.solids();
    top = Vec3(z=1.0);
    # The first's top to the second's, the second's to the third's.
    assert scene.link_sides(boxes[0], facing(scene, 0, top), boxes[1], facing(scene, 1, top));
    assert scene.link_sides(boxes[2], facing(scene, 2, top), boxes[1], facing(scene, 1, top));
    assert scene.link_count() == 2;
    # Linked already, not in one plane, or one brush with itself: refused.
    assert not scene.link_sides(boxes[1], facing(scene, 1, top), boxes[0], facing(scene, 0, top));
    assert not scene.link_sides(boxes[0], facing(scene, 0, top), boxes[3], facing(scene, 3, top));
    assert not scene.link_sides(boxes[0], facing(scene, 0, top), boxes[0], facing(scene, 0, top));
    tied = scene.linked_sides(boxes[0], facing(scene, 0, top));
    assert len(tied) == 2;
    # Pushing the third's top up sixteen lifts all three; the fourth is left.
    assert scene.push_side(boxes[2], facing(scene, 2, top), 16.0);
    for index in range(3) {
        box = boxes[index].bounds();
        assert box is not None and about(box[1].z, 80.0) , str(index);
    }
    fourth = boxes[3].bounds();
    assert fourth is not None and about(fourth[1].z, 128.0);
    # They are still linked where they now lie, and one undo puts all three back.
    assert len(scene.linked_sides(boxes[1], facing(scene, 1, top))) == 2;
    assert scene.undo() == "Resize";
    for index in range(3) {
        box = boxes[index].bounds();
        assert box is not None and about(box[1].z, 64.0);
    }
    # A push that would leave any of them with nothing inside moves none.
    assert not scene.push_side(boxes[0], facing(scene, 0, top), -64.0);
    box = boxes[1].bounds();
    assert box is not None and about(box[1].z, 64.0);
    # A side with no links is pushed alone, as before.
    assert scene.push_side(boxes[0], facing(scene, 0, Vec3(y=-1.0)), 8.0);
    assert about(brush_volume(boxes[0].sides), 64.0 * 72.0 * 64.0) and about(brush_volume(boxes[1].sides), 64.0 * 64.0 * 64.0);
}

test "a side is taken out of its links, and a brush that is gone is not pushed" {
    scene = row();
    boxes = scene.solids();
    top = Vec3(z=1.0);
    scene.link_sides(boxes[0], facing(scene, 0, top), boxes[1], facing(scene, 1, top));
    scene.link_sides(boxes[1], facing(scene, 1, top), boxes[2], facing(scene, 2, top));
    # The middle one deleted: the first's top has nothing left to carry.
    scene.select_solid(boxes[1]);
    assert scene.remove_selection();
    assert len(scene.linked_sides(boxes[0], facing(scene, 0, top))) == 0 and scene.link_count() == 0;
    assert scene.undo() and len(scene.linked_sides(boxes[0], facing(scene, 0, top))) == 2 and scene.link_count() == 2;
    assert scene.unlink_side(boxes[1], facing(scene, 1, top)) == 2 and scene.link_count() == 0;
    assert scene.unlink_side(boxes[1], facing(scene, 1, top)) == 0;
    # The faces picked are linked with the first of them; one out of the plane is passed over.
    scene.select_face(boxes[0], facing(scene, 0, top));
    scene.select_face(boxes[2], facing(scene, 2, top), True);
    scene.select_face(boxes[3], facing(scene, 3, top), True);
    assert scene.link_faces() == 1 and scene.link_count() == 1;
    assert scene.push_side(boxes[0], facing(scene, 0, top), 8.0);
    third = boxes[2].bounds();
    assert third is not None and about(third[1].z, 72.0);
}

test "the faces a cut left in pieces are linked, and links are kept in the map" {
    scene = row();
    boxes = scene.solids();
    # The tops, bottoms, fronts and backs of the three in the row each lie
    # in one plane: two links tie three faces, the third pair being tied
    # through them already.
    made = scene.link_coplanar(boxes[:3]);
    assert made == 4 * 2 and scene.link_count() == 8;
    front = Vec3(y=-1.0);
    assert scene.push_side(boxes[1], facing(scene, 1, front), 16.0);
    for index in range(3) {
        box = boxes[index].bounds();
        assert box is not None and about(box[0].y, -16.0);
    }
    text = write_map(scene_map(scene));
    assert '"_links" "' in text and "_links" not in scene.world().fields;
    again = scene_from_map("passion", "studio:again", read_map(text));
    assert again.link_count() == 8 and not again.dirty and "_links" not in again.world().fields;
    others = again.solids();
    assert again.push_side(others[0], facing(again, 0, Vec3(z=1.0)), 32.0);
    last = others[2].bounds();
    assert last is not None and about(last[1].z, 96.0);
}

test "two brushes that overlap at a corner are cut to meet in a seam" {
    scene = Scene(game="passion", name="studio:test");
    world = scene.world();
    # Two walls 16 thick meeting at a right angle, each running through the corner.
    scene.add_solid(world, box_sides(Vec3(x=0.0, y=0.0, z=0.0), Vec3(x=128.0, y=16.0, z=64.0), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=0.0, y=0.0, z=0.0), Vec3(x=16.0, y=128.0, z=64.0), "wall"));
    walls = scene.solids();
    before = brush_volume(walls[0].sides) + brush_volume(walls[1].sides);
    scene.select_solid(walls[0]);
    scene.select_solid(walls[1], True);
    assert scene.miter_selection();
    # Each loses half of the corner they shared: together they hold it once.
    after = brush_volume(walls[0].sides) + brush_volume(walls[1].sides);
    assert about(before - after, 16.0 * 16.0 * 64.0, 1.0);
    assert about(brush_volume(walls[0].sides), brush_volume(walls[1].sides), 1.0);
    assert len(walls[0].sides) == 7 or len(walls[0].sides) == 6;
    first = walls[0].bounds();
    second = walls[1].bounds();
    assert first is not None and second is not None and about(first[1].x, 128.0) and about(second[1].y, 128.0);
    assert scene.undo() == "Miter" and about(brush_volume(walls[0].sides) + brush_volume(walls[1].sides), before);
    # Brushes apart, or one alone, have no seam to cut.
    scene.clear_selection();
    scene.select_solid(walls[0]);
    assert not scene.miter_selection();
    far = scene.add_solid(world, box_sides(Vec3(x=400.0, y=400.0, z=0.0), Vec3(x=464.0, y=464.0, z=64.0), "wall"));
    scene.select_solid(far, True);
    assert not scene.miter_selection();
}

test "a corner moved onto another leaves one where two were" {
    scene = Scene(game="passion", name="studio:test");
    box = scene.add_solid(scene.world(), box_sides(Vec3(), Vec3(x=64.0, y=64.0, z=64.0), "wall"));
    assert len(box.sides) == 6;
    # The top corner at (64, 64, 64) down onto the one beneath it.
    assert scene.merge_corners(box, Vec3(x=64.0, y=64.0, z=64.0), Vec3(x=64.0, y=64.0, z=0.0));
    assert brush_volume(box.sides) < 64.0 * 64.0 * 64.0 and brush_volume(box.sides) > 0.0;
    high = box.bounds();
    assert high is not None and about(high[1].z, 64.0);
    assert scene.undo() == "Merge corners" and about(brush_volume(box.sides), 262144.0);
    assert not scene.merge_corners(box, Vec3(x=64.0, y=64.0, z=64.0), Vec3(x=64.0, y=64.0, z=64.0));
}

test "linked faces share one material, painted or edited from any of them, as one step" {
    scene = row();
    boxes = scene.solids();
    top = Vec3(z=1.0);
    assert scene.link_sides(boxes[0], facing(scene, 0, top), boxes[1], facing(scene, 1, top));
    assert scene.link_sides(boxes[2], facing(scene, 2, top), boxes[1], facing(scene, 1, top));
    # One top painted: all three tops take it; their sides and the fourth keep theirs.
    assert scene.paint_face(boxes[2], facing(scene, 2, top), "metal");
    for index in range(3) {
        assert boxes[index].sides[facing(scene, index, top)].material == "metal" , str(index);
        assert boxes[index].sides[facing(scene, index, Vec3(y=-1.0))].material == "wall";
    }
    assert boxes[3].sides[facing(scene, 3, top)].material == "wall";
    assert scene.undo() == "Paint face";
    for index in range(3) {
        assert boxes[index].sides[facing(scene, index, top)].material == "wall";
    }
    # An edit of a picked face reaches its links once, however many links lead there.
    scene.select_face(boxes[0], facing(scene, 0, top));
    assert scene.reface(FaceEdit(how="shift", s=8.0, t=0.0), "Shift");
    shifted = [boxes[index].sides[facing(scene, index, top)].mapping.s_shift for index in range(3)];
    assert shifted[0] == shifted[1] and shifted[1] == shifted[2] and shifted[0] != 0.0;
    assert boxes[3].sides[facing(scene, 3, top)].mapping.s_shift == 0.0;
    # A material given the whole of one brush gives its linked top to the others too.
    scene.clear_selection();
    scene.select_solid(boxes[1]);
    assert scene.reface(FaceEdit(how="material", material="stone"), "Material");
    assert boxes[0].sides[facing(scene, 0, top)].material == "stone" and boxes[2].sides[facing(scene, 2, top)].material == "stone";
    assert boxes[0].sides[facing(scene, 0, Vec3(y=-1.0))].material == "wall";
}
