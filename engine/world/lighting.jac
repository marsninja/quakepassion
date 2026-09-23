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
            fraction.append(max(0.0, min(1.0, value - float(index))) if last > 0 else 0.0);
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
        cache_hit: bool = False;

    def region_at(point: Vec3) -> int {
        if not self.lookup {
            return 0;
        }
        x = min(self.lookup_columns - 1, max(0, int(math.floor(point.x / self.lookup_cell))));
        y = min(self.lookup_rows - 1, max(0, int(math.floor(point.y / self.lookup_cell))));
        return self.lookup[y * self.lookup_columns + x];
    }

    def sample(point: Vec3, include_dynamic: bool = True) -> Illumination {
        if not self.regions {
            return Illumination();
        }
        index = self.region_at(point);
        result = Illumination(enabled=True, ambient=Vec3(x=0.12, y=0.12, z=0.12));
        if 0 <= index < len(self.regions) {
            result = self.regions[index].sample(point);
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
    has collision: CollisionMap, excluded: list[int] = [];

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
        point, normal, lamps, TraceOccluder(collision=collision, excluded=excluded), probe
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
