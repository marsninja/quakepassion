"""Original first-person asset and animation ranges, independent of damage rules."""
import from engine.world.weapons { ViewWeaponRule }
import from .weapons { weapon_rules }

def view_weapons(game: str) -> list[ViewWeaponRule] {
    result: list[ViewWeaponRule] = [];
    if game == "q1" {
        names = ["axe", "shot", "shot2", "nail", "nail2", "rock", "rock2", "light"];
        for i in range(len(names)) {
            result.append(
                ViewWeaponRule(
                    slot=i + 1, model="progs/v_" + names[i] + ".mdl", fire_first=1
                )
            );
        }
    } elif game == "q2" {
        names = [
            "blast",
            "shotg",
            "shotg2",
            "machn",
            "chain",
            "launch",
            "rocket",
            "hyperb",
            "rail",
            "bfg",
            "handgr"
        ];
        ranges = [
            (4, 8, 52),
            (7, 18, 36),
            (6, 17, 57),
            (3, 5, 45),
            (4, 31, 61),
            (5, 16, 59),
            (4, 12, 50),
            (5, 20, 49),
            (3, 18, 56),
            (8, 32, 55),
            (0, 15, 48)
        ];
        for i in range(len(names)) {
            limits = ranges[i];
            result.append(
                ViewWeaponRule(
                    slot=i + 1,
                    model="models/weapons/v_" + names[i] + "/tris.md2",
                    fire_first=limits[0] + 1,
                    fire_last=limits[1],
                    idle_first=limits[1] + 1,
                    idle_last=limits[2]
                )
            );
        }
    } elif game == "q3" {
        for weapon in weapon_rules(game) {
            model = weapon.model
                if weapon.model
                else "models/weapons2/gauntlet/gauntlet.md3";
            result.append(
                ViewWeaponRule(
                    slot=weapon.slot,
                    model=model,
                    hand=model[:-4] + "_hand.md3",
                    fire_first=1,
                    fire_last=6
                )
            );
        }
    }
    return result;
}
