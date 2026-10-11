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
        fov: float = 73.74,
        # Above zero the camera is orthographic: this many world units fit
        # the view's height, and everything along the line of sight shows.
        span: float = 0.0,
        # An orthographic view held to a band of depth: what lies wholly
        # outside `depth_low` to `depth_high`, measured along the axis the
        # view looks along, is out of it.
        bounded: bool = False,
        depth_low: float = 0.0,
        depth_high: float = 0.0;

    def forward -> Vec3 {
        return forward_from(self.yaw, self.pitch);
    }

    def right -> Vec3 {
        return right_from(self.yaw);
    }

    def up -> Vec3 {
        return self.right().cross(self.forward());
    }

    """The axis depth is measured along: the world's own when the view looks
    along one (z for a view from above, whichever way it faces), else the
    line of sight."""
    def depth_axis -> Vec3 {
        ahead = self.forward();
        for axis in [Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)] {
            if abs(ahead.dot(axis)) > 0.9999 {
                return axis;
            }
        }
        return ahead;
    }

    """Whether an orthographic camera looks along none of the world's axes."""
    def oblique -> bool {
        ahead = self.forward();
        return self.span > 0.0 and max(abs(ahead.x), max(abs(ahead.y), abs(ahead.z))) <= 0.9999;
    }

    """Whether a box lies wholly outside the band of depth the view is held to."""
    def out_of_depth(low: Vec3, high: Vec3) -> bool {
        if not self.bounded or self.span <= 0.0 {
            return False;
        }
        axis = self.depth_axis();
        least = min(low.x * axis.x, high.x * axis.x) + min(low.y * axis.y, high.y * axis.y)
            + min(low.z * axis.z, high.z * axis.z);
        most = max(low.x * axis.x, high.x * axis.x) + max(low.y * axis.y, high.y * axis.y)
            + max(low.z * axis.z, high.z * axis.z);
        return most < self.depth_low or least > self.depth_high;
    }

    """Turn by angles in radians, without rolling over the poles."""
    def turn(yaw: float, pitch: float) {
        self.yaw += yaw;
        self.pitch = max(-CAMERA_PITCH_LIMIT, min(CAMERA_PITCH_LIMIT, self.pitch + pitch));
    }

    """Swing round a point by angles in radians, at the distance the camera
    stands from it and facing it."""
    def orbit(pivot: Vec3, yaw: float, pitch: float) {
        reach = self.eye.sub(pivot).length();
        self.turn(yaw, pitch);
        self.eye = pivot.sub(self.forward().scale(reach));
    }

    """Stand at a point and face another."""
    def look_from(stand: Vec3, target: Vec3) {
        way = target.sub(stand);
        if way.length() < 0.001 {
            return;
        }
        way = way.normalized();
        self.eye = stand;
        self.yaw = math.atan2(way.y, way.x);
        self.pitch = max(
            -CAMERA_PITCH_LIMIT, min(CAMERA_PITCH_LIMIT, math.asin(max(-1.0, min(1.0, way.z))))
        );
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

    """The line of sight through a point of the view: where it starts and
    which way it runs. An orthographic camera's lines are parallel and start
    far back, so they enter the level from outside it."""
    def sight(view: Rect, x: int, y: int) -> list[Vec3] {
        if self.span <= 0.0 {
            return [self.eye, self.ray(view, x, y)];
        }
        unit = self.span / float(max(1, view.h));
        start = self.eye.add(self.right().scale((float(x - view.x) - float(view.w) * 0.5) * unit)).add(
            self.up().scale((float(view.y) + float(view.h) * 0.5 - float(y)) * unit)
        );
        return [start.sub(self.forward().scale(16384.0)), self.forward()];
    }

    """Slide an orthographic view by a number of screen units."""
    def pan(view: Rect, dx: int, dy: int) {
        unit = self.span / float(max(1, view.h)) if self.span > 0.0 else 1.0;
        self.eye = self.eye.sub(self.right().scale(float(dx) * unit)).add(self.up().scale(float(dy) * unit));
    }

    """Show more or less of the level in an orthographic view."""
    def zoom(factor: float) {
        self.span = max(16.0, min(65536.0, self.span * factor));
    }

    """Where a world point shows in the view, or none when it is behind the
    camera."""
    def project(view: Rect, point: Vec3) -> list[int] | None {
        if self.span > 0.0 {
            away = point.sub(self.eye);
            unit = self.span / float(max(1, view.h));
            return [
                view.x + view.w // 2 + int(round(away.dot(self.right()) / unit)),
                view.y + view.h // 2 - int(round(away.dot(self.up()) / unit))
            ];
        }
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
        if self.span > 0.0 {
            self.eye = center;
            self.span = max(96.0, radius * 2.6);
            return;
        }
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

"""An orthographic camera looking along an axis: "top" looks down with +y up
the screen, "front" looks along +y with +z up, "side" looks along -x with +z
up; +x or +y runs to the right."""
def axis_camera(kind: str, span: float = 1024.0) -> EditCamera {
    if kind == "top" {
        return EditCamera(yaw=math.pi * 0.5, pitch=-math.pi * 0.5, span=span);
    }
    if kind == "side" {
        return EditCamera(yaw=math.pi, pitch=0.0, span=span);
    }
    return EditCamera(yaw=math.pi * 0.5, pitch=0.0, span=span);
}
