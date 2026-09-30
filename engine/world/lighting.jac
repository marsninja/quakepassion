"""Static light graph, shadow queries and interpolated model illumination."""
import math;
import from ..math.vec3 { Vec3 }
import from ..physics.collision { CollisionMap }
import from ..formats.bsp { Face }
import from .lightstyles { LightStyles }

node LightRig {}
node Lamp {
    has origin: Vec3,
        color: Vec3,
        radius: float = 760.0,
        strength: float = 1.8;
}

edge Emits: LightRig --> Lamp {}

"""How a model is lit: an ambient colour plus a directed colour scaled by
how squarely a vertex faces `direction`. Faces turned away take `rear` of
the directed light, times the (negative) cosine: Q2's shadedots darken the
far side a little (r_avertexnormal_dots, 1 + 13/44 cos there) where Q1 and
Q3 leave it at the ambient light. A `model_space` direction turns with the
model (Q2's shadevector), else it is fixed in the world. Colours are in
the renderer's scale, 1 the texture's own colour."""
obj Illumination {
    has enabled: bool = False;
    has ambient: Vec3 = Vec3(x=1.0, y=1.0, z=1.0),
        directed: Vec3 = Vec3(),
        direction: Vec3 = Vec3(z=1.0),
        rear: float = 0.0,
        model_space: bool = False,
        glow: bool = False;

    """The light at `seconds`: RF_GLOW's pulse (`glow_pulse`) applied to a
    glowing model's light, which the model shader otherwise applies."""
    def at(seconds: float) -> Illumination {
        if not self.glow {
            return self;
        }
        light = glow_pulse(self.ambient, seconds);
        return Illumination(
            enabled=self.enabled, ambient=light, directed=light, direction=self.direction,
            rear=self.rear, model_space=self.model_space
        );
    }

    """The light on a vertex whose normal (in the direction's space) is
    `normal`."""
    def shade(normal: Vec3) -> Vec3 {
        facing = normal.dot(self.direction);
        return self.ambient.add(
            self.directed.scale(facing if facing >= 0.0 else facing * self.rear)
        );
    }
}

"""Q2 RF_GLOW (gl_mesh.c R_DrawAliasModel): bonus items pulse by 0.1 sin(7t)
of full light, never below 80% of their own; `light` is in the renderer's
doubled scale. The model shader applies the same pulse."""
def glow_pulse(light: Vec3, seconds: float) -> Vec3 {
    pulse = 0.2 * math.sin(seconds * 7.0);
    return Vec3(
        x=max(light.x * 0.8, light.x + pulse),
        y=max(light.y * 0.8, light.y + pulse),
        z=max(light.z * 0.8, light.z + pulse)
    );
}

"""Render flags that change how a model takes light: the view weapon (Q1
R_DrawViewModel lights it at least 24; Q2 marks it RF_MINLIGHT, Q3
RF_MINLIGHT), Q2 renderfx RF_MINLIGHT, RF_FULLBRIGHT and RF_GLOW (bonus
items pulse), and Q1 brush pickups whose skins carry their own lightmaps."""
glob MODEL_LIGHT_VIEW: int = 1,
     MODEL_LIGHT_MINLIGHT: int = 2,
     MODEL_LIGHT_FULLBRIGHT: int = 4,
     MODEL_LIGHT_GLOW: int = 8;

# r_alias.c LIGHT_MIN: no Q1 model vertex is lit below it.
glob QUAKE_LIGHT_MIN: float = 5.0;

# Q2 r_avertexnormal_dots: a normal facing away from the shade vector keeps
# 1 + 13/44 cos of the light (the table's far side, as MH's GLSL reproduces it).
glob QUAKE2_SHADE_REAR: float = 13.0 / 44.0;

"""Where a trace straight down from a point first meets a lit world surface
(RecursiveLightPoint): the face, and the offset of the lightmap sample under
the point in each of its style layers. No face (-1): the trace left the
world without striking one."""
obj LightSpot {
    has face: int = -1,
        sample: int = 0;
}

"""The light a Q1 or Q2 world's lightmaps give points (r_light.c and
gl_light.c R_LightPoint): the lightmap sample on the first lit surface
straight below, each style layer scaled by its style's current value. A
level supplies the trace through its BSP tree (`trace`, abstract so it
dispatches to the level module's implementation); traces are cached by
point, since most models rest where they stand."""
obj LightPointSource {
    has faces: list[Face] = [],
        lightmaps: bytes = b"",
        channels: int = 1;

    """The first lit surface straight below `point`."""
    def trace(point: Vec3) -> LightSpot abst;

    """The raw light at `point` (lightmap bytes times style values, per
    channel; a mono Q1 lightmap fills all three), or None when the trace
    strikes nothing. A surface without samples is black."""
    def light(point: Vec3, styles: dict[int, float]) -> Vec3 | None {
        return self.light_at(self.trace(point), styles);
    }

    """The raw light of a traced `found` spot under the style values."""
    def light_at(found: LightSpot, styles: dict[int, float]) -> Vec3 | None {
        if found.face < 0 {
            return None;
        }
        face = self.faces[found.face];
        if face.light_offset < 0 {
            return Vec3();
        }
        layer = face.light_width * face.light_height * self.channels;
        offset = face.light_offset + found.sample * self.channels;
        total = [0.0, 0.0, 0.0];
        for style in face.styles {
            value = styles.get(style, 1.0);
            for channel in range(3) {
                total[channel] += float(self.lightmaps[offset + (channel if self.channels == 3 else 0)]) * value;
            }
            offset += layer;
        }
        return Vec3(x=total[0], y=total[1], z=total[2]);
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

"""A dynamic light this frame (cl_dlights, Q2 V_AddLight, Q3
trap_R_AddLightToScene): where it is, its colour (Q1 lights are white), its
radius (Q2 calls it intensity) and, for Q1, the minimum light it adds to a
surface before it cuts off (dl->minlight)."""
obj FlashLight {
    has origin: Vec3,
        color: Vec3,
        radius: float = 220.0,
        minlight: float = 0.0;
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
#
"""One drawable's model light, reused while nothing it depends on changes:
where it stands, its shade row and flags, the light style values (their
table and serial) and the dynamic lights (their version). It lives with the
thing drawn, so a model standing still is lit once per change of light
instead of being looked up by position every frame."""
obj ModelLight {
    has origin: Vec3 = Vec3(),
        # The lightmap sample traced below `spot_origin` (R_LightPoint): a
        # change of light styles or dynamic lights recombines it untraced.
        spot_origin: Vec3 = Vec3(),
        spot: LightSpot | None = None,
        row: int = -1,
        flags: int = -1,
        serial: int = -1,
        dynamic: int = -1,
        styles: dict[int, float] | None = None,
        result: Illumination = Illumination();
}

# Q1/Q2 levels light models from their lightmaps instead (`point`, with the
# light style values `styles` shared with the world renderer), Q3 levels from
# their light grid.
obj Lighting {
    has rig: LightRig = LightRig(),
        regions: list[ProbeRegion] = [],
        lookup: list[int] = [],
        lookup_columns: int = 0,
        lookup_rows: int = 0,
        lookup_cell: float = 160.0,
        dynamic: list[FlashLight] = [],
        cache_hit: bool = False,
        grid: LightGrid | None = None,
        game: str = "",
        point: LightPointSource | None = None,
        styles: dict[int, float] = {},
        style_source: LightStyles | None = None,
        # Counts replacements of `dynamic`, so held model light knows it.
        dynamic_version: int = 0;

    """Replace the dynamic lights."""
    def set_dynamic(lights: list[FlashLight]) {
        self.dynamic = lights;
        self.dynamic_version += 1;
    }

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

    """The light grid or probe light at `point`, with the dynamic lights.
    Q3 adds each to the directed light (tr_light.c R_SetupEntityLighting:
    DLIGHT_AT_RADIUS 16 times the radius squared over the distance squared,
    no nearer than DLIGHT_MINIMUM_RADIUS 16, turning the light's direction
    toward it); probes add a soft ambient glow."""
    def sample(point: Vec3, include_dynamic: bool = True) -> Illumination {
        grid = self.grid;
        if not self.regions and grid is None {
            return Illumination();
        }
        result = Illumination(enabled=True, ambient=Vec3(x=0.12, y=0.12, z=0.12));
        if grid is not None {
            result = grid.sample(point);
            if include_dynamic and self.dynamic {
                steer = result.direction.scale(result.directed.length());
                for flash in self.dynamic {
                    toward = flash.origin.sub(point);
                    distance = toward.length();
                    power = 16.0 * flash.radius * flash.radius / (max(16.0, distance) ** 2) / 255.0;
                    result.directed = result.directed.add(flash.color.scale(power));
                    if distance > 0.00001 {
                        steer = steer.add(toward.scale(power / distance));
                    }
                }
                if steer.length() > 0.00001 {
                    result.direction = steer.normalized();
                }
            }
            return result;
        }
        index = self.region_at(point);
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

    """How a model at `origin` is lit, turned `yaw` degrees, with MODEL_LIGHT
    `flags`: Q1 and Q2 from the lightmaps below it, Q3 from its light grid,
    Passion from its probes (16 units up). With `held`, the drawable's own
    ModelLight, the light is reused until something it depends on changes."""
    def light_model(
        origin: Vec3, yaw: float = 0.0, flags: int = 0, held: ModelLight | None = None
    ) -> Illumination {
        # Q2 R_LightPoint's shadedots row, (int)(angles[1] * SHADEDOT_QUANT /
        # 360) & (SHADEDOT_QUANT - 1); only Q2 shades by it.
        row = int(yaw * 16.0 / 360.0) & 15 if self.point is not None and self.game != "q1" else 0;
        clock = self.style_source;
        serial = clock.serial if clock is not None else -1;
        if held is not None
            and held.serial == serial
            and held.dynamic == self.dynamic_version
            and held.styles is self.styles
            and held.row == row
            and held.flags == flags
            and held.origin.x == origin.x
            and held.origin.y == origin.y
            and held.origin.z == origin.z {
            return held.result;
        }
        result = self.build_model_light(origin, row, flags, held);
        if held is not None {
            held.origin = Vec3(x=origin.x, y=origin.y, z=origin.z);
            held.row = row;
            held.flags = flags;
            held.serial = serial;
            held.dynamic = self.dynamic_version;
            held.styles = self.styles;
            held.result = result;
        }
        return result;
    }

    def build_model_light(origin: Vec3, row: int, flags: int, held: ModelLight | None) -> Illumination {
        source = self.point;
        if source is not None {
            return self.quake_model_light(source, origin, flags, held)
                if self.game == "q1"
                else self.quake2_model_light(source, origin, row, flags, held);
        }
        result = self.sample(origin if self.grid is not None else origin.add(Vec3(z=16.0)));
        if flags & MODEL_LIGHT_VIEW != 0 and result.enabled {
            result.ambient = Vec3(
                x=max(0.1, result.ambient.x), y=max(0.1, result.ambient.y), z=max(0.1, result.ambient.z)
            );
        }
        return result;
    }

    """R_LightPoint below `origin` under the current styles, tracing only
    when the drawable has moved since its held spot was traced."""
    def point_light(source: LightPointSource, origin: Vec3, held: ModelLight | None) -> Vec3 | None {
        if held is None {
            return source.light(origin, self.styles);
        }
        spot = held.spot;
        if spot is None
            or held.spot_origin.x != origin.x
            or held.spot_origin.y != origin.y
            or held.spot_origin.z != origin.z {
            spot = source.trace(origin);
            held.spot = spot;
            held.spot_origin = Vec3(x=origin.x, y=origin.y, z=origin.z);
        }
        return source.light_at(spot, self.styles);
    }

    """Q1 (WinQuake r_main.c R_DrawEntitiesOnList, R_DrawViewModel and
    r_alias.c R_AliasSetupLighting): ambient and shade light both start at
    R_LightPoint (the gun at least 24); each dynamic light adds its radius
    less its distance to the ambient light; ambient is held to 128 and the
    two together to 192, and nothing falls below LIGHT_MIN. The shade light
    comes from lightvec (-1, 0, 0): faces turned toward +x brighten. A light
    level L shows as the colormap row a wall lit L shows, so both use the
    renderer's scale (2L/255)."""
    def quake_model_light(
        source: LightPointSource, origin: Vec3, flags: int, held: ModelLight | None = None
    ) -> Illumination {
        level = 255.0;
        if source.lightmaps {
            light = self.point_light(source, origin, held);
            level = 0.0 if light is None else math.floor(light.x);
        }
        if flags & MODEL_LIGHT_VIEW != 0 and level < 24.0 {
            level = 24.0;
        }
        ambient = level;
        shade = level;
        for flash in self.dynamic {
            add = flash.radius - flash.origin.sub(origin).length();
            if add > 0.0 {
                ambient += float(int(add));
            }
        }
        ambient = min(128.0, ambient);
        if ambient + shade > 192.0 {
            shade = 192.0 - ambient;
        }
        ambient = max(QUAKE_LIGHT_MIN, ambient);
        shade = max(0.0, shade);
        scale = 2.0 / 255.0;
        return Illumination(
            enabled=True,
            ambient=Vec3(x=ambient * scale, y=ambient * scale, z=ambient * scale),
            directed=Vec3(x=shade * scale, y=shade * scale, z=shade * scale),
            direction=Vec3(x=1.0)
        );
    }

    """Q2 (ref_gl gl_mesh.c R_DrawAliasModel, gl_light.c R_LightPoint): the
    coloured lightmap light below (gl_modulate 1), plus each dynamic light's
    intensity less its distance, over 256, in its colour; RF_FULLBRIGHT is
    full light, RF_MINLIGHT keeps at least 0.1, RF_GLOW pulses (`glow`, see
    glow_pulse). Vertices take that light times shadedots: table `row` for
    the yaw in sixteenths of a turn, as the normal faces its shade vector.
    Light is doubled to the renderer's scale as the lightmaps are."""
    def quake2_model_light(
        source: LightPointSource, origin: Vec3, row: int, flags: int, held: ModelLight | None = None
    ) -> Illumination {
        color = Vec3(x=1.0, y=1.0, z=1.0);
        if flags & MODEL_LIGHT_FULLBRIGHT == 0 and source.lightmaps {
            light = self.point_light(source, origin, held);
            color = Vec3() if light is None else light.scale(1.0 / 255.0);
            for flash in self.dynamic {
                add = (flash.radius - origin.sub(flash.origin).length()) / 256.0;
                if add > 0.0 {
                    color = color.add(flash.color.scale(add));
                }
            }
        }
        if flags & (MODEL_LIGHT_MINLIGHT | MODEL_LIGHT_VIEW) != 0
            and color.x <= 0.1 and color.y <= 0.1 and color.z <= 0.1 {
            color = Vec3(x=0.1, y=0.1, z=0.1);
        }
        turn = float(row) / 16.0 * 2.0 * math.pi;
        light = color.scale(2.0);
        return Illumination(
            enabled=True,
            ambient=light,
            directed=light,
            direction=Vec3(x=math.cos(-turn), y=math.sin(-turn), z=1.0).normalized(),
            rear=QUAKE2_SHADE_REAR,
            model_space=True,
            glow=flags & MODEL_LIGHT_GLOW != 0
        );
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
