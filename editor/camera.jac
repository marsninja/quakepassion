"""The studio's free camera, and the geometry of looking through it: the ray
under a point of its view and where a world point lands on screen."""
import math;
import from engine.math.vec3 { Vec3, forward_from, right_from }
import from .ui.canvas { Rect }

glob CAMERA_PITCH_LIMIT: float = 1.55;

obj EditCamera {
    has eye: Vec3 = Vec3(),
        yaw: float = 0.0,
        pitch: float = 0.0,
        # The vertical view angle, in degrees (the renderer's).
        fov: float = 73.74;

    def forward -> Vec3 {
        return forward_from(self.yaw, self.pitch);
    }

    def right -> Vec3 {
        return right_from(self.yaw);
    }

    def up -> Vec3 {
        return self.right().cross(self.forward());
    }

    """Turn by angles in radians, without rolling over the poles."""
    def turn(yaw: float, pitch: float) {
        self.yaw += yaw;
        self.pitch = max(-CAMERA_PITCH_LIMIT, min(CAMERA_PITCH_LIMIT, self.pitch + pitch));
    }

    """Move along the camera's own axes."""
    def fly(ahead: float, side: float, rise: float) {
        self.eye = self.eye.add(self.forward().scale(ahead)).add(self.right().scale(side)).add(
            Vec3(z=rise)
        );
    }

    """Half the view's height at distance 1."""
    def slope -> float {
        return math.tan(math.radians(self.fov) * 0.5);
    }

    """The direction seen through a point of the view."""
    def ray(view: Rect, x: int, y: int) -> Vec3 {
        half = float(max(1, view.h)) * 0.5;
        across = (float(x - view.x) - float(view.w) * 0.5) / half * self.slope();
        upward = (float(view.y) + half - float(y)) / half * self.slope();
        return self.forward().add(self.right().scale(across)).add(self.up().scale(upward)).normalized();
    }

    """Where a world point shows in the view, or none when it is behind the
    camera."""
    def project(view: Rect, point: Vec3) -> list[int] | None {
        offset = point.sub(self.eye);
        depth = offset.dot(self.forward());
        if depth < 1.0 {
            return None;
        }
        half = float(max(1, view.h)) * 0.5;
        scale = half / self.slope() / depth;
        return [
            view.x + view.w // 2 + int(offset.dot(self.right()) * scale),
            view.y + view.h // 2 - int(offset.dot(self.up()) * scale)
        ];
    }

    """Back off along the line of sight until a ball of `radius` about
    `center` fits the view."""
    def frame(center: Vec3, radius: float) {
        reach = max(48.0, radius) / math.sin(math.radians(self.fov) * 0.5) * 1.2;
        self.eye = center.sub(self.forward().scale(reach));
    }
}

"""How far along a ray it enters a box, or -1 when it misses. A ray that
starts inside enters at 0."""
def ray_enters_box(start: Vec3, direction: Vec3, low: Vec3, high: Vec3) -> float {
    near = 0.0;
    far = 1000000.0;
    starts = [start.x, start.y, start.z];
    turns = [direction.x, direction.y, direction.z];
    lows = [low.x, low.y, low.z];
    highs = [high.x, high.y, high.z];
    for axis in range(3) {
        if abs(turns[axis]) < 0.0000001 {
            if starts[axis] < lows[axis] or starts[axis] > highs[axis] {
                return -1.0;
            }
            continue;
        }
        first = (lows[axis] - starts[axis]) / turns[axis];
        second = (highs[axis] - starts[axis]) / turns[axis];
        if first > second {
            swap = first;
            first = second;
            second = swap;
        }
        near = max(near, first);
        far = min(far, second);
        if near > far {
            return -1.0;
        }
    }
    return near;
}
