import struct;
import from engine.world.lightstyles {
    LightStyles,
    LightSwitch,
    HasLightStyles,
    Switches,
    LightStyleTick,
    load_light_styles,
    letter_scale
}
import from engine.world.world { World }
import from engine.formats.bsp { Bsp, MapEntity }
import from engine.formats.q1.wad { wad_lumps, wad_pictures }

test "style letters scale brightness around normal" {
    assert letter_scale("a") == 0.0 and letter_scale("m") == 1.0;
    assert letter_scale("z") > 2.0;
}

test "animated styles play at ten frames a second and switches toggle" {
    world = World();
    bsp = Bsp(game="q1");
    bsp.entities = [
        MapEntity(fields={"classname": "worldspawn"}),
        MapEntity(fields={"classname": "light", "targetname": "lamp", "style": "32"}),
        MapEntity(fields={"classname": "light", "targetname": "dark", "style": "33", "spawnflags": "1"})
    ];
    styles = load_light_styles(world, bsp);
    assert styles is not None;
    # Style 4 is the fast strobe "mamamamamama".
    assert styles.values[4] == 1.0 and styles.values[0] == 1.0;
    assert styles.values[32] == 1.0 and styles.values[33] == 0.0;
    world spawn LightStyleTick(dt=0.1);
    assert styles.values[4] == 0.0;
    before = styles.serial;
    switches = [styles->:Switches:->][?:LightSwitch];
    assert len(switches) == 2;
    switches[0].activation.pending = 1;
    switches[1].activation.pending = 1;
    world spawn LightStyleTick(dt=0.01);
    assert styles.values[32] == 0.0 and styles.values[33] == 1.0 and styles.serial > before;
    # Q3 lighting has no styles.
    assert load_light_styles(World(), Bsp(game="q3")) is None;
}

test "gfx.wad pictures decode through the palette with index 255 transparent" {
    palette = bytes([(i * 3 + c) % 256 for i in range(256) for c in range(3)]);
    picture = struct.pack("<ii", 2, 1) + bytes([1, 255]);
    table_at = 12 + len(picture);
    name = b"sbar" + b"\x00" * 12;
    record = struct.pack("<iii", 12, len(picture), len(picture)) + bytes([66, 0, 0, 0]) + name;
    data = b"WAD2" + struct.pack("<ii", 1, table_at) + picture + record;
    lumps = wad_lumps(data);
    assert len(lumps) == 1 and lumps[0].name == "sbar" and lumps[0].kind == 66;
    pictures = wad_pictures(data, palette);
    sbar = pictures["sbar"];
    assert sbar.width == 2 and sbar.height == 1;
    assert list(sbar.pixels) == [3, 4, 5, 255, 253, 254, 255, 0];
}
