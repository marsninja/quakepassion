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

"""An original's foes as data: its `light` kinds always, its `strong` ones
growing with a stretch's danger (by `scale`), and for a heavy pick kinds and a
scale of their own (`q1_palette`'s weights over them); a flyer, when one is
asked for, is `flying` (or `flying_other` as often as `flying_odds`)."""
obj FoeMix {
    has light: list[str],
        strong: list[str],
        heavy_light: list[str] | None = None,
        heavy_strong: list[str] | None = None,
        scale: float = 1.0,
        heavy_scale: float | None = None,
        flying: str = "",
        flying_other: str = "",
        flying_odds: float = 0.0;

    """A foe by a stretch's danger, heavy or a flyer when asked."""
    def pick(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
        if flying {
            if self.flying_other {
                return self.flying_other if dice.chance(self.flying_odds) else self.flying;
            }
            return self.flying;
        }
        if heavy {
            common = self.heavy_light if self.heavy_light is not None else self.light;
            growing = self.heavy_strong if self.heavy_strong is not None else self.strong;
            return q1_foe(dice, q1_palette(common, growing, danger * (self.heavy_scale if self.heavy_scale is not None else self.scale)));
        }
        return q1_foe(dice, q1_palette(self.light, self.strong, danger * self.scale));
    }

    """`count` foes, the first heavy when `heavy`."""
    def squad(dice: Stream, danger: float, count: int, heavy: bool = False) -> list[str] {
        return [self.pick(dice, danger, heavy and index == 0) for index in range(count)];
    }
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
