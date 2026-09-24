"""Weapon descriptions shared by game rules, pickups and combat simulation."""
obj WeaponRule {
    has slot: int,
        key: str,
        name: str,
        ammo: str = "",
        capacity: int = 0,
        pickup_ammo: int = 0,
        cost: int = 1,
        damage: int = 10,
        kick: int = -1,
        interval: float = 0.1,
        pellets: int = 1,
        spread: float = 0.0,
        vertical_spread: float = 0.0,
        reach: float = 8192.0,
        speed: float = 0.0,
        splash: int = 0,
        radius: float = 0.0,
        beam_damage: int = 0,
        beam_radius: float = 0.0,
        burst_damage: int = 0,
        burst_radius: float = 0.0,
        gravity: bool = False,
        fuse: float = 5.0,
        piercing: bool = False,
        model: str = "",
        effect: str = "",
        hand_thrown: bool = False,
        avoid_underwater: bool = False,
        circular: bool = False,
        punch: float = 0.0,
        punch_time: float = 0.0,
        raise_time: float = 0.0,
        lower_time: float = 0.0;
}

obj ViewWeaponRule {
    has slot: int,
        model: str,
        hand: str = "",
        fire_first: int = 0,
        fire_last: int = -1,
        idle_first: int = 0,
        idle_last: int = 0;
}

"""Sample cosmetic frames from simulation time without advancing weapon logic."""
def view_frame(
    rule: ViewWeaponRule,
    count: int,
    fired: float,
    idle: float,
    hand_grenade: bool = False,
    grenade_phase: int = 0,
    grenade_clock: float = 0.0
) -> int {
    last = rule.fire_last if rule.fire_last >= 0 else count - 1;
    frame = rule.idle_first;
    if rule.idle_last > rule.idle_first {
        frame += int(max(0.0, idle) * 10.0) % (rule.idle_last - rule.idle_first + 1);
    }
    if hand_grenade {
        if grenade_phase == 1 {
            frame = max(1, min(10, 1 + int((1.0 - grenade_clock) * 10.0)));
        } elif grenade_phase == 2 {
            frame = 11;
        } elif grenade_phase == 3 {
            frame = 12;
        } elif fired >= 0.0 and fired < 0.4 {
            frame = min(15, 12 + int(fired * 10.0));
        }
    } elif fired >= 0.0 and fired < float(last - rule.fire_first + 1) * 0.1 {
        frame = rule.fire_first + int(fired * 10.0);
    }
    return max(0, min(count - 1, frame));
}
