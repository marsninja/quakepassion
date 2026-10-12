import math;
import from engine.math.vec3 { Vec3 }
import from editor.camera { EditCamera, axis_camera, depth_cut, depth_of }

test "a band of depth is cut as distances along the line of sight" {
    # Looking down from above: the band along z, nearer at its top.
    top = axis_camera("top");
    top.eye = Vec3(z=1000.0);
    assert depth_cut(top) == [0.0, 0.0];
    top.bounded = True;
    top.depth_low = 0.0;
    top.depth_high = 128.0;
    cut = depth_cut(top);
    assert abs(cut[0] - 872.0) < 0.001 and abs(cut[1] - 1000.0) < 0.001;
    assert depth_of(top, Vec3(x=50.0, z=64.0)) == 64.0;
    # A perspective view, or a band that is nothing, sees every depth.
    seen = EditCamera(eye=Vec3(), span=0.0, bounded=True, depth_low=0.0, depth_high=10.0);
    assert depth_cut(seen) == [0.0, 0.0];
    top.depth_high = top.depth_low;
    assert depth_cut(top) == [0.0, 0.0];
}

test "a view that looks along an axis has the band the nearer end first" {
    front = axis_camera("front");
    front.bounded = True;
    front.depth_low = -32.0;
    front.depth_high = 32.0;
    ahead = front.forward();
    axis = front.depth_axis();
    front.eye = axis.scale(-500.0 if ahead.dot(axis) > 0.0 else 500.0);
    cut = depth_cut(front);
    assert abs(cut[0] - 468.0) < 0.001 and abs(cut[1] - 532.0) < 0.001;
}
