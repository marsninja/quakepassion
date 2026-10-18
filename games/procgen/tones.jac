"""How the games' own surfaces are toned, family by family: for each game
and each family of wall picture (and the model skins), the median colour,
lightness spread and saturation of the game's own pictures of that family.
The generator's pictures are graded to these (games/procgen/image.jac
graded) so a family reads as the game's does: Quake II's metal as dark and
muted as Quake II's, not as bright as a recipe left it.

Each entry is a median over a whole family (its count in the comment), never
one picture's; the values were measured from the games' archives with the
comparison tools and are kept here as numbers: red, green, blue (0-1), luma
standard deviation, mean saturation."""

"""(red, green, blue, spread, saturation) for each family of each game."""
glob FAMILY_TONES: dict[str, dict[str, list[float]]] = {
    "q1": {
        "blank": [0.324, 0.294, 0.276, 0.300, 0.016],
        "brick": [0.176, 0.127, 0.074, 0.045, 0.017],
        "button": [0.198, 0.111, 0.079, 0.071, 0.034],
        "crate": [0.216, 0.143, 0.085, 0.053, 0.019],
        "door": [0.211, 0.137, 0.081, 0.051, 0.016],
        "flesh": [0.151, 0.093, 0.049, 0.060, 0.019],
        "glass": [0.211, 0.144, 0.088, 0.090, 0.036],
        "grass": [0.184, 0.148, 0.059, 0.053, 0.022],
        "ground": [0.257, 0.159, 0.092, 0.059, 0.021],
        "light": [0.245, 0.191, 0.102, 0.196, 0.037],
        "metal": [0.158, 0.123, 0.086, 0.041, 0.017],
        "rock": [0.176, 0.118, 0.072, 0.059, 0.019],
        "rune": [0.165, 0.117, 0.084, 0.067, 0.025],
        "stone": [0.198, 0.142, 0.093, 0.052, 0.020],
        "tech": [0.253, 0.165, 0.100, 0.066, 0.017],
        "tile": [0.238, 0.180, 0.096, 0.046, 0.016],
        "wood": [0.251, 0.160, 0.085, 0.046, 0.016]
    },
    "q2": {
        "blank": [0.600, 0.214, 0.000, 0.122, 0.107],
        "brick": [0.156, 0.119, 0.094, 0.050, 0.016],
        "button": [0.130, 0.089, 0.066, 0.053, 0.036],
        "crate": [0.215, 0.148, 0.095, 0.047, 0.016],
        "door": [0.140, 0.109, 0.083, 0.044, 0.017],
        "flesh": [0.230, 0.087, 0.061, 0.038, 0.017],
        "glass": [0.215, 0.159, 0.177, 0.034, 0.019],
        "grass": [0.168, 0.150, 0.096, 0.036, 0.013],
        "grate": [0.153, 0.131, 0.110, 0.069, 0.017],
        "ground": [0.143, 0.107, 0.078, 0.024, 0.015],
        "lava": [0.492, 0.111, 0.026, 0.111, 0.061],
        "light": [0.214, 0.168, 0.133, 0.118, 0.018],
        "metal": [0.163, 0.127, 0.093, 0.039, 0.015],
        "rock": [0.171, 0.139, 0.095, 0.043, 0.014],
        "rune": [0.142, 0.081, 0.054, 0.045, 0.034],
        "skin": [0.116, 0.083, 0.061, 0.088, 0.019],
        "sky": [0.969, 0.783, 0.339, 0.196, 0.129],
        "stone": [0.155, 0.122, 0.094, 0.048, 0.015],
        "tech": [0.149, 0.111, 0.084, 0.064, 0.022],
        "trim": [0.126, 0.121, 0.115, 0.029, 0.009],
        "water": [0.179, 0.153, 0.125, 0.039, 0.016]
    },
    "q3": {
        "blank": [0.126, 0.112, 0.119, 0.032, 0.003],
        "brick": [0.266, 0.192, 0.174, 0.089, 0.013],
        "crate": [0.493, 0.336, 0.283, 0.167, 0.051],
        "door": [0.275, 0.236, 0.208, 0.087, 0.011],
        "flesh": [0.413, 0.290, 0.276, 0.120, 0.018],
        "glass": [0.363, 0.297, 0.235, 0.094, 0.013],
        "grate": [0.205, 0.197, 0.159, 0.074, 0.012],
        "ground": [0.218, 0.219, 0.173, 0.088, 0.007],
        "lava": [0.499, 0.205, 0.049, 0.099, 0.043],
        "light": [0.371, 0.307, 0.281, 0.123, 0.021],
        "metal": [0.289, 0.238, 0.216, 0.068, 0.010],
        "rock": [0.272, 0.216, 0.173, 0.075, 0.013],
        "rune": [0.213, 0.180, 0.168, 0.087, 0.021],
        "skin": [0.314, 0.197, 0.195, 0.144, 0.045],
        "stone": [0.281, 0.226, 0.197, 0.081, 0.012],
        "tech": [0.250, 0.209, 0.174, 0.114, 0.011],
        "teleport": [0.744, 0.739, 0.953, 0.091, 0.031],
        "trim": [0.261, 0.224, 0.203, 0.079, 0.010],
        "wood": [0.239, 0.178, 0.148, 0.125, 0.019]
    }
};

"""The tone a family of `game` is graded to; [] when the game's own
pictures of that family were too few to say."""
def family_tone(game: str, family: str) -> list[float] {
    return FAMILY_TONES.get(game, {}).get(family, []);
}

"""Quake III's added pictures, as medians of the game's own: (mean luma,
mean saturation) of those on walls (lamps' glows, screens; 186) and of its
effects (sprites, weapon hits, flares; 156)."""
glob GLOW_TONES: dict[str, list[float]] = {"wall": [0.057, 0.023], "effect": [0.088, 0.032]};
