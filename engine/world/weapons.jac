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

"""A first-person weapon's model and animation. Frames step ten a second,
as Q1's player think functions set weaponframe and Q2's Weapon_Generic steps
ps.gunframe each server frame. `fire_first` is the first frame shown after a
shot (Q2 fires on FRAME_FIRE_FIRST and the fire function steps past it in the
same frame), `fire_last` the last before the idle frames. While the trigger
holds, a continuous weapon cycles `loop_first` to `loop_last` instead of
running on (Q1 player_nail and player_light, Q2 Machinegun_Fire, Chaingun_Fire
and Weapon_HyperBlaster_Fire); let go, Q1's goes straight back to its idle
frame (player_run), Q2's runs on to its idle frames, the chaingun skipping
from `release_skip` to them. `swings` offsets alternate attacks, one taken per
shot (Q1 W_Attack's four axe swings). The idle frames loop, holding at each of
`pause_frames` fifteen steps in sixteen (Q2's rand()&15 fidget pauses).
`blend_frames` draws each frame blended from the last over its tenth of a
second, as Q2's client lerps gun frames and Q3's hand follows the torso. A
shot kicks the Q2 view (kick_origin, kick_angles) `kick_back` units against
the aim, up to `kick_shake` units each way and `kick_twist` degrees
([pitch, yaw, roll]) at random."""
obj ViewWeaponRule {
    has slot: int,
        model: str,
        hand: str = "",
        fire_first: int = 0,
        fire_last: int = -1,
        idle_first: int = 0,
        idle_last: int = 0,
        loop_first: int = -1,
        loop_last: int = -1,
        release_idle: bool = False,
        release_skip: int = -1,
        swings: list[int] = [],
        pause_frames: list[int] = [],
        blend_frames: bool = False,
        kick_back: float = 0.0,
        kick_shake: float = 0.0,
        kick_twist: list[float] = [];
    # The switch: frames played while the weapon lowers and while it rises,
    # at `switch_rate` frames a second (-1 for none).
    has lower_first: int = -1,
        lower_last: int = -1,
        raise_first: int = -1,
        raise_last: int = -1,
        switch_rate: float = 10.0;
}

"""The frame of a weapon `elapsed` seconds into lowering (or raising), or -1
when it has no such frames: Q2 Weapon_Generic's WEAPON_DROPPING and
WEAPON_ACTIVATING frames, Q3 CG_MapTorsoToWeaponFrame's hand frames for
TORSO_DROP and TORSO_RAISE."""
def switch_frame(rule: ViewWeaponRule, count: int, lowering: bool, elapsed: float) -> int {
    first = rule.lower_first if lowering else rule.raise_first;
    last = rule.lower_last if lowering else rule.raise_last;
    if first < 0 or last < first {
        return -1;
    }
    frame = first + int(max(0.0, elapsed) * rule.switch_rate);
    return max(0, min(count - 1, min(last, frame)));
}

"""Q2 Weapon_Grenade's frames while a hand grenade is cooked and thrown:
priming 1-10 over the second before it is live, 11 held, 12 let go, then
the throw to 15 over `thrown` seconds; -1 once it is back to idling."""
def grenade_frame(phase: int, clock: float, thrown: float) -> int {
    if phase == 1 {
        return max(1, min(10, 1 + int((1.0 - clock) * 10.0)));
    }
    if phase == 2 {
        return 11;
    }
    if phase == 3 {
        return 12;
    }
    if thrown >= 0.0 and thrown < 0.4 {
        return min(15, 12 + int(thrown * 10.0));
    }
    return -1;
}

glob GUN_FRAME_TIME: float = 0.1;

"""A first-person weapon's running animation (ViewWeaponRule): the frame
shown, the one before it and when it was stepped to. Cosmetic: it follows
the combat state's shots and trigger and never changes them."""
obj GunAnimation {
    has frame: int = 0,
        previous: int = 0,
        stepped_at: float = 0.0,
        firing: bool = False,
        swing: int = 0,
        last_shot: float = -100.0,
        dice: int = 1;

    """Readied at `seconds` (a switch finished, a level loaded): idling from
    the first idle frame."""
    def ready(rule: ViewWeaponRule, seconds: float) {
        self.frame = rule.idle_first;
        self.previous = rule.idle_first;
        self.stepped_at = seconds;
        self.firing = False;
        self.swing = 0;
    }

    """A shot at `seconds`. A continuous weapon already cycling keeps its
    cycle; anything else starts its firing frames, the axe on a swing chosen
    at random (a cosmetic stream, not the game's)."""
    def shot(rule: ViewWeaponRule, seconds: float) {
        self.last_shot = seconds;
        if self.firing and rule.loop_first >= 0 {
            return;
        }
        self.swing = 0;
        if rule.swings {
            self.dice = (self.dice * 48271) % 2147483647;
            self.swing = rule.swings[self.dice % len(rule.swings)];
        }
        self.previous = self.frame;
        self.frame = rule.fire_first + self.swing;
        self.stepped_at = seconds;
        self.firing = True;
    }

    """Step to `seconds`, a frame each tenth of a second; `held` is whether
    the trigger is held."""
    def advance(rule: ViewWeaponRule, seconds: float, held: bool) {
        # Still shooting: a continuous weapon fires every step it cycles.
        cycling = held and seconds - self.last_shot <= GUN_FRAME_TIME * 1.5;
        steps = 0;
        while seconds - self.stepped_at >= GUN_FRAME_TIME - 0.000001 and steps < 100 {
            self.stepped_at += GUN_FRAME_TIME;
            self.previous = self.frame;
            self.frame = self.next_frame(rule, cycling);
            steps += 1;
        }
        if steps >= 100 {
            self.stepped_at = seconds;
        }
    }

    def next_frame(rule: ViewWeaponRule, cycling: bool) -> int {
        frame = self.frame;
        if self.firing {
            if rule.loop_first >= 0 {
                if cycling {
                    frame += 1;
                    return rule.loop_first if frame > rule.loop_last else frame;
                }
                if rule.release_idle or frame == rule.release_skip {
                    self.firing = False;
                    return rule.idle_first;
                }
            }
            if frame < rule.fire_last + self.swing {
                return frame + 1;
            }
            self.firing = False;
            return rule.idle_first;
        }
        if frame in rule.pause_frames {
            self.dice = (self.dice * 48271) % 2147483647;
            if (self.dice & 15) != 0 {
                return frame;
            }
        }
        if frame >= rule.idle_last or frame < rule.idle_first {
            return rule.idle_first;
        }
        return frame + 1;
    }

    """How far the shown frame has come from the one before, for weapons
    that blend them (else all the way)."""
    def share(rule: ViewWeaponRule, seconds: float) -> float {
        if not rule.blend_frames {
            return 1.0;
        }
        return max(0.0, min(1.0, (seconds - self.stepped_at) / GUN_FRAME_TIME));
    }
}
