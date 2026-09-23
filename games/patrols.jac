"""Idle walking speeds, summed from each monster's ai_walk frame distances in
the original walk cycles (units per second at 10 Hz)."""

def patrol_speed(game: str, kind: str) -> float {
    speeds: dict[str, float] = {
        "q1:monster_army": 18.0,
        "q1:monster_dog": 80.0,
        "q1:monster_demon1": 71.0,
        "q1:monster_enforcer": 25.0,
        "q1:monster_fish": 80.0,
        "q1:monster_hell_knight": 20.0,
        "q1:monster_knight": 31.0,
        "q1:monster_ogre": 27.0,
        "q1:monster_ogre_marksman": 27.0,
        "q1:monster_shalrath": 29.0,
        "q1:monster_shambler": 82.0,
        "q1:monster_wizard": 80.0,
        "q1:monster_zombie": 10.0,
        "q2:monster_soldier": 25.0,
        "q2:monster_soldier_light": 25.0,
        "q2:monster_soldier_ss": 25.0,
        "q2:monster_infantry": 45.0,
        "q2:monster_gunner": 43.0,
        "q2:monster_berserk": 61.0,
        "q2:monster_medic": 92.0,
        "q2:monster_mutant": 75.0,
        "q2:monster_chick": 75.0,
        "q2:monster_brain": 20.0,
        "q2:monster_parasite": 30.0,
        "q2:monster_tank": 40.0,
        "q2:monster_tank_commander": 40.0,
        "q2:monster_flyer": 50.0,
        "q2:monster_floater": 50.0,
        "q2:monster_hover": 50.0,
        "q2:misc_insane": 30.0
    };
    key = game + ":" + kind;
    return speeds[key] if key in speeds else 0.0;
}
