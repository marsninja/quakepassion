"""Kits: the materials of each district, taken from the original levels.

Each kit is one level's own palette, read off how that level uses its
textures (scripts/passion_corpus.jac lists, for every texture of every
level, the area it covers on floors, walls and ceilings and on narrow trim):
the floor it is walked on most, the wall it shows most, its ceiling, the
narrow texture its edges are trimmed with, the supports its walls are
ribbed with, the panels that set off a wall, the texture its lights are
made of, its doors, sky and liquid. Materials are named as the studio names
them (`q1:e1m1/tech08_1`, `q2:e1u1/metal2_1`, `q3:textures/...`)."""

"""One district's materials, how big its textures are drawn (`scale`, world
units a texel; Quake III's large images are drawn at half), the colour and
strength of its lamps, how bright its darkest corners stay (`ambient`), and
the source level it was read from."""
obj Kit {
    has name: str,
        game: str,
        source: str,
        floor: str,
        wall: str,
        ceiling: str,
        trim: str,
        support: str,
        lower: str,
        accent: str,
        light: str,
        door: str,
        step: str,
        sky: str,
        liquid: str,
        scale: float = 1.0,
        # Other walls, floors and ceilings the level uses, for rooms that
        # take a variant of the district's look.
        walls: list[str] = [],
        floors: list[str] = [],
        ceilings: list[str] = [],
        lamp_color: str = "255 255 255",
        lamp_level: int = 200,
        ambient: float = 0.08;
}

import from .level_kits { LEVEL_KITS }

glob KITS: list[Kit] = [
         Kit(
             name="Slipgate Base",
             game="q1",
             source="e1m1",
             floor="q1:e1m1/sfloor4_2",
             wall="q1:e1m1/tech08_1",
             ceiling="q1:e1m1/tech01_6",
             trim="q1:e1m1/tech04_1",
             support="q1:e1m1/tech04_3",
             lower="q1:e1m1/uwall1_2",
             accent="q1:e1m1/comp1_1",
             light="q1:e1m1/tlight11",
             door="q1:e1m1/door02_1",
             step="q1:e1m1/tech01_9",
             sky="q1:e1m1/sky4",
             liquid="q1:e1m1/*slime0",
             walls=["q1:e1m1/uwall1_2", "q1:e1m1/twall5_1", "q1:e1m1/tech07_2"],
             floors=["q1:e1m1/ground1_2", "q1:e1m1/ground1_6"],
             ceilings=["q1:e1m1/tech04_1", "q1:e1m1/tech01_1"],
             lamp_color="255 236 214",
             lamp_level=154
         ),
         Kit(
             name="Stone Keep",
             game="q1",
             source="e1m2",
             floor="q1:e1m2/wizmet1_7",
             wall="q1:e1m2/wbrick1_5",
             ceiling="q1:e1m2/wizwood1_5",
             trim="q1:e1m2/stone1_3",
             support="q1:e1m2/wizmet1_2",
             lower="q1:e1m2/wswamp2_1",
             accent="q1:e1m2/wswamp2_1",
             light="q1:e1m2/wizmet1_2",
             door="q1:e1m2/adoor09_2",
             step="q1:e1m2/wiz1_1",
             sky="q1:e1m2/sky1",
             liquid="q1:e1m2/*04water1",
             walls=["q1:e1m2/wizmet1_2", "q1:e1m2/wiz1_4"],
             floors=["q1:e1m2/wswamp1_2", "q1:e1m2/woodflr1_4"],
             ceilings=["q1:e1m2/wizwood1_4", "q1:e1m2/wizmet1_2"],
             lamp_color="255 214 160",
             lamp_level=162
         ),
         Kit(
             name="Runic Halls",
             game="q1",
             source="e3m2",
             floor="q1:e3m2/metal5_4",
             wall="q1:e3m2/metal4_4",
             ceiling="q1:e3m2/cop1_6",
             trim="q1:e3m2/met5_1",
             support="q1:e3m2/metal4_2",
             lower="q1:e3m2/metalt1_1",
             accent="q1:e3m2/rune2_5",
             light="q1:e3m2/light3_7",
             door="q1:e3m2/dr07_1",
             step="q1:e3m2/metal5_3",
             sky="q1:e3m2/sky4",
             liquid="q1:e3m2/*lava1",
             walls=["q1:e3m2/metal4_2", "q1:e3m2/metalt1_1"],
             floors=["q1:e3m2/metal5_3", "q1:e3m2/cop1_6"],
             ceilings=["q1:e3m2/metal4_7", "q1:e3m2/metal5_4"],
             lamp_color="255 220 190",
             lamp_level=147
         ),
         Kit(
             name="Tech Complex",
             game="q1",
             source="e4m1",
             floor="q1:e4m1/sfloor4_5",
             wall="q1:e4m1/tech14_1",
             ceiling="q1:e4m1/tech01_6",
             trim="q1:e4m1/tech04_5",
             support="q1:e4m1/tech06_1",
             lower="q1:e4m1/tech05_1",
             accent="q1:e4m1/tech13_2",
             light="q1:e4m1/tlight08",
             door="q1:e4m1/door02_7",
             step="q1:e4m1/tech04_7",
             sky="q1:e4m1/sky4",
             liquid="q1:e4m1/*water1",
             walls=["q1:e4m1/tech06_1", "q1:e4m1/tech05_1", "q1:e4m1/tech13_2"],
             floors=["q1:e4m1/sfloor4_6", "q1:e4m1/sfloor4_7"],
             ceilings=["q1:e4m1/twall5_2", "q1:e4m1/ecop1_8"],
             lamp_color="230 240 255",
             lamp_level=154
         ),
         Kit(
             name="Strogg Outpost",
             game="q2",
             source="base1",
             floor="q2:e1u1/floor3_1",
             wall="q2:e1u1/metal2_1",
             ceiling="q2:e1u1/grate2_1",
             trim="q2:e1u1/flat1_1",
             support="q2:e1u1/support1_1",
             lower="q2:e1u1/metal3_5",
             accent="q2:e1u1/box1_3",
             light="q2:e1u1/baselt_2",
             door="q2:e1u1/metal3_5",
             step="q2:e1u1/metal3_5",
             sky="q2:e1u1/sky1",
             liquid="q2:e1u1/bluwter",
             walls=["q2:e1u1/ggrat4_2", "q2:e1u1/rocks19_1"],
             floors=["q2:e1u1/metal3_5", "q2:e1u1/metal1_8"],
             ceilings=["q2:e1u1/grate1_3", "q2:e1u1/metal1_5"],
             lamp_color="235 245 255",
             lamp_level=154
         ),
         Kit(
             name="Deep Mines",
             game="q2",
             source="mine1",
             floor="q2:e2u1/flr1_2",
             wall="q2:e2u1/rocks19_1",
             ceiling="q2:e2u1/metal3_1",
             trim="q2:e2u1/metal18_1",
             support="q2:e2u1/mmtl15_5",
             lower="q2:e2u1/metal3_1",
             accent="q2:e2u1/metal3_1",
             light="q2:e2u1/lsrlt1",
             door="q2:e2u1/metal3_1",
             step="q2:e2u1/mmtl15_5",
             sky="q2:e2u1/sky1",
             liquid="q2:e2u1/lava",
             walls=["q2:e2u1/metal3_1", "q2:e2u1/mmtl15_5"],
             floors=["q2:e2u1/mmtl16_6", "q2:e2u1/rocks19_1"],
             ceilings=["q2:e2u1/rrock1_2", "q2:e2u1/rocks24_2"],
             lamp_color="255 210 150",
             lamp_level=162
         ),
         Kit(
             name="Strogg Works",
             game="q2",
             source="fact1",
             floor="q2:e2u2/floor1_7",
             wall="q2:e2u2/metal25_3",
             ceiling="q2:e2u2/metal25_2",
             trim="q2:e2u2/metal18_2",
             support="q2:e2u2/support1_1",
             lower="q2:e2u2/metal25_2",
             accent="q2:e1u1/box1_3",
             light="q2:e2u3/baselt_a",
             door="q2:e2u2/metal25_2",
             step="q2:e2u2/metal18_2",
             sky="q2:e2u2/sky1",
             liquid="q2:e2u2/lava",
             walls=["q2:e2u2/support1_1", "q2:e2u2/metal25_2"],
             floors=["q2:e2u2/flr1_2", "q2:e2u2/floor1_5"],
             ceilings=["q2:e2u2/metal28_1", "q2:e2u2/flr1_3"],
             lamp_color="255 235 200",
             lamp_level=154
         ),
         Kit(
             name="Gothic Ruin",
             game="q3",
             source="q3dm1",
             floor="q3:textures/gothic_floor/largerblock3b",
             wall="q3:textures/gothic_block/blocks18c",
             ceiling="q3:textures/gothic_ceiling/woodceiling1a",
             trim="q3:textures/gothic_trim/baseboard09_l2",
             support="q3:textures/gothic_trim/metalsupport4b",
             lower="q3:textures/gothic_block/blocks15",
             accent="q3:textures/gothic_wall/iron01_e",
             light="q3:textures/gothic_light/gothic_light3",
             door="q3:textures/gothic_door/skull_door_a",
             step="q3:textures/gothic_floor/xstepborder3",
             sky="q3:textures/skies/toxicsky",
             liquid="q1:e3m2/*lava1",
             scale=0.5,
             walls=["q3:textures/gothic_block/blocks15", "q3:textures/gothic_trim/pitted_rust3"],
             floors=["q3:textures/gothic_floor/metalbridge06"],
             ceilings=["q3:textures/gothic_ceiling/woodceiling1b_dark"],
             lamp_color="255 200 150",
             lamp_level=162
         ),
         Kit(
             name="Arena Works",
             game="q3",
             source="q3dm17",
             floor="q3:textures/base_floor/diamond2c",
             wall="q3:textures/base_wall/c_met5_2",
             ceiling="q3:textures/base_wall/metalblack03",
             trim="q3:textures/base_trim/border11b",
             support="q3:textures/base_trim/basemetalsupport",
             lower="q3:textures/base_wall/basewall01",
             accent="q3:textures/base_wall/atech1_e",
             light="q3:textures/base_light/ceil1_38",
             door="q3:textures/base_wall/metalblack03",
             step="q3:textures/base_trim/pewter",
             sky="q3:textures/skies/toxicsky",
             liquid="q1:e4m1/*water1",
             scale=0.5,
             walls=["q3:textures/base_wall/metalblack03"],
             floors=["q3:textures/base_wall/metfloor_block_3"],
             ceilings=["q3:textures/base_wall/c_met7_2"],
             lamp_color="220 235 255",
             lamp_level=154
         )
     ];

"""A room's wall, floor and ceiling: the kit's own, or for a room taking a
variant (`variant` above 0) one of the others the level uses."""
def kit_surfaces(kit: Kit, variant: int) -> list[str] {
    if variant <= 0 {
        return [kit.wall, kit.floor, kit.ceiling];
    }
    walls = [kit.wall] + kit.walls;
    floors = [kit.floor] + kit.floors;
    ceilings = [kit.ceiling] + kit.ceilings;
    return [walls[variant % len(walls)], floors[(variant // 3) % len(floors)], ceilings[(variant // 7) % len(ceilings)]];
}

"""A water a kit's game has, for a pit that must stay wadeable when the
kit's own liquid would kill."""
def kit_water(kit: Kit) -> str {
    lowered = kit.liquid.lower();
    if "lava" not in lowered and "slime" not in lowered {
        return kit.liquid;
    }
    return "q2:e1u1/bluwter" if kit.game == "q2" else "q1:e1m2/*04water1";
}

"""A kit from a row of `LEVEL_KITS` (one original's own palette): what it
lacks (a sky, a liquid) taken from the first kit of its game."""
def kit_from_row(row: list[str]) -> Kit {
    game = row[0];
    first = KITS[0];
    for kit in KITS {
        if kit.game == game {
            first = kit;
            break;
        }
    }
    return Kit(
        name=game + " " + row[1],
        game=game,
        source=row[1],
        floor=row[2],
        wall=row[3],
        ceiling=row[4],
        trim=row[5],
        support=row[6],
        lower=row[7],
        accent=row[8],
        light=row[9],
        door=row[10],
        step=row[11],
        sky=row[12] if row[12] else first.sky,
        liquid=row[13] if row[13] else first.liquid,
        scale=0.5 if game == "q3" else 1.0,
        walls=[name for name in row[14].split("|") if name],
        floors=[name for name in row[15].split("|") if name],
        ceilings=[name for name in row[16].split("|") if name],
        lamp_color=first.lamp_color,
        lamp_level=first.lamp_level
    );
}

"""The hand-picked kits, then every original's own (`level_kits.jac`), in
the order `LEVEL_KITS` lists them."""
glob ALL_KITS: list[Kit] = KITS + [kit_from_row(row) for row in LEVEL_KITS];

"""The district of an original's own kit (`game:map`), or the first kit of
its game when it has none."""
def level_district(spec: str) -> int {
    parts = spec.split(":");
    for (index, row) in enumerate(LEVEL_KITS) {
        if row[0] == parts[0] and row[1] == parts[1] {
            return len(KITS) + index;
        }
    }
    for (index, kit) in enumerate(KITS) {
        if kit.game == parts[0] {
            return index;
        }
    }
    return 0;
}

"""The kit of a district (districts past the last kit wrap round)."""
def kit_of(district: int) -> Kit {
    return ALL_KITS[district % len(ALL_KITS)];
}
