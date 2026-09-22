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
        for value in coordinates {
            value = max(0.0, min(3.0, value));
            index = min(2, int(math.floor(value)));
            low.append(index);
            fraction.append(value - float(index));
        }
        result = Illumination(enabled=True, ambient=Vec3(), direction=Vec3());
        total = 0.0;
        for z in range(2) {
            for y in range(2) {
                for x in range(2) {
                    index = (low[2] + z) * 16 + (low[1] + y) * 4 + low[0] + x;
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

obj Lighting {
    has rig: LightRig = LightRig(),
        regions: list[ProbeRegion] = [],
        dynamic: list[FlashLight] = [],
        cache_hit: bool = False;

    def sample(point: Vec3, include_dynamic: bool = True) -> Illumination {
        if not self.regions {
            return Illumination();
        }
        # Region-local interpolation avoids blending through room walls.
        x = min(4, max(0, int(math.floor(point.x / 640.0))));
        y = min(3, max(0, int(math.floor(point.y / 640.0))));
        result = self.regions[y * 5 + x].sample(point);
        for flash in (self.dynamic if include_dynamic else []) {
            delta = flash.origin.sub(point);
            factor = max(0.0, 1.0 - delta.length() / flash.radius);
            result.ambient = result.ambient.add(flash.color.scale(factor * factor));
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
        # Two deterministic emitter samples soften edges without frame-time rays.
        visibility = 0.0;
        for offset in [-6.0, 6.0] {
            hit = collision.trace_point(
                point, lamp.origin.add(Vec3(x=offset)), excluded
            );
            if not hit.start_solid and hit.fraction >= 1.0 {
                visibility += 0.5;
            }
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
