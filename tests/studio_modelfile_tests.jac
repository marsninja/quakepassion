import from engine.math.vec3 { Vec3 }
import from editor.model.mesh { Mesh, mesh_volume }
import from editor.model.primitives { primitive_mesh }
import from editor.model.document { ModelDoc, Reshape }
import from editor.model.files { doc_from_model, write_mdl, mdl_limits, palette_indices, grey_palette, turned_about }
import from editor.model.work { work_text, doc_from_work }
import from engine.formats.q1.model { parse_mdl }

def about(a: float, b: float, slack: float = 0.01) -> bool {
    return abs(a - b) < slack;
}

"""A box 64 by 32 by 16 on the origin."""
def crate -> Mesh {
    made = Mesh();
    for z in [0.0, 16.0] {
        for (x, y) in [(0.0, 0.0), (64.0, 0.0), (64.0, 32.0), (0.0, 32.0)] {
            made.points.append(Vec3(x=x, y=y, z=z));
            made.uvs.append(x / 64.0);
            made.uvs.append(y / 32.0);
        }
    }
    made.corners = [
        0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7, 0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5, 2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7
    ];
    return made;
}

"""A model of one crate with three frames, the lid a little higher in each."""
def lifting -> ModelDoc {
    doc = ModelDoc(name="crate");
    doc.add_part("box", crate(), ["skins/crate"]);
    assert doc.copy_frame(0, "half") == 1 and doc.copy_frame(1, "open") == 2;
    for frame in [1, 2] {
        doc.frame = frame;
        doc.pick_faces([2, 3]);
        assert doc.reshape(Reshape(kind="move", picks=doc.parts()[0].picked_points, vector=Vec3(z=8.0 * float(frame)), only=frame), "Lift");
    }
    doc.frame = 0;
    doc.pick_points([]);
    return doc;
}

test "a model written as a Quake MDL is one mesh the engine reads, with its skin in it" {
    doc = lifting();
    doc.add_part("knob", primitive_mesh("sphere", Vec3(x=0.0, y=0.0, z=40.0), Vec3(x=16.0, y=16.0, z=56.0), 8));
    assert mdl_limits(doc) == [];
    # A skin of two colours of the palette: the top half one, the bottom the other.
    palette = grey_palette();
    picture = bytearray();
    for row in range(32) {
        for column in range(64) {
            picture.extend(bytes([40, 40, 40, 255] if row < 16 else [200, 201, 199, 255]));
        }
    }
    skin = palette_indices(bytes(picture), palette);
    assert len(skin) == 64 * 32 and int(skin[0]) == 40 and int(skin[64 * 32 - 1]) == 200;
    # Nothing is given one of the last thirty-two colours, which Quake draws unlit.
    assert int(palette_indices(bytes([255, 255, 255, 255]), palette)[0]) == 223;
    data = write_mdl(doc, 64, 32, skin);
    assert data[:4] == b"IDPO" and len(data) > 84 + 64 * 32;
    read = parse_mdl(data, palette);
    assert len(read.surfaces) == 1;
    surface = read.surfaces[0];
    box_part = doc.parts()[0];
    knob = doc.parts()[1];
    assert len(surface.indices) == len(box_part.corners) + len(knob.corners) and len(surface.frames) == 3;
    assert surface.indices[:36] == turned_about(box_part.corners) and surface.indices[36] == 8 + turned_about(knob.corners)[0];
    assert surface.frames[0].name == "frame 0" and surface.frames[2].name == "open";
    assert len(surface.frames[0].vertices) == 8 + len(doc.poses(knob)[0].points);
    for frame in range(3) {
        for (index, point) in enumerate(doc.poses(box_part)[frame].points) {
            # A byte an axis across the box round every frame: within a 255th of it.
            assert about(surface.frames[frame].vertices[index].sub(point).length(), 0.0, 0.3) , str(frame) + " " + str(index);
        }
    }
    # A place on the skin comes back to within a texel, and the skin as it was given.
    first = turned_about(box_part.corners)[1];
    assert about(surface.uv[2], box_part.uvs[first * 2], 1.0 / 64.0) and about(surface.uv[3], box_part.uvs[first * 2 + 1], 1.0 / 32.0);
    assert len(surface.embedded_skins) == 1 and surface.embedded_skins[0].width == 64 and surface.embedded_skins[0].height == 32;
    texels = surface.embedded_skins[0].pixels;
    assert int(texels[0]) == 40 and int(texels[(64 * 32 - 1) * 4]) == 200 and int(texels[3]) == 255;
    # As a graph again it is one part that holds what the two did.
    again = doc_from_model(read, "crate");
    assert len(again.parts()) == 1 and again.frames() == 3 and again.faults() == [];
    held = mesh_volume(doc.mesh(box_part, 0)) + mesh_volume(doc.mesh(knob, 0));
    assert about(mesh_volume(again.mesh(again.parts()[0], 0)), held, held * 0.02);
    # Without a skin of the right size it is one grey; an empty model is not written.
    plain = parse_mdl(write_mdl(doc, 16, 16, skin), palette);
    assert int(plain.surfaces[0].embedded_skins[0].pixels[0]) == 8 and len(mdl_limits(ModelDoc())) == 2 and write_mdl(ModelDoc()) == b"";
}

test "a work file keeps a model as it is: poses, picks, tags, bones and what was in hand" {
    doc = lifting();
    doc.add_part("knob", primitive_mesh("sphere", Vec3(x=0.0, y=0.0, z=40.0), Vec3(x=16.0, y=16.0, z=56.0), 8), ["skins/knob", "skins/knob glow"]);
    # A point no byte could keep, a tag turned at one frame, bones that carry points by weight.
    box_part = doc.parts()[0];
    doc.part_now = 0;
    doc.frame = 1;
    assert doc.reshape(Reshape(kind="move", picks=[6], vector=Vec3(x=0.123456, y=-0.5), only=1), "Nudge");
    hook = doc.add_tag("tag_hook", Vec3(x=4.0, y=5.5, z=6.0));
    assert hook is not None;
    hook.origins[2] = Vec3(x=4.0, y=5.5, z=22.25);
    hook.axes[2] = [Vec3(y=1.0), Vec3(x=-1.0), Vec3(z=1.0)];
    assert doc.add_bone("upper", Vec3(), Vec3(z=16.0)) is not None and doc.continue_bone("upper", "fore", Vec3(z=32.0)) is not None;
    assert doc.hold_points("upper", [0, 1, 2, 3, 4]) == 5 and doc.hold_points("fore", [4, 5, 6, 7], 0.5) == 4;
    doc.pick_faces([2, 3]);
    text = work_text(doc);
    assert text.startswith("qpmodel 1\nmodel crate\nhand 1 0\npart box\nskin skins/crate\n") and "\nrig\n" in text;
    again = doc_from_work(text);
    assert again is not None;
    assert again.name == "crate" and again.frame == 1 and again.part_now == 0 and not again.dirty and again.faults() == [];
    assert [part.name for part in again.parts()] == ["box", "knob"] and again.frames() == 3;
    assert again.parts()[1].skins == ["skins/knob", "skins/knob glow"] and again.frame_name(2) == "open";
    for (number, part) in enumerate(doc.parts()) {
        other = again.parts()[number];
        assert other.corners == part.corners and other.uvs == part.uvs;
        for (frame, pose) in enumerate(doc.poses(part)) {
            for (index, point) in enumerate(pose.points) {
                assert about(again.poses(other)[frame].points[index].sub(point).length(), 0.0, 0.00001);
            }
        }
    }
    assert about(again.poses(again.parts()[0])[1].points[6].x, 64.123456, 0.0000011);
    assert again.parts()[0].picked_faces == [2, 3] and again.parts()[0].picked_points == box_part.picked_points;
    kept = again.tag("tag_hook");
    assert kept is not None and len(kept.origins) == 3 and about(kept.origins[2].z, 22.25) and about(kept.axes[2][1].x, -1.0);
    assert [bone.name for bone in again.bones()] == ["upper", "fore"];
    assert again.point_shares(4) == [("upper", 0.5), ("fore", 0.5)] and again.point_shares(0) == [("upper", 1.0)];
    # Written again it is the same text.
    assert work_text(again) == text;
    # What is not a work file, or is one with a part that points past its points, is no model.
    assert doc_from_work("") is None and doc_from_work("IDP3") is None and doc_from_work("qpmodel 1\n") is None;
    assert doc_from_work(text.replace("corners 0 2 1", "corners 0 2 99")) is None;
    assert doc_from_work(text.replace("points 0 0 0", "points 0 0 zero")) is None;
    assert doc_from_work("qpmodel 1\npose stray\n") is None;
}
