"""Deterministic generated lightmaps and probes, cached by complete bake inputs."""
import os;
import math;
import struct;
import hashlib;
import from engine.world.lighting {
    Lighting,
    Lamp,
    Emits,
    GatherLamps,
    ProbeRegion,
    Illumination,
    irradiance
}
import from engine.world.level { Level }
import from engine.math.vec3 { Vec3 }
import from engine.formats.bsp { Face, Texture }
import from .geometry { Builder }
import from .plan { Chamber }

def fixtures(builder: Builder, room: Chamber, ceiling: float) {
    # Emission is a separate material, so dark surroundings never dim the lamp.
    x = float(room.x) * 640.0;
    y = float(room.y) * 640.0;
    z = float(room.y) * 32.0;
    for cy in [160.0, 480.0] {
        builder.panel(
            [
                Vec3(x=x + 292.0, y=y + cy - 12.0, z=z + ceiling - 0.5),
                Vec3(x=x + 292.0, y=y + cy + 12.0, z=z + ceiling - 0.5),
                Vec3(x=x + 348.0, y=y + cy + 12.0, z=z + ceiling - 0.5),
                Vec3(x=x + 348.0, y=y + cy - 12.0, z=z + ceiling - 0.5)
            ],
            7 + room.theme
        );
        builder.bsp.faces[-1].emission = True;
    }
}

def fixture_materials() -> list[Texture] {
    return [
        Texture(name="passion:lamp-amber", width=1, height=1, rgba=b"\xff\xc4\x80\xff"),
        Texture(name="passion:lamp-cool", width=1, height=1, rgba=b"\xad\xdc\xff\xff"),
        Texture(name="passion:lamp-rose", width=1, height=1, rgba=b"\xff\xad\xc7\xff")
    ];
}

def axes(face: Face) -> list[Vec3] {
    u = face.vertices[1].sub(face.vertices[0]).normalized();
    v = face.vertices[-1].sub(face.vertices[0]).normalized();
    return [u, v];
}

def layout(level: Level) -> int {
    offset = 0;
    for index in range(len(level.bsp.faces)) {
        face = level.bsp.faces[index];
        face.colors = [];
        face.light_uv = [];
        face.light_offset = -1;
        face.moving_light = index >= level.bsp.models[1].first_face;
        if face.emission or face.moving_light {
            continue;
        }
        width = face.vertices[1].sub(face.vertices[0]).length();
        height = face.vertices[-1].sub(face.vertices[0]).length();
        face.light_width = int(math.ceil(width / 32.0)) + 1;
        face.light_height = int(math.ceil(height / 32.0)) + 1;
        face.light_offset = offset;
        face.styles = [0];
        basis = axes(face);
        for vertex in face.vertices {
            delta = vertex.sub(face.vertices[0]);
            face.light_uv.extend(
                [
                    delta.dot(basis[0]) / width * float(face.light_width - 1),
                    delta.dot(basis[1]) / height * float(face.light_height - 1)
                ]
            );
        }
        offset += face.light_width * face.light_height * 3;
    }
    level.bsp.light_channels = 3;
    return offset;
}

def cache_key(level: Level, lamps: list[Lamp]) -> str {
    digest = hashlib.sha256(b"passion-lighting-1-spacing32-probes4-soft2-ambient012");
    digest.update(level.name.encode());
    for texture in level.bsp.textures {
        digest.update(texture.name.encode());
        digest.update(texture.rgba);
        digest.update(texture.encoded);
        digest.update(texture.pixels);
    }
    for face in level.bsp.faces {
        digest.update(str(face.texture).encode());
        for vertex in face.vertices {
            digest.update(struct.pack("<ddd", vertex.x, vertex.y, vertex.z));
        }
    }
    for lamp in lamps {
        digest.update(
            struct.pack(
                "<dddddddd",
                lamp.origin.x,
                lamp.origin.y,
                lamp.origin.z,
                lamp.color.x,
                lamp.color.y,
                lamp.color.z,
                lamp.radius,
                lamp.strength
            )
        );
    }
    return digest.hexdigest();
}

def pack_probes(lighting: Lighting) -> bytes {
    data = bytearray();
    for region in lighting.regions {
        for i in range(64) {
            sample = region.samples[i];
            data.append(1 if region.valid[i] else 0);
            for vector in [sample.ambient, sample.directed, sample.direction] {
                data.extend(struct.pack("<fff", vector.x, vector.y, vector.z));
            }
        }
    }
    return bytes(data);
}

def unpack_probes(data: bytes, lighting: Lighting) {
    if len(data) != 20 * 64 * 37 {
        raise ValueError("Invalid probe cache length");
    }
    offset = 0;
    for region in lighting.regions {
        region.samples = [];
        region.valid = [];
        for i in range(64) {
            if data[offset] > 1 {
                raise ValueError("Invalid probe validity");
            }
            region.valid.append(data[offset] == 1);
            offset += 1;
            vectors: list[Vec3] = [];
            for v in range(3) {
                components = struct.unpack("<fff", data[offset:offset + 12]);
                offset += 12;
                x = float(components[0]);
                y = float(components[1]);
                z = float(components[2]);
                if not math.isfinite(x)
                    or not math.isfinite(y)
                    or not math.isfinite(z)
                    or abs(x) > 16.0
                    or abs(y) > 16.0
                    or abs(z) > 16.0 {
                    raise ValueError("Invalid probe value");
                }
                vectors.append(Vec3(x=x, y=y, z=z));
            }
            region.samples.append(
                Illumination(
                    ambient=vectors[0], directed=vectors[1], direction=vectors[2]
                )
            );
        }
    }
}

def bake(level: Level, rooms: list[Chamber], cache_directory: str = "") {
    lighting = Lighting();
    level.lighting = lighting;
    colors = [
        Vec3(x=1.0, y=0.77, z=0.5),
        Vec3(x=0.68, y=0.86, z=1.0),
        Vec3(x=1.0, y=0.68, z=0.78)
    ];
    for room in rooms {
        ceiling = 320.0 if room.shape == 0 else (224.0 if room.shape == 1 else 384.0);
        x = float(room.x) * 640.0;
        y = float(room.y) * 640.0;
        z = float(room.y) * 32.0;
        for cy in [160.0, 480.0] {
            lighting.rig +>:Emits:+> Lamp(
                origin=Vec3(x=x + 320.0, y=y + cy, z=z + ceiling - 8.0),
                color=colors[room.theme]
            );
        }
        lighting.regions.append(
            ProbeRegion(origin=Vec3(x=x + 80.0, y=y + 80.0, z=z + 40.0))
        );
    }
    lamps = (lighting.rig spawn GatherLamps()).lamps;
    size = layout(level);
    path = "";
    if cache_directory {
        path = cache_directory + "/" + cache_key(level, lamps) + ".light";
        try {
            with open(path, "rb") as stream {
                data = stream.read();
            }
            if len(data) != 32 + size + 20 * 64 * 37
                or hashlib.sha256(data[32:]).digest() != data[:32] {
                raise ValueError("Invalid lighting cache");
            }
            unpack_probes(data[32 + size:], lighting);
            level.bsp.lighting = data[32:32 + size];
            lighting.cache_hit = True;
            print("LIGHTING cache hit", level.name);
            return;
        } except (OSError, ValueError) {}
    }
    # Doors are absent from static shadow rays; they are lit from probes as they move.
    excluded = [
        i
        for i in range(len(level.collision.models))
        if level.collision.models[i] != 0
    ];
    pixels = bytearray();
    print("LIGHTING baking", level.name, len(level.bsp.faces), "faces");
    for index in range(len(level.bsp.faces)) {
        face = level.bsp.faces[index];
        if face.light_offset < 0 {
            continue;
        }
        start = face.vertices[0];
        u = face.vertices[1].sub(start);
        v = face.vertices[-1].sub(start);
        for y in range(face.light_height) {
            for x in range(face.light_width) {
                # Inset boundary samples to avoid sampling inside the neighboring wall.
                s = max(
                    0.5 / u.length(),
                    min(1.0 - 0.5 / u.length(), float(x) / float(face.light_width - 1))
                );
                t = max(
                    0.5 / v.length(),
                    min(1.0 - 0.5 / v.length(), float(y) / float(face.light_height - 1))
                );
                point = start.add(u.scale(s)).add(v.scale(t)).add(
                    face.normal.scale(0.25)
                );
                sample = irradiance(
                    point, face.normal, lamps, level.collision, excluded
                );
                color = sample.ambient.add(sample.directed);
                for value in [color.x, color.y, color.z] {
                    pixels.append(int(max(0.0, min(127.0, value * 127.5))));
                }
            }
        }
        if index % 500 == 0 {
            print("LIGHTING faces", index, "/", len(level.bsp.faces));
        }
    }
    level.bsp.lighting = bytes(pixels);
    for region in lighting.regions {
        region.samples = [];
        region.valid = [];
        for z in range(4) {
            for y in range(4) {
                for x in range(4) {
                    point = region.origin.add(
                        Vec3(x=float(x) * 160.0, y=float(y) * 160.0, z=float(z) * 80.0)
                    );
                    valid = not level.collision.trace_point(
                        point, point, excluded
                    ).start_solid;
                    region.valid.append(valid);
                    region.samples.append(
                        irradiance(
                            point, Vec3(), lamps, level.collision, excluded, True
                        )
                            if valid
                            else Illumination(ambient=Vec3())
                    );
                }
            }
        }
    }
    if path {
        try {
            os.makedirs(cache_directory, exist_ok=True);
            payload = level.bsp.lighting + pack_probes(lighting);
            temporary = path + "." + str(os.getpid()) + ".tmp";
            with open(temporary, "wb") as stream {
                stream.write(hashlib.sha256(payload).digest() + payload);
            }
            os.replace(temporary, path);
        } except OSError {
            print("LIGHTING cache unavailable; using completed bake");
        }
    }
    print("LIGHTING ready", len(pixels), "lightmap bytes, 1280 probes");
}
