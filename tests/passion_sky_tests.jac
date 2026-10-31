"""A made level's sky: which kit's it is, and that every kit has a real one."""
import from games.passion.kits { ALL_KITS, level_district, kit_of }
import from games.passion.brushwork { sky_kit }
import from games.passion.space { Space }

test "a level shows the sky of the kit over most of its open floor" {
    jail = level_district("q2:jail1");
    base = level_district("q2:base1");
    indoors = Space(id=0, district=base, w=50, d=50);
    assert sky_kit([indoors]) is None;
    spaces = [
        indoors,
        Space(id=1, district=base, w=4, d=4, sky=True),
        Space(id=2, district=jail, w=8, d=8, sky=True),
        Space(id=3, district=base, w=9, d=9, sky=True)
    ];
    open_kit = sky_kit(spaces);
    assert open_kit is not None and open_kit.name == kit_of(base).name;
    spaces.append(Space(id=4, district=jail, w=6, d=6, sky=True));
    open_kit = sky_kit(spaces);
    assert open_kit is not None and open_kit.name == kit_of(jail).name;
}

test "every kit's sky is a sky of its own game, not a tile that goes by another name" {
    for kit in ALL_KITS {
        assert kit.sky.startswith(kit.game + ":");
        last = kit.sky.split("/")[-1];
        if kit.game == "q3" {
            assert kit.sky.startswith("q3:textures/skies/");
        } else {
            assert last.startswith("sky");
        }
    }
}
