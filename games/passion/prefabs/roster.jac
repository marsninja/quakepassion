"""The foes and supplies the hand-made prefabs cast, by game: what each
original's stretches fill their rooms with."""
import from ..random { Stream }

"""A foe of Quake's by weights over its kinds (a kind left out weighs
nothing): `weights` maps a monster's classname to its weight. When none
weighs anything, a grunt."""
def q1_foe(dice: Stream, weights: dict[str, float]) -> str {
    kinds: list[str] = [kind for kind in weights.keys() if weights[kind] > 0.0];
    if not kinds {
        return "monster_army";
    }
    return kinds[dice.weighted([weights[kind] for kind in kinds])];
}

"""The weights of a palette of Quake's foes for a stretch's danger (0 to
1): `light` kinds always, `heavy` ones growing with the danger."""
def q1_palette(light: list[str], heavy: list[str], danger: float) -> dict[str, float] {
    found: dict[str, float] = {};
    for kind in light {
        found[kind] = found.get(kind, 0.0) + 3.0;
    }
    for kind in heavy {
        found[kind] = found.get(kind, 0.0) + 0.5 + 3.0 * danger;
    }
    return found;
}

"""Quake II's supplies by what they restore: health, the ammunition its
foes' weapons want, armor."""
glob Q2_HEALTH: str = "item_health_large",
     Q2_AMMO: list[str] = ["ammo_shells", "ammo_bullets", "ammo_grenades", "ammo_rockets", "ammo_cells"],
     Q2_ARMOR: str = "item_armor_jacket";

"""Quake II's foes, light and heavy, by a stretch's danger (0 to 1): its
soldiers and infantry first, gunners and berserkers growing with the
danger (the weights of `q1_palette`, for Quake II's kinds)."""
def q2_foe(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
    if flying {
        return "monster_flyer";
    }
    light = ["monster_infantry", "monster_gunner"] if heavy else ["monster_soldier_light", "monster_soldier", "monster_infantry"];
    strong = ["monster_gladiator", "monster_berserk"] if heavy else ["monster_gunner", "monster_soldier_ss"];
    return q1_foe(dice, q1_palette(light, strong, danger));
}
