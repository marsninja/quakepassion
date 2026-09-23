"""Q3 portals and mirrors. A misc_portal_surface marks the portal surface
nearest it. Without a target it is a mirror; with one it looks out of a
misc_portal_camera, oriented as cgame's CG_Portal and g_misc.c locateCamera
set it up (aimed at the camera's target or along its angle, rolled, and
swaying or spinning). The view through a surface is tr_main.c's
R_GetPortalOrientations and R_MirrorViewBySurface."""
import math;
import from .world { World, Entity }
import from ..formats.bsp { Bsp, Face }
import from ..math.vec3 { Vec3, forward_from }

# q_math.c bytedirs: the 162 directions an entity direction byte can hold.
glob BYTE_DIRECTIONS: list[Vec3] = [
    Vec3(x=-0.525731, y=0.0, z=0.850651),
    Vec3(x=-0.442863, y=0.238856, z=0.864188),
    Vec3(x=-0.295242, y=0.0, z=0.955423),
    Vec3(x=-0.309017, y=0.5, z=0.809017),
    Vec3(x=-0.16246, y=0.262866, z=0.951056),
    Vec3(x=0.0, y=0.0, z=1.0),
    Vec3(x=0.0, y=0.850651, z=0.525731),
    Vec3(x=-0.147621, y=0.716567, z=0.681718),
    Vec3(x=0.147621, y=0.716567, z=0.681718),
    Vec3(x=0.0, y=0.525731, z=0.850651),
    Vec3(x=0.309017, y=0.5, z=0.809017),
    Vec3(x=0.525731, y=0.0, z=0.850651),
    Vec3(x=0.295242, y=0.0, z=0.955423),
    Vec3(x=0.442863, y=0.238856, z=0.864188),
    Vec3(x=0.16246, y=0.262866, z=0.951056),
    Vec3(x=-0.681718, y=0.147621, z=0.716567),
    Vec3(x=-0.809017, y=0.309017, z=0.5),
    Vec3(x=-0.587785, y=0.425325, z=0.688191),
    Vec3(x=-0.850651, y=0.525731, z=0.0),
    Vec3(x=-0.864188, y=0.442863, z=0.238856),
    Vec3(x=-0.716567, y=0.681718, z=0.147621),
    Vec3(x=-0.688191, y=0.587785, z=0.425325),
    Vec3(x=-0.5, y=0.809017, z=0.309017),
    Vec3(x=-0.238856, y=0.864188, z=0.442863),
    Vec3(x=-0.425325, y=0.688191, z=0.587785),
    Vec3(x=-0.716567, y=0.681718, z=-0.147621),
    Vec3(x=-0.5, y=0.809017, z=-0.309017),
    Vec3(x=-0.525731, y=0.850651, z=0.0),
    Vec3(x=0.0, y=0.850651, z=-0.525731),
    Vec3(x=-0.238856, y=0.864188, z=-0.442863),
    Vec3(x=0.0, y=0.955423, z=-0.295242),
    Vec3(x=-0.262866, y=0.951056, z=-0.16246),
    Vec3(x=0.0, y=1.0, z=0.0),
    Vec3(x=0.0, y=0.955423, z=0.295242),
    Vec3(x=-0.262866, y=0.951056, z=0.16246),
    Vec3(x=0.238856, y=0.864188, z=0.442863),
    Vec3(x=0.262866, y=0.951056, z=0.16246),
    Vec3(x=0.5, y=0.809017, z=0.309017),
    Vec3(x=0.238856, y=0.864188, z=-0.442863),
    Vec3(x=0.262866, y=0.951056, z=-0.16246),
    Vec3(x=0.5, y=0.809017, z=-0.309017),
    Vec3(x=0.850651, y=0.525731, z=0.0),
    Vec3(x=0.716567, y=0.681718, z=0.147621),
    Vec3(x=0.716567, y=0.681718, z=-0.147621),
    Vec3(x=0.525731, y=0.850651, z=0.0),
    Vec3(x=0.425325, y=0.688191, z=0.587785),
    Vec3(x=0.864188, y=0.442863, z=0.238856),
    Vec3(x=0.688191, y=0.587785, z=0.425325),
    Vec3(x=0.809017, y=0.309017, z=0.5),
    Vec3(x=0.681718, y=0.147621, z=0.716567),
    Vec3(x=0.587785, y=0.425325, z=0.688191),
    Vec3(x=0.955423, y=0.295242, z=0.0),
    Vec3(x=1.0, y=0.0, z=0.0),
    Vec3(x=0.951056, y=0.16246, z=0.262866),
    Vec3(x=0.850651, y=-0.525731, z=0.0),
    Vec3(x=0.955423, y=-0.295242, z=0.0),
    Vec3(x=0.864188, y=-0.442863, z=0.238856),
    Vec3(x=0.951056, y=-0.16246, z=0.262866),
    Vec3(x=0.809017, y=-0.309017, z=0.5),
    Vec3(x=0.681718, y=-0.147621, z=0.716567),
    Vec3(x=0.850651, y=0.0, z=0.525731),
    Vec3(x=0.864188, y=0.442863, z=-0.238856),
    Vec3(x=0.809017, y=0.309017, z=-0.5),
    Vec3(x=0.951056, y=0.16246, z=-0.262866),
    Vec3(x=0.525731, y=0.0, z=-0.850651),
    Vec3(x=0.681718, y=0.147621, z=-0.716567),
    Vec3(x=0.681718, y=-0.147621, z=-0.716567),
    Vec3(x=0.850651, y=0.0, z=-0.525731),
    Vec3(x=0.809017, y=-0.309017, z=-0.5),
    Vec3(x=0.864188, y=-0.442863, z=-0.238856),
    Vec3(x=0.951056, y=-0.16246, z=-0.262866),
    Vec3(x=0.147621, y=0.716567, z=-0.681718),
    Vec3(x=0.309017, y=0.5, z=-0.809017),
    Vec3(x=0.425325, y=0.688191, z=-0.587785),
    Vec3(x=0.442863, y=0.238856, z=-0.864188),
    Vec3(x=0.587785, y=0.425325, z=-0.688191),
    Vec3(x=0.688191, y=0.587785, z=-0.425325),
    Vec3(x=-0.147621, y=0.716567, z=-0.681718),
    Vec3(x=-0.309017, y=0.5, z=-0.809017),
    Vec3(x=0.0, y=0.525731, z=-0.850651),
    Vec3(x=-0.525731, y=0.0, z=-0.850651),
    Vec3(x=-0.442863, y=0.238856, z=-0.864188),
    Vec3(x=-0.295242, y=0.0, z=-0.955423),
    Vec3(x=-0.16246, y=0.262866, z=-0.951056),
    Vec3(x=0.0, y=0.0, z=-1.0),
    Vec3(x=0.295242, y=0.0, z=-0.955423),
    Vec3(x=0.16246, y=0.262866, z=-0.951056),
    Vec3(x=-0.442863, y=-0.238856, z=-0.864188),
    Vec3(x=-0.309017, y=-0.5, z=-0.809017),
    Vec3(x=-0.16246, y=-0.262866, z=-0.951056),
    Vec3(x=0.0, y=-0.850651, z=-0.525731),
    Vec3(x=-0.147621, y=-0.716567, z=-0.681718),
    Vec3(x=0.147621, y=-0.716567, z=-0.681718),
    Vec3(x=0.0, y=-0.525731, z=-0.850651),
    Vec3(x=0.309017, y=-0.5, z=-0.809017),
    Vec3(x=0.442863, y=-0.238856, z=-0.864188),
    Vec3(x=0.16246, y=-0.262866, z=-0.951056),
    Vec3(x=0.238856, y=-0.864188, z=-0.442863),
    Vec3(x=0.5, y=-0.809017, z=-0.309017),
    Vec3(x=0.425325, y=-0.688191, z=-0.587785),
    Vec3(x=0.716567, y=-0.681718, z=-0.147621),
    Vec3(x=0.688191, y=-0.587785, z=-0.425325),
    Vec3(x=0.587785, y=-0.425325, z=-0.688191),
    Vec3(x=0.0, y=-0.955423, z=-0.295242),
    Vec3(x=0.0, y=-1.0, z=0.0),
    Vec3(x=0.262866, y=-0.951056, z=-0.16246),
    Vec3(x=0.0, y=-0.850651, z=0.525731),
    Vec3(x=0.0, y=-0.955423, z=0.295242),
    Vec3(x=0.238856, y=-0.864188, z=0.442863),
    Vec3(x=0.262866, y=-0.951056, z=0.16246),
    Vec3(x=0.5, y=-0.809017, z=0.309017),
    Vec3(x=0.716567, y=-0.681718, z=0.147621),
    Vec3(x=0.525731, y=-0.850651, z=0.0),
    Vec3(x=-0.238856, y=-0.864188, z=-0.442863),
    Vec3(x=-0.5, y=-0.809017, z=-0.309017),
    Vec3(x=-0.262866, y=-0.951056, z=-0.16246),
    Vec3(x=-0.850651, y=-0.525731, z=0.0),
    Vec3(x=-0.716567, y=-0.681718, z=-0.147621),
    Vec3(x=-0.716567, y=-0.681718, z=0.147621),
    Vec3(x=-0.525731, y=-0.850651, z=0.0),
    Vec3(x=-0.5, y=-0.809017, z=0.309017),
    Vec3(x=-0.238856, y=-0.864188, z=0.442863),
    Vec3(x=-0.262866, y=-0.951056, z=0.16246),
    Vec3(x=-0.864188, y=-0.442863, z=0.238856),
    Vec3(x=-0.809017, y=-0.309017, z=0.5),
    Vec3(x=-0.688191, y=-0.587785, z=0.425325),
    Vec3(x=-0.681718, y=-0.147621, z=0.716567),
    Vec3(x=-0.442863, y=-0.238856, z=0.864188),
    Vec3(x=-0.587785, y=-0.425325, z=0.688191),
    Vec3(x=-0.309017, y=-0.5, z=0.809017),
    Vec3(x=-0.147621, y=-0.716567, z=0.681718),
    Vec3(x=-0.425325, y=-0.688191, z=0.587785),
    Vec3(x=-0.16246, y=-0.262866, z=0.951056),
    Vec3(x=0.442863, y=-0.238856, z=0.864188),
    Vec3(x=0.16246, y=-0.262866, z=0.951056),
    Vec3(x=0.309017, y=-0.5, z=0.809017),
    Vec3(x=0.147621, y=-0.716567, z=0.681718),
    Vec3(x=0.0, y=-0.525731, z=0.850651),
    Vec3(x=0.425325, y=-0.688191, z=0.587785),
    Vec3(x=0.587785, y=-0.425325, z=0.688191),
    Vec3(x=0.688191, y=-0.587785, z=0.425325),
    Vec3(x=-0.955423, y=0.295242, z=0.0),
    Vec3(x=-0.951056, y=0.16246, z=0.262866),
    Vec3(x=-1.0, y=0.0, z=0.0),
    Vec3(x=-0.850651, y=0.0, z=0.525731),
    Vec3(x=-0.955423, y=-0.295242, z=0.0),
    Vec3(x=-0.951056, y=-0.16246, z=0.262866),
    Vec3(x=-0.864188, y=0.442863, z=-0.238856),
    Vec3(x=-0.951056, y=0.16246, z=-0.262866),
    Vec3(x=-0.809017, y=0.309017, z=-0.5),
    Vec3(x=-0.864188, y=-0.442863, z=-0.238856),
    Vec3(x=-0.951056, y=-0.16246, z=-0.262866),
    Vec3(x=-0.809017, y=-0.309017, z=-0.5),
    Vec3(x=-0.681718, y=0.147621, z=-0.716567),
    Vec3(x=-0.681718, y=-0.147621, z=-0.716567),
    Vec3(x=-0.850651, y=0.0, z=-0.525731),
    Vec3(x=-0.688191, y=0.587785, z=-0.425325),
    Vec3(x=-0.587785, y=0.425325, z=-0.688191),
    Vec3(x=-0.425325, y=0.688191, z=-0.587785),
    Vec3(x=-0.425325, y=-0.688191, z=-0.587785),
    Vec3(x=-0.587785, y=-0.425325, z=-0.688191),
    Vec3(x=-0.688191, y=-0.587785, z=-0.425325)
];

"""DirToByte then ByteToDir: the network-quantized direction the renderer
actually receives."""
def byte_direction(direction: Vec3) -> Vec3 {
    best = 0;
    best_dot = 0.0;
    for i in range(len(BYTE_DIRECTIONS)) {
        d = direction.dot(BYTE_DIRECTIONS[i]);
        if d > best_dot {
            best_dot = d;
            best = i;
        }
    }
    chosen = BYTE_DIRECTIONS[best];
    return Vec3(x=chosen.x, y=chosen.y, z=chosen.z);
}

node PortalSurface(Entity) {
    has camera: Vec3 = Vec3(),
        mirror: bool = True,
        aim: Vec3 = Vec3(x=1.0),
        side: Vec3 = Vec3(y=1.0),
        above: Vec3 = Vec3(z=1.0),
        spin: float = 0.0,
        sway: bool = False,
        roll: float = 0.0;
}

edge HasPortal: World --> PortalSurface {}

"""A view through a portal: the new eye and axes, whether it mirrors (so the
image must be flipped), the plane that clips what lies behind the portal
camera, and where visibility is flooded from."""
obj PortalView {
    has origin: Vec3,
        forward: Vec3,
        left: Vec3,
        up: Vec3,
        mirror: bool,
        clip_normal: Vec3,
        clip_dist: float,
        pvs: Vec3;
}

"""q_math.c PerpendicularVector: the smallest axis projected off `src`."""
def perpendicular(src: Vec3) -> Vec3 {
    axis = Vec3(x=1.0);
    smallest = abs(src.x);
    if abs(src.y) < smallest {
        axis = Vec3(y=1.0);
        smallest = abs(src.y);
    }
    if abs(src.z) < smallest {
        axis = Vec3(z=1.0);
    }
    along = src.dot(axis) / src.dot(src);
    return axis.sub(src.scale(along)).normalized();
}

"""q_math.c RotatePointAroundVector, `degrees` about the unit `axis`."""
def rotate_about(point: Vec3, axis: Vec3, degrees: float) -> Vec3 {
    angle = math.radians(degrees);
    c = math.cos(angle);
    s = math.sin(angle);
    return point.scale(c).add(axis.cross(point).scale(s)).add(axis.scale(axis.dot(point) * (1.0 - c)));
}

def portal_origin(fields: dict[str, str]) -> Vec3 {
    parts = fields.get("origin", "0 0 0").split();
    if len(parts) != 3 {
        return Vec3();
    }
    return Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
}

"""G_SetMovedir: angle -1 is up, -2 down, otherwise the angles' forward."""
def camera_direction(fields: dict[str, str]) -> Vec3 {
    pitch = 0.0;
    yaw = float(fields.get("angle", "0"));
    parts = fields.get("angles", "").split();
    if len(parts) == 3 {
        pitch = float(parts[0]);
        yaw = float(parts[1]);
    }
    if yaw == -1.0 {
        return Vec3(z=1.0);
    }
    if yaw == -2.0 {
        return Vec3(z=-1.0);
    }
    return forward_from(math.radians(yaw), -math.radians(pitch));
}

def load_portals(world: World, bsp: Bsp) {
    if bsp.game != "q3" {
        return;
    }
    named: dict[str, dict[str, str]] = {};
    for entity in bsp.entities {
        name = entity.fields.get("targetname", "");
        if name and name not in named {
            named[name] = entity.fields;
        }
    }
    for entity in bsp.entities {
        fields = entity.fields;
        if fields.get("classname", "") != "misc_portal_surface" {
            continue;
        }
        origin = portal_origin(fields);
        portal = PortalSurface(pos=origin, camera=origin);
        target = fields.get("target", "");
        if target in named {
            owner = named[target];
            portal.mirror = False;
            portal.camera = portal_origin(owner);
            flags = int(owner.get("spawnflags", "0"));
            # locateCamera: frame holds the spin speed, powerups the sway,
            # clientNum the roll in 256ths of a turn.
            portal.spin = 25.0 if flags & 1 else (75.0 if flags & 2 else 0.0);
            portal.sway = flags & 4 == 0;
            portal.roll = float(int(float(owner.get("roll", "0")) / 360.0 * 256.0)) / 256.0 * 360.0;
            aim = camera_direction(owner);
            ahead = owner.get("target", "");
            if ahead in named {
                toward = portal_origin(named[ahead]).sub(portal.camera);
                if toward.length() > 0.0 {
                    aim = toward.normalized();
                }
            }
            # The direction crosses the network as a byte (DirToByte); CG_Portal
            # then negates the perpendicular for axis 1.
            aim = byte_direction(aim);
            portal.aim = aim;
            portal.side = perpendicular(aim).scale(-1.0);
            portal.above = aim.cross(portal.side);
        }
        world +>:HasPortal:+> portal;
    }
}

"""R_GetPortalOrientations and R_MirrorViewBySurface for the view (eye,
forward, left, up) looking at `face`; None when no portal entity lies within
64 units of its plane."""
def portal_view(world: World, face: Face, eye: Vec3, forward: Vec3, left: Vec3, up: Vec3, seconds: float) -> PortalView | None {
    normal = face.normal;
    dist = face.plane_dist;
    chosen: PortalSurface | None = None;
    for portal in [world->:HasPortal:->][?:PortalSurface] {
        offset = portal.pos.dot(normal) - dist;
        if offset <= 64.0 and offset >= -64.0 {
            chosen = portal;
            break;
        }
    }
    if chosen is None {
        return None;
    }
    surface = [normal, perpendicular(normal)];
    surface.append(surface[0].cross(surface[1]));
    camera: list[Vec3] = [];
    surface_origin = normal.scale(dist);
    camera_origin = surface_origin;
    if chosen.mirror {
        camera = [surface[0].scale(-1.0), surface[1], surface[2]];
    } else {
        offset = chosen.pos.dot(normal) - dist;
        surface_origin = chosen.pos.sub(surface[0].scale(offset));
        camera_origin = chosen.camera;
        camera = [chosen.aim.scale(-1.0), chosen.side.scale(-1.0), chosen.above];
        turn = chosen.roll;
        if chosen.sway {
            turn = chosen.spin * seconds if chosen.spin != 0.0 else chosen.roll + math.sin(seconds * 3.0) * 4.0;
        }
        if turn != 0.0 {
            camera[1] = rotate_about(camera[1], camera[0], turn);
            camera[2] = camera[0].cross(camera[1]);
        }
    }
    local = eye.sub(surface_origin);
    moved = Vec3();
    for i in range(3) {
        moved = moved.add(camera[i].scale(local.dot(surface[i])));
    }
    turned: list[Vec3] = [];
    for axis in [forward, left, up] {
        out = Vec3();
        for i in range(3) {
            out = out.add(camera[i].scale(axis.dot(surface[i])));
        }
        turned.append(out);
    }
    clip = camera[0].scale(-1.0);
    return PortalView(
        origin=moved.add(camera_origin),
        forward=turned[0],
        left=turned[1],
        up=turned[2],
        mirror=chosen.mirror,
        clip_normal=clip,
        clip_dist=camera_origin.dot(clip),
        pvs=chosen.camera
    );
}
