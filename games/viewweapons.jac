"""Original first-person asset and animation ranges, independent of damage rules."""
import from engine.world.weapons { ViewWeaponRule }
import from .weapons { weapon_rules }

def view_weapons(game: str) -> list[ViewWeaponRule] {
    result: list[ViewWeaponRule] = [];
    if game == "q1" {
        # player.qc's weaponframes: the axe swings through 1-4 (player_axe,
        # player_axec) or 5-8 (player_axeb, player_axed), W_Attack choosing
        # one of the four at random; the shotguns (player_shot) and the
        # launchers (player_rocket) run 1-6; the nailguns (player_nail) cycle
        # 1-8 and the thunderbolt (player_light) 1-4 while the trigger holds,
        # player_run putting the weapon back to frame 0 once it is let go.
        names = ["axe", "shot", "shot2", "nail", "nail2", "rock", "rock2", "light"];
        lasts = [4, 6, 6, 8, 8, 6, 6, 4];
        for i in range(len(names)) {
            looping = names[i] in ["nail", "nail2", "light"];
            result.append(
                ViewWeaponRule(
                    slot=i + 1,
                    model="progs/v_" + names[i] + ".mdl",
                    fire_first=1,
                    fire_last=lasts[i],
                    loop_first=1 if looping else -1,
                    loop_last=lasts[i] if looping else -1,
                    release_idle=looping,
                    swings=[0, 4, 0, 4] if names[i] == "axe" else []
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
        # Each weapon's pause_frames; one on FRAME_IDLE_LAST never holds, as
        # Weapon_Generic wraps to FRAME_IDLE_FIRST first. Weapon_Grenade
        # pauses on 48 before wrapping.
        pauses = [
            [19, 32],
            [22, 28, 34],
            [29, 42],
            [23],
            [38, 43, 51],
            [34, 51],
            [25, 33, 42],
            [],
            [],
            [39, 45, 50],
            [29, 34, 39, 48]
        ];
        for i in range(len(names)) {
            limits = ranges[i];
            switching = limits[3] > limits[2];
            rule = ViewWeaponRule(
                slot=i + 1,
                model="models/weapons/v_" + names[i] + "/tris.md2",
                # A shot shows FRAME_FIRE_FIRST + 1: the fire function steps
                # past the frame it fired on.
                fire_first=limits[0] + 2,
                fire_last=limits[1],
                idle_first=limits[1] + 1,
                idle_last=limits[2],
                pause_frames=pauses[i],
                blend_frames=True,
                lower_first=limits[2] + 1 if switching else -1,
                lower_last=limits[3] if switching else -1,
                raise_first=0 if switching else -1,
                raise_last=limits[0] if switching else -1
            );
            if names[i] == "machn" {
                # Machinegun_Fire alternates 4 and 5 while the trigger holds.
                rule.loop_first = 4;
                rule.loop_last = 5;
            } elif names[i] == "chain" {
                # Chaingun_Fire spins up to 21, then cycles 15-21; let go, it
                # jumps from 14 to idle or winds down through 22-31.
                rule.loop_first = 15;
                rule.loop_last = 21;
                rule.release_skip = 14;
            } elif names[i] == "hyperb" {
                # Weapon_HyperBlaster_Fire goes back from 12 to 6.
                rule.loop_first = 6;
                rule.loop_last = 11;
            }
            result.append(rule);
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
                    switch_rate=20.0,
                    blend_frames=True
                )
            );
        }
    }
    return result;
}
