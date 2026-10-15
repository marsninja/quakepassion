"""Themes: what kind of place a level is.

A theme is a recipe the generator follows for one level: which archetypes
its rooms lean toward and which is its centrepiece, how its floors are
joined up and down (stairs, lifts, holes to drop through, flooded shafts,
jump pads), which way it drifts (up a spire, down a mine), how it loops,
which districts dress it, which foes hold it, what liquid lies in its pits
and how it is lit. Every theme draws on the same archetypes and connectors,
so a theme is data, not code: a seed (and a run's depth) picks one, and the
rest of the generator reads it."""
import from .random { mix32 }

"""A theme: its name and title, and the weights and leanings it gives the
generator. Archetypes and connectors missing from its weights keep weight
1 and 0."""
obj Theme {
    has key: str,
        title: str,
        # Archetype weights, multiplying each beat kind's own.
        kinds: dict[str, float] = {},
        # The centrepiece: the archetype one great room takes, and how much
        # bigger it grows.
        centre: str = "",
        centre_grow: int = 2,
        # How rooms placed one above another are joined: stair, lift, drop,
        # water, jumppad; and how often a room is placed so.
        connectors: dict[str, float] = {"stair": 1.0},
        stack: float = 0.2,
        # Leanings added to the niche's: verticality, loopiness, density,
        # and rooms more or fewer.
        vertical: float = 0.0,
        loop: float = 0.0,
        dense: float = 0.0,
        rooms: int = 0,
        # The way the level drifts as it goes: 1 up, -1 down, 0 either.
        drift: int = 0,
        # The mission archetypes it sets (keys, relays, guardian, mixed),
        # none for the seed's own.
        missions: list[str] = [],
        # The liquid in its pits (lava, slime, water; "" the district's), and
        # how much more often its pits and cisterns are flooded.
        liquid: str = "",
        flood: float = 0.0,
        # The districts it is dressed in, first choice first.
        kits: list[str] = [],
        # The kinds of foe that hold it: soldier, beast, undead, arcane,
        # strogg, q3.
        foes: list[str] = [],
        # Its light: how bright against the district's own, and its colour
        # ("" the district's).
        light: float = 1.0,
        tint: str = "",
        # How often a tall room opens to the sky, a corridor is widened, and
        # a link is made a teleporter on purpose.
        sky: float = 0.0,
        wide: float = 0.5,
        gates: float = 0.0;
}

glob THEMES: list[Theme] = [
    Theme(
        key="keep", title="Keep",
        kinds={"court": 4.0, "towerhub": 3.0, "hall": 2.0, "stairhall": 2.0, "crosshall": 2.0, "octagon": 1.5},
        centre="court", connectors={"stair": 3.0, "lift": 1.5, "drop": 1.0}, stack=0.3,
        missions=["keys", "relays"], liquid="water", kits=["Stone Keep", "Gothic Ruin"],
        foes=["soldier", "undead", "beast"], sky=0.2
    ),
    Theme(
        key="cathedral", title="Cathedral",
        kinds={"overlook": 4.0, "hall": 3.0, "crosshall": 3.0, "crypt": 2.0, "octagon": 2.0, "atrium": 2.0},
        centre="crosshall", centre_grow=3, connectors={"stair": 3.0, "drop": 1.0}, stack=0.25,
        missions=["guardian", "keys"], kits=["Gothic Ruin", "Runic Halls", "Stone Keep"],
        foes=["undead", "arcane"], light=1.1, tint="255 220 190"
    ),
    Theme(
        key="spire", title="Spire",
        kinds={"towerhub": 4.0, "shaft": 3.0, "atrium": 2.0, "overlook": 2.0, "vault": 1.0},
        centre="towerhub", connectors={"lift": 3.0, "stair": 2.0, "jumppad": 1.0}, stack=0.6,
        vertical=0.4, drift=1, kits=["Runic Halls", "Gothic Ruin", "Tech Complex"],
        foes=["arcane", "undead"], sky=0.3
    ),
    Theme(
        key="dungeon", title="Dungeon",
        kinds={"crypt": 4.0, "maze": 2.0, "vault": 2.0, "cellblock": 2.0, "lhall": 2.0, "hall": 1.0},
        centre="crypt", connectors={"drop": 3.0, "stair": 2.0, "lift": 1.0}, stack=0.35, drift=-1, dense=0.1,
        liquid="water", kits=["Stone Keep", "Runic Halls"], foes=["undead", "beast"], light=0.7
    ),
    Theme(
        key="cloister", title="Cloister",
        kinds={"court": 5.0, "crosshall": 2.0, "hall": 2.0, "terraces": 2.0, "octagon": 2.0},
        centre="court", connectors={"stair": 3.0}, stack=0.1, loop=0.3,
        kits=["Stone Keep", "Gothic Ruin"], foes=["soldier", "undead"], light=1.15, sky=0.3
    ),
    Theme(
        key="ruins", title="Ruins",
        kinds={"court": 3.0, "chasm": 3.0, "bridgespan": 3.0, "terraces": 2.0, "cave": 2.0, "catwalk": 1.0},
        centre="chasm", connectors={"drop": 2.0, "stair": 2.0, "jumppad": 1.0, "lift": 1.0}, stack=0.3,
        liquid="lava", kits=["Gothic Ruin", "Runic Halls"], foes=["beast", "undead", "q3"], sky=0.6
    ),
    Theme(
        key="necropolis", title="Necropolis",
        kinds={"crypt": 4.0, "vault": 3.0, "ziggurat": 2.0, "court": 2.0, "maze": 1.0},
        centre="ziggurat", connectors={"stair": 3.0, "drop": 1.0},
        kits=["Runic Halls", "Stone Keep", "Gothic Ruin"], foes=["undead", "arcane"],
        light=0.75, tint="200 210 255"
    ),
    Theme(
        key="ziggurat", title="Ziggurat",
        kinds={"ziggurat": 5.0, "terraces": 3.0, "court": 2.0, "vault": 2.0, "stairhall": 2.0},
        centre="ziggurat", connectors={"stair": 3.0, "lift": 1.0}, drift=1,
        kits=["Gothic Ruin", "Runic Halls"], foes=["arcane", "beast"], sky=0.4
    ),
    Theme(
        key="factory", title="Factory",
        kinds={"cratehall": 3.0, "catwalk": 3.0, "hall": 2.0, "overlook": 2.0, "shaft": 1.0},
        centre="catwalk", connectors={"lift": 3.0, "stair": 2.0, "drop": 1.0}, stack=0.35,
        liquid="lava", kits=["Strogg Works", "Strogg Outpost", "Tech Complex"], foes=["strogg"]
    ),
    Theme(
        key="refinery", title="Refinery",
        kinds={"cistern": 4.0, "catwalk": 3.0, "bridgespan": 2.0, "hall": 2.0},
        centre="cistern", connectors={"lift": 2.0, "stair": 2.0, "water": 1.0}, liquid="slime", flood=0.4,
        kits=["Strogg Works", "Slipgate Base", "Tech Complex"], foes=["strogg", "soldier"], tint="200 255 180"
    ),
    Theme(
        key="powerplant", title="Power Plant",
        kinds={"towerhub": 3.0, "shaft": 3.0, "catwalk": 2.0, "vault": 2.0, "overlook": 2.0},
        centre="towerhub", connectors={"lift": 4.0, "stair": 1.0}, stack=0.45, missions=["relays"],
        kits=["Tech Complex", "Strogg Outpost", "Slipgate Base"], foes=["strogg", "soldier"], tint="190 220 255"
    ),
    Theme(
        key="warehouse", title="Warehouse",
        kinds={"cratehall": 5.0, "overlook": 2.0, "hall": 2.0, "lhall": 2.0},
        centre="cratehall", centre_grow=3, connectors={"stair": 2.0, "lift": 2.0}, dense=0.1,
        kits=["Strogg Outpost", "Tech Complex", "Arena Works"], foes=["soldier", "strogg"]
    ),
    Theme(
        key="mine", title="Mine",
        kinds={"cave": 4.0, "shaft": 3.0, "chasm": 2.0, "catwalk": 2.0, "crypt": 1.0},
        centre="shaft", connectors={"lift": 3.0, "drop": 2.0, "stair": 1.0}, stack=0.45, vertical=0.3, drift=-1,
        liquid="lava", kits=["Deep Mines", "Strogg Works"], foes=["strogg", "beast"], light=0.8
    ),
    Theme(
        key="slipgate", title="Slipgate Complex",
        kinds={"hall": 3.0, "vault": 2.0, "octagon": 2.0, "crosshall": 2.0, "atrium": 1.0},
        centre="octagon", connectors={"stair": 2.0, "lift": 1.0}, gates=0.35,
        kits=["Slipgate Base", "Tech Complex"], foes=["soldier", "beast"]
    ),
    Theme(
        key="waterworks", title="Waterworks",
        kinds={"cistern": 4.0, "bridgespan": 2.0, "shaft": 2.0, "catwalk": 2.0, "hall": 1.0},
        centre="cistern", connectors={"water": 3.0, "lift": 2.0, "stair": 1.0}, stack=0.35, liquid="water", flood=0.5,
        kits=["Tech Complex", "Slipgate Base", "Strogg Outpost"], foes=["soldier", "strogg"]
    ),
    Theme(
        key="detention", title="Detention Block",
        kinds={"cellblock": 5.0, "hall": 2.0, "lhall": 2.0, "maze": 1.0, "towerhub": 1.0},
        centre="cellblock", connectors={"stair": 2.0, "lift": 2.0}, missions=["keys"],
        kits=["Strogg Outpost", "Tech Complex", "Stone Keep"], foes=["soldier", "strogg"]
    ),
    Theme(
        key="hangar", title="Hangar",
        kinds={"atrium": 3.0, "overlook": 3.0, "cratehall": 2.0, "arena": 2.0, "hall": 1.0},
        centre="arena", centre_grow=3, connectors={"jumppad": 3.0, "lift": 2.0, "stair": 1.0}, stack=0.45,
        vertical=0.3, kits=["Arena Works", "Strogg Outpost", "Tech Complex"], foes=["q3", "strogg"], sky=0.3
    ),
    Theme(
        key="laboratory", title="Laboratory",
        kinds={"vault": 3.0, "hall": 3.0, "octagon": 2.0, "crosshall": 2.0, "lhall": 2.0},
        centre="octagon", connectors={"lift": 2.0, "stair": 2.0}, missions=["relays", "keys"],
        kits=["Tech Complex", "Slipgate Base"], foes=["soldier", "strogg", "arcane"], light=1.2, tint="220 235 255"
    ),
    Theme(
        key="caverns", title="Caverns",
        kinds={"cave": 6.0, "chasm": 2.0, "cistern": 1.0, "terraces": 1.0},
        centre="cave", centre_grow=3, connectors={"drop": 2.0, "stair": 2.0, "water": 1.5, "lift": 1.0}, stack=0.35,
        liquid="water", kits=["Deep Mines", "Runic Halls", "Gothic Ruin"], foes=["beast", "undead"], light=0.8
    ),
    Theme(
        key="sunken", title="Sunken Temple",
        kinds={"cistern": 4.0, "crypt": 2.0, "octagon": 2.0, "ziggurat": 2.0, "overlook": 1.0},
        centre="cistern", connectors={"water": 4.0, "stair": 1.0}, stack=0.35, liquid="water", flood=0.5,
        kits=["Runic Halls", "Gothic Ruin", "Stone Keep"], foes=["arcane", "undead"], tint="180 220 255"
    ),
    Theme(
        key="forge", title="Lava Forge",
        kinds={"catwalk": 4.0, "bridgespan": 3.0, "chasm": 3.0, "hall": 1.0, "cave": 1.0},
        centre="catwalk", centre_grow=3, connectors={"stair": 2.0, "lift": 2.0, "drop": 1.0}, liquid="lava", flood=0.5,
        kits=["Runic Halls", "Deep Mines", "Strogg Works"], foes=["beast", "arcane", "strogg"], tint="255 190 140"
    ),
    Theme(
        key="abyss", title="Abyss",
        kinds={"shaft": 3.0, "chasm": 3.0, "catwalk": 2.0, "towerhub": 2.0, "cave": 2.0},
        centre="shaft", connectors={"drop": 5.0, "lift": 2.0, "water": 0.5, "stair": 1.0}, stack=0.6, vertical=0.5, drift=-1,
        kits=["Deep Mines", "Runic Halls", "Gothic Ruin"], foes=["beast", "undead"], light=0.8
    ),
    Theme(
        key="skyislands", title="Sky Islands",
        kinds={"bridgespan": 4.0, "court": 3.0, "octagon": 2.0, "ziggurat": 1.0, "arena": 1.0},
        centre="bridgespan", connectors={"jumppad": 4.0, "lift": 2.0, "stair": 1.0}, stack=0.4, vertical=0.3,
        kits=["Arena Works", "Gothic Ruin"], foes=["q3", "arcane"], sky=0.9
    ),
    Theme(
        key="gauntlet", title="Gauntlet",
        kinds={"arena": 5.0, "hall": 2.0, "stairhall": 2.0},
        centre="arena", connectors={"stair": 2.0, "lift": 1.0, "drop": 1.0}, loop=-0.3, dense=0.2,
        missions=["guardian"], foes=[]
    ),
    Theme(
        key="colosseum", title="Colosseum",
        kinds={"arena": 4.0, "terraces": 3.0, "court": 2.0, "crypt": 1.0},
        centre="arena", centre_grow=4, dense=0.15, missions=["guardian"],
        kits=["Gothic Ruin", "Arena Works", "Stone Keep"], foes=["beast", "q3"], sky=0.4
    ),
    Theme(
        key="siege", title="Siege",
        kinds={"court": 4.0, "towerhub": 3.0, "terraces": 2.0, "stairhall": 2.0, "hall": 1.0},
        centre="court", connectors={"stair": 3.0, "lift": 1.0}, dense=0.1,
        kits=["Stone Keep", "Gothic Ruin"], foes=["soldier", "beast"], sky=0.4
    ),
    Theme(
        key="labyrinth", title="Labyrinth",
        kinds={"maze": 5.0, "lhall": 3.0, "crypt": 2.0, "crosshall": 2.0},
        centre="maze", centre_grow=3, loop=0.3, rooms=3,
        kits=["Runic Halls", "Stone Keep", "Strogg Outpost"], foes=["beast", "undead"], light=0.85
    ),
    Theme(
        key="clockwork", title="Clockwork",
        kinds={"vault": 2.0, "shaft": 2.0, "catwalk": 2.0, "hall": 2.0, "overlook": 2.0, "towerhub": 1.0},
        centre="towerhub", connectors={"lift": 3.0, "stair": 1.0}, stack=0.35, missions=["relays"],
        kits=["Tech Complex", "Strogg Works", "Runic Halls"], foes=["arcane", "strogg"], tint="255 230 180"
    ),
    Theme(
        key="twintowers", title="Twin Towers",
        kinds={"towerhub": 5.0, "bridgespan": 3.0, "shaft": 2.0, "court": 1.0},
        centre="towerhub", connectors={"lift": 2.0, "stair": 2.0, "jumppad": 1.0}, stack=0.5, vertical=0.4,
        kits=["Gothic Ruin", "Tech Complex", "Arena Works"], foes=["q3", "arcane"], sky=0.4
    ),
    Theme(
        key="spiral", title="Spiral Descent",
        kinds={"shaft": 3.0, "towerhub": 3.0, "terraces": 2.0, "chasm": 2.0, "overlook": 2.0},
        centre="shaft", connectors={"stair": 3.0, "drop": 2.0, "lift": 1.5}, stack=0.4, vertical=0.4, drift=-1,
        kits=["Runic Halls", "Deep Mines"], foes=["undead", "beast"]
    )
];

"""The theme a run's level takes: drawn from the level's own seed, so
neighbouring seeds and the levels of one run differ."""
def theme_for(seed: int) -> Theme {
    return THEMES[mix32(seed * 2246822519 % 4294967296 + 7919) % len(THEMES)];
}

"""A theme by its key, or None."""
def theme_named(key: str) -> Theme | None {
    for theme in THEMES {
        if theme.key == key {
            return theme;
        }
    }
    return None;
}

"""An archetype's weight in a theme."""
def kind_weight(theme: Theme | None, kind: str) -> float {
    if theme is None {
        return 1.0;
    }
    return theme.kinds.get(kind, 1.0);
}
