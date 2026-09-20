import struct;
import from engine.core.menu { map_names, is_q1_level }

test "map catalogue deduplicates archives and sorts map names" {
    assert map_names(
        [
            "maps/e1m2.bsp",
            "maps/e1m1.bsp",
            "maps/e1m2.bsp",
            "textures/a.tga",
            "maps/e1m1.aas"
        ]
    )
        == ["e1m1", "e1m2"];
}

test "Quake brush models are excluded but both player spawn kinds are accepted" {
    for kind in ["info_player_start", "info_player_deathmatch", "worldspawn"] {
        entities = ('{"classname" "' + kind + '"}\x00').encode("utf-8");
        data = struct.pack("<iii", 29, 12, len(entities)) + entities;
        assert is_q1_level(data) == (kind != "worldspawn");
    }
}
