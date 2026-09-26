"""Static light graph, shadow queries and interpolated model illumination."""
import math;
import from ..math.vec3 { Vec3 }
import from ..physics.collision { CollisionMap }

node LightRig {}
node Lamp {
    has origin: Vec3,
        color: Vec3,
        radius: float = 760.0,
        strength: float = 1.8;
}

edge Emits: LightRig --> Lamp {}

obj Illumination {
    has enabled: bool = False;
    has ambient: Vec3 = Vec3(x=1.0, y=1.0, z=1.0),
        directed: Vec3 = Vec3(),
        direction: Vec3 = Vec3(z=1.0);

    def shade(normal: Vec3) -> Vec3 {
        return self.ambient.add(
            self.directed.scale(max(0.0, normal.dot(self.direction)))
        );
    }
}

"""How baked light brightens a surface. Q3 stores lightmaps, vertex light
and its light grid at a quarter of full range (r_mapOverBrightBits 2) and
R_ColorShiftLightingBytes shifts them up, scaling an overflowing colour back
as a whole rather than saturating each channel to white. Q1 and Q2 light is
doubled and clamped."""
def shift_light(overbright: bool, red: int, green: int, blue: int) -> tuple[int, int, int] {
    if not overbright {
        return (min(255, red * 2), min(255, green * 2), min(255, blue * 2));
    }
    red = red * 4;
    green = green * 4;
    blue = blue * 4;
    brightest = max(red, max(green, blue));
    if brightest > 255 {
        red = red * 255 // brightest;
        green = green * 255 // brightest;
        blue = blue * 255 // brightest;
    }
    return (red, green, blue);
}

"""Q3's light grid (tr_bsp.c R_LoadLightGrid): a lattice of `size` cells
over the world model's bounds, each point holding an ambient and a directed
colour, shifted like the lightmaps, and the direction the light comes from.
Models are lit from it as tr_light.c R_SetupEntityLighting does."""
obj LightGrid {
    has origin: Vec3 = Vec3(),
        size: Vec3 = Vec3(x=64.0, y=64.0, z=128.0),
        bounds: list[int] = [0, 0, 0],
        ambient: list[Vec3] = [],
        directed: list[Vec3] = [],
        directions: list[Vec3] = [];

    """R_SetupEntityLightingGrid: blend the eight surrounding points, leaving
    out those inside walls (all black), scale ambient light by r_ambientScale
    0.6, add the minimum light of 32 and keep ambient light in range."""
    def sample(point: Vec3) -> Illumination {
        local = point.sub(self.origin);
        spots = [local.x / self.size.x, local.y / self.size.y, local.z / self.size.z];
        cell: list[int] = [];
        fraction: list[float] = [];
        for axis in range(3) {
            whole = int(math.floor(spots[axis]));
            fraction.append(spots[axis] - float(whole));
            cell.append(max(0, min(self.bounds[axis] - 1, whole)));
        }
        ambient = Vec3();
        directed = Vec3();
        direction = Vec3();
        total = 0.0;
        for corner in range(8) {
            factor = 1.0;
            index = [cell[0], cell[1], cell[2]];
            for axis in range(3) {
                if corner & (1 << axis) != 0 {
                    factor *= fraction[axis];
                    index[axis] += 1;
                } else {
                    factor *= 1.0 - fraction[axis];
                }
            }
            if index[0] >= self.bounds[0] or index[1] >= self.bounds[1] or index[2] >= self.bounds[2] {
                continue;
            }
            spot = (index[2] * self.bounds[1] + index[1]) * self.bounds[0] + index[0];
            light = self.ambient[spot];
            if light.x + light.y + light.z <= 0.0 {
                continue;
            }
            total += factor;
            ambient = ambient.add(light.scale(factor));
            directed = directed.add(self.directed[spot].scale(factor));
            direction = direction.add(self.directions[spot].scale(factor));
        }
        if total > 0.0 and total < 0.99 {
            ambient = ambient.scale(1.0 / total);
            directed = directed.scale(1.0 / total);
        }
        ambient = ambient.scale(0.6).add(Vec3(x=32.0, y=32.0, z=32.0));
        ambient = Vec3(x=min(255.0, ambient.x), y=min(255.0, ambient.y), z=min(255.0, ambient.z));
        return Illumination(
            enabled=True,
            ambient=ambient.scale(1.0 / 255.0),
            directed=directed.scale(1.0 / 255.0),
            direction=direction.normalized() if direction.length() > 0.00001 else Vec3(z=1.0)
        );
    }
}

"""Read a Q3 light grid lump for a world spanning `mins` to `maxs` with the
worldspawn `gridsize`. None when the lump does not match the lattice (as
the original warns and lights models without it)."""
def load_light_grid(data: bytes, mins: Vec3, maxs: Vec3, size: Vec3 = Vec3(x=64.0, y=64.0, z=128.0)) -> LightGrid | None {
    grid = LightGrid(size=size);
    low = [mins.x, mins.y, mins.z];
    high = [maxs.x, maxs.y, maxs.z];
    steps = [size.x, size.y, size.z];
    origin: list[float] = [];
    for axis in range(3) {
        start = steps[axis] * math.ceil(low[axis] / steps[axis]);
        end = steps[axis] * math.floor(high[axis] / steps[axis]);
        origin.append(start);
        grid.bounds[axis] = int((end - start) / steps[axis]) + 1;
    }
    grid.origin = Vec3(x=origin[0], y=origin[1], z=origin[2]);
    count = grid.bounds[0] * grid.bounds[1] * grid.bounds[2];
    if count <= 0 or len(data) != count * 8 {
        return None;
    }
    for spot in range(count) {
        p = spot * 8;
        shade = shift_light(True, data[p], data[p + 1], data[p + 2]);
        grid.ambient.append(Vec3(x=float(shade[0]), y=float(shade[1]), z=float(shade[2])));
        shade = shift_light(True, data[p + 3], data[p + 4], data[p + 5]);
        grid.directed.append(Vec3(x=float(shade[0]), y=float(shade[1]), z=float(shade[2])));
        # The direction as latitude and longitude bytes (256 steps a turn).
        lat = float(data[p + 7]) * math.pi * 2.0 / 256.0;
        lng = float(data[p + 6]) * math.pi * 2.0 / 256.0;
        grid.directions.append(
            Vec3(x=math.cos(lat) * math.sin(lng), y=math.sin(lat) * math.sin(lng), z=math.cos(lng))
        );
    }
    return grid;
}

obj FlashLight {
    has origin: Vec3,
        color: Vec3,
        radius: float = 220.0;
}

walker GatherLamps {
    has lamps: list[Lamp] = [];

    can start with LightRig entry {
        visit [-->];
    }

    can gather with Lamp entry {
        self.lamps.append(here);
    }
}

obj ProbeRegion {
    has origin: Vec3,
        spacing: Vec3 = Vec3(x=160.0, y=160.0, z=80.0),
        counts: list[int] = [4, 4, 4],
        samples: list[Illumination] = [],
        valid: list[bool] = [];

    def sample(point: Vec3) -> Illumination {
        delta = point.sub(self.origin);
        coordinates = [
            delta.x / self.spacing.x,
            delta.y / self.spacing.y,
            delta.z / self.spacing.z
        ];
        low: list[int] = [];
        fraction: list[float] = [];
        for axis in range(3) {
            last = self.counts[axis] - 1;
            value = max(0.0, min(float(last), coordinates[axis]));
            index = max(0, min(last - 1, int(math.floor(value))));
            low.append(index);
            fraction.append(
                max(0.0, min(1.0, value - float(index))) if last > 0 else 0.0
            );
        }
        result = Illumination(enabled=True, ambient=Vec3(), direction=Vec3());
        total = 0.0;
        for z in range(2) {
            for y in range(2) {
                for x in range(2) {
                    px = min(self.counts[0] - 1, low[0] + x);
                    py = min(self.counts[1] - 1, low[1] + y);
                    pz = min(self.counts[2] - 1, low[2] + z);
                    index = (pz * self.counts[1] + py) * self.counts[0] + px;
                    if not self.valid[index] {
                        continue;
                    }
                    weight = (fraction[0] if x else 1.0 - fraction[0])
                        * (fraction[1] if y else 1.0 - fraction[1])
                        * (fraction[2] if z else 1.0 - fraction[2]);
                    sample = self.samples[index];
                    total += weight;
                    result.ambient = result.ambient.add(sample.ambient.scale(weight));
                    result.directed = result.directed.add(
                        sample.directed.scale(weight)
                    );
                    result.direction = result.direction.add(
                        sample.direction.scale(weight * sample.directed.length())
                    );
                }
            }
        }
        if total < 0.00001 {
            return Illumination(enabled=True, ambient=Vec3(x=0.12, y=0.12, z=0.12));
        }
        result.ambient = result.ambient.scale(1.0 / total);
        result.directed = result.directed.scale(1.0 / total);
        result.direction = result.direction.normalized();
        return result;
    }
}

# Probe regions are chosen through a coarse floor-plan grid, so interpolation
# stays inside one room or corridor and never blends through a wall.
obj Lighting {
    has rig: LightRig = LightRig(),
        regions: list[ProbeRegion] = [],
        lookup: list[int] = [],
        lookup_columns: int = 0,
        lookup_rows: int = 0,
        lookup_cell: float = 160.0,
        dynamic: list[FlashLight] = [],
        cache_hit: bool = False,
        grid: LightGrid | None = None;

    def region_at(point: Vec3) -> int {
        if not self.lookup {
            return 0;
        }
        x = min(
            self.lookup_columns - 1, max(0, int(math.floor(point.x / self.lookup_cell)))
        );
        y = min(
            self.lookup_rows - 1, max(0, int(math.floor(point.y / self.lookup_cell)))
        );
        return self.lookup[y * self.lookup_columns + x];
    }

    def sample(point: Vec3, include_dynamic: bool = True) -> Illumination {
        grid = self.grid;
        if not self.regions and grid is None {
            return Illumination();
        }
        result = Illumination(enabled=True, ambient=Vec3(x=0.12, y=0.12, z=0.12));
        if grid is not None {
            result = grid.sample(point);
        } else {
            index = self.region_at(point);
            if 0 <= index < len(self.regions) {
                result = self.regions[index].sample(point);
            }
        }
        for flash in (self.dynamic if include_dynamic else []) {
            delta = flash.origin.sub(point);
            factor = max(0.0, 1.0 - delta.length() / flash.radius);
            result.ambient = result.ambient.add(flash.color.scale(factor * factor));
        }
        return result;
    }
}

# Shadow queries are pluggable: collision traces by default, or any faster
# exact test a level source can offer for its own geometry.
obj Occluder {
    def visibility(point: Vec3, target: Vec3) -> float {
        return 1.0;
    }
}

obj TraceOccluder(Occluder) {
    has collision: CollisionMap,
        excluded: list[int] = [];

    # A clear central ray means a fully visible emitter; otherwise two
    # deterministic offset samples soften the shadow edge.
    def visibility(point: Vec3, target: Vec3) -> float {
        center = self.collision.trace_point(point, target, self.excluded);
        if not center.start_solid and center.fraction >= 1.0 {
            return 1.0;
        }
        result = 0.0;
        for offset in [-6.0, 6.0] {
            hit = self.collision.trace_point(
                point, target.add(Vec3(x=offset)), self.excluded
            );
            if not hit.start_solid and hit.fraction >= 1.0 {
                result += 0.5;
            }
        }
        return result;
    }
}

def irradiance(
    point: Vec3,
    normal: Vec3,
    lamps: list[Lamp],
    collision: CollisionMap,
    excluded: list[int],
    probe: bool = False
) -> Illumination {
    return shade(
        point,
        normal,
        lamps,
        TraceOccluder(collision=collision, excluded=excluded),
        probe
    );
}

def shade(
    point: Vec3,
    normal: Vec3,
    lamps: list[Lamp],
    occluder: Occluder,
    probe: bool = False
) -> Illumination {
    result = Illumination(ambient=Vec3(x=0.12, y=0.12, z=0.12), direction=Vec3());
    for lamp in lamps {
        delta = lamp.origin.sub(point);
        distance = delta.length();
        if distance >= lamp.radius {
            continue;
        }
        direction = delta.normalized();
        cosine = 1.0 if probe else max(0.0, normal.dot(direction));
        if cosine <= 0.0 {
            continue;
        }
        visibility = occluder.visibility(point, lamp.origin);
        if visibility <= 0.0 {
            continue;
        }
        factor = 1.0 - distance / lamp.radius;
        contribution = lamp.color.scale(
            lamp.strength * factor * factor * visibility * cosine
        );
        result.directed = result.directed.add(contribution);
        result.direction = result.direction.add(direction.scale(contribution.length()));
    }
    result.direction = result.direction.normalized();
    if probe {
        # A modest nondirectional component keeps model backs readable.
        result.ambient = result.ambient.add(result.directed.scale(0.25));
        result.directed = result.directed.scale(0.75);
    }
    return result;
}
