import math;
import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { Plane3, Mapping, box_sides, brush_windings, classic_mapping }
import from editor.geometry.primitive { primitive_base, mapping_of_primitive, primitive_of_mapping, primitive_place }

def about(a: float, b: float, slack: float = 0.0001) -> bool {
    return abs(a - b) < slack;
}

test "the axes a face's texture is measured along follow from its normal" {
    # A floor: the first axis is +y and the second +x, as Quake III's tools have it.
    floor = primitive_base(Vec3(z=1.0));
    assert about(floor[0].y, 1.0) and about(floor[0].x, 0.0) and about(floor[1].x, 1.0) and about(floor[1].z, 0.0);
    # A wall facing +x: level along +y, and down the wall.
    wall = primitive_base(Vec3(x=1.0));
    assert about(wall[0].y, 1.0) and about(wall[1].z, -1.0) and about(wall[1].x, 0.0);
    # Whatever the face, the two are a unit long, square to each other and lie in the face.
    for normal in [Vec3(x=1.0), Vec3(y=-1.0), Vec3(z=-1.0), Vec3(x=0.6, y=0.0, z=0.8), Vec3(x=0.48, y=0.64, z=-0.6)] {
        pair = primitive_base(normal);
        assert about(pair[0].length(), 1.0) and about(pair[1].length(), 1.0) and about(pair[0].dot(pair[1]), 0.0);
        assert about(pair[0].dot(normal), 0.0) and about(pair[1].dot(normal), 0.0);
    }
}

test "a matrix that lays a texture once a repeat reads as a texel a unit" {
    floor = Plane3(normal=Vec3(z=1.0), dist=64.0);
    # A sixty-fourth of the texture a unit, along the tools' own axes, starting a quarter in.
    lay = mapping_of_primitive(floor, [1.0 / 64.0, 0.0, 0.25, 0.0, 1.0 / 64.0, 0.0], 64, 64);
    assert about(lay.s_axis.y, 1.0) and about(lay.t_axis.x, 1.0) and about(lay.s_scale, 1.0) and about(lay.t_scale, 1.0);
    assert about(lay.s_shift, 16.0) and about(lay.t_shift, 0.0);
    spot = lay.texel(Vec3(x=10.0, y=20.0, z=64.0));
    assert about(spot[0], 36.0) and about(spot[1], 10.0);
    # A texture twice as wide takes twice the units to repeat at the same matrix.
    wide = mapping_of_primitive(floor, [1.0 / 64.0, 0.0, 0.25, 0.0, 1.0 / 64.0, 0.0], 128, 64);
    assert about(wide.s_scale, 0.5) and about(wide.s_shift, 32.0) and about(wide.t_scale, 1.0);
    # A matrix that is no way to lie gives the way a new brush has.
    flat = mapping_of_primitive(floor, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], 64, 64);
    fresh = classic_mapping(floor.normal, 0.0, 0.0, 0.0, 1.0, 1.0);
    assert about(flat.s_axis.sub(fresh.s_axis).length(), 0.0) and about(flat.s_scale, 1.0);
    assert about(mapping_of_primitive(floor, [1.0], 64, 64).t_scale, 1.0);
}

test "a material's lie goes to a matrix and back with every texel where it was" {
    sides = box_sides(Vec3(x=-32.0, y=-64.0, z=0.0), Vec3(x=96.0, y=64.0, z=48.0), "wall");
    outlines = brush_windings(sides);
    for (index, side) in enumerate(sides) {
        # Turned, stretched and slid, and leaning a little out of the face.
        lean = side.plane.normal.scale(0.3);
        lay = Mapping(
            s_axis=side.mapping.s_axis.scale(0.8).add(side.mapping.t_axis.scale(0.6)).add(lean).normalized(),
            t_axis=side.mapping.t_axis.scale(0.8).sub(side.mapping.s_axis.scale(0.6)),
            s_shift=13.0,
            t_shift=-7.5,
            s_scale=0.5,
            t_scale=2.0
        );
        matrix = primitive_of_mapping(side.plane, lay, 128, 64);
        back = mapping_of_primitive(side.plane, matrix, 128, 64);
        for corner in outlines[index] {
            was = lay.texel(corner);
            now = back.texel(corner);
            assert about(was[0], now[0], 0.001) and about(was[1], now[1], 0.001) , str(index);
            # And the compiler's own sum gives that texel as a share of the texture.
            share = primitive_place(side.plane, matrix, corner);
            assert about(share[0] * 128.0, was[0], 0.001) and about(share[1] * 64.0, was[1], 0.001);
        }
        # Read back, the axes lie in the face.
        assert about(back.s_axis.dot(side.plane.normal), 0.0) and about(back.t_axis.dot(side.plane.normal), 0.0);
    }
}
