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
        # p_weapon.c Weapon_Generic: FRAME_ACTIVATE_LAST, FRAME_FIRE_LAST,
        # FRAME_IDLE_LAST and FRAME_DEACTIVATE_LAST. Weapon_Grenade has no
        # activate or deactivate frames.
        ranges = [
            (4, 8, 52, 55),
            (7, 18, 36, 39),
            (6, 17, 57, 61),
            (3, 5, 45, 49),
            (4, 31, 61, 64),
            (5, 16, 59, 64),
            (4, 12, 50, 54),
            (5, 20, 49, 53),
            (3, 18, 56, 61),
            (8, 32, 55, 58),
            (0, 15, 48, 48)
        ];
        for i in range(len(names)) {
            limits = ranges[i];
            switching = limits[3] > limits[2];
            result.append(
                ViewWeaponRule(
                    slot=i + 1,
                    model="models/weapons/v_" + names[i] + "/tris.md2",
                    fire_first=limits[0] + 1,
                    fire_last=limits[1],
                    idle_first=limits[1] + 1,
                    idle_last=limits[2],
                    lower_first=limits[2] + 1 if switching else -1,
                    lower_last=limits[3] if switching else -1,
                    raise_first=0 if switching else -1,
                    raise_last=limits[0] if switching else -1
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
                    fire_last=6,
                    # CG_MapTorsoToWeaponFrame: the hand's frames 6-14 follow
                    # the torso's 20 fps TORSO_DROP (5) and TORSO_RAISE (4).
                    lower_first=6,
                    lower_last=10,
                    raise_first=11,
                    raise_last=14,
                    switch_rate=20.0
                )
            );
        }
    }
    return result;
}
