"""Native bake/cache acceptance with synthetic textures and no display required."""
import os;
import time;
import from games.passion.generate { generate }
import from games.passion.lighting { cache_key, probe_count }
import from games.passion.materials { MAT_LAMP, LAMP_COLORS }
import from engine.world.lighting { GatherLamps }
import from engine.world.world { World }
import from engine.formats.bsp { Texture }
import from engine.math.vec3 { Vec3 }
with entry {
    directory = os.environ.get("QP_LIGHT_TEST_CACHE", "");
    assert directory and "qp-lighting-" in directory , "Use an isolated qp-lighting- temporary directory";
    textures = [
        Texture(name="test-" + str(i), width=1, height=1, rgba=b"\xff\xff\xff\xff")
        for i in range(MAT_LAMP + LAMP_COLORS)
    ];
    start = time.perf_counter();
    first = generate(World(), "v2-42", textures, directory);
    cold = time.perf_counter() - start;
    assert not first.lighting.cache_hit;
    assert first.bsp.lighting and len(first.lighting.regions) == first.bsp.clusters;
    assert first.lighting.lookup and probe_count(first.lighting) > 0;
    assert len(set(first.bsp.lighting)) > 20;
    assert [
        face
        for face in first.bsp.faces
        if face.emission
    ];
    assert all(
        face.light_offset < 0
        for face in first.bsp.faces
        if face.moving_light
    );
    start = time.perf_counter();
    warm = generate(World(), "v2-42", textures, directory);
    elapsed = time.perf_counter() - start;
    assert warm.lighting.cache_hit and warm.bsp.lighting == first.bsp.lighting;
    starts = [
        entity
        for entity in first.bsp.entities
        if entity.fields.get("classname", "") == "info_player_start"
    ];
    parts = starts[0].fields["origin"].split();
    spot = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]) + 32.0);
    a = first.lighting.sample(spot);
    b = warm.lighting.sample(spot);
    assert a.ambient.length() > 0.12 or a.directed.length() > 0.0;
    assert a.ambient.sub(b.ambient).length() < 0.00001;
    lamps = (first.lighting.rig spawn GatherLamps()).lamps;
    key = cache_key(first, lamps);
    first.bsp.textures[0].rgba = b"\x00\xff\xff\xff";
    assert cache_key(first, lamps) != key;
    first.bsp.textures[0].rgba = b"\xff\xff\xff\xff";
    with open(directory + "/" + key + ".light", "wb") as stream {
        stream.write(b"corrupt");
    }
    repaired = generate(World(), "v2-42", textures, directory);
    assert not repaired.lighting.cache_hit
        and repaired.bsp.lighting == warm.bsp.lighting;
    print(
        "LIGHTING PASS cold seconds",
        cold,
        "warm seconds",
        elapsed,
        "bytes",
        len(warm.bsp.lighting),
        "probes",
        probe_count(warm.lighting),
        "faces",
        len(warm.bsp.faces)
    );
}
