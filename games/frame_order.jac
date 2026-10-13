"""Quake's standard frame order: each monster model's frames by number, as
QuakeC's `$frame` lines name them and compile them to numbers (`$pain1` is a
frame number in progs.dat, not a name the engine looks up). A rule names its
frames; a model that keeps Quake's frames in Quake's order under names of
its own (LibreQuake's are `frame1`, `frame2`, ...) is animated by number, as
Quake animates every model. `name4..9` stands for name4, name5, ... name9."""

glob QUAKE_FRAME_ORDER: dict[str, str] = {
    "progs/boss.mdl": "rise1..17 walk1..31 death1..9 attack1..23 shocka1..10 shockb1..6 "
        + "shockc1..10",
    "progs/demon.mdl": "stand1..13 walk1..8 run1..6 leap1..12 pain1..6 death1..9 attacka1..15",
    "progs/dog.mdl": "attack1..8 death1..9 deathb1..9 pain1..6 painb1..16 run1..12 leap1..9 "
        + "stand1..9 walk1..8",
    "progs/enforcer.mdl": "stand1..7 walk1..16 run1..8 attack1..10 death1..14 fdeath1..11 paina1..4 "
        + "painb1..5 painc1..8 paind1..19",
    "progs/fish.mdl": "attack1..18 death1..21 swim1..18 pain1..9",
    "progs/hknight.mdl": "stand1..9 walk1..20 run1..8 pain1..5 death1..12 deathb1..9 char_a1..16 "
        + "magica1..14 magicb1..13 char_b1..6 slice1..10 smash1..11 w_attack1..22 "
        + "magicc1..11",
    "progs/knight.mdl": "stand1..9 runb1..8 runattack1..11 pain1..3 painb1..11 attackb1 "
        + "attackb1..10 walk1..14 kneel1..5 standing2..5 death1..10 deathb1..11",
    "progs/ogre.mdl": "stand1..9 walk1..16 run1..8 swing1..14 smash1..14 shoot1..6 pain1..5 "
        + "painb1..3 painc1..6 paind1..16 paine1..15 death1..14 bdeath1..10 "
        + "pull1..11",
    "progs/oldone.mdl": "old1..46 shake1..12 shake12..20",
    "progs/player.mdl": "axrun1..6 rockrun1..6 stand1..5 axstnd1..12 axpain1..6 pain1..6 "
        + "axdeth1..9 deatha1..11 deathb1..9 deathc1..15 deathd1..9 deathe1..9 "
        + "nailatt1 nailatt2 light1 light2 rockatt1..6 shotatt1..6 axatt1..6 "
        + "axattb1..6 axattc1..6 axattd1..6",
    "progs/shalrath.mdl": "attack1..11 pain1..5 death1..7 walk1..12",
    "progs/shambler.mdl": "stand1..17 walk1..12 run1..6 smash1..12 swingr1..9 swingl1..9 magic1..12 "
        + "pain1..6 death1..11",
    "progs/soldier.mdl": "stand1..8 death1..10 deathc1..11 load1..11 pain1..6 painb1..14 "
        + "painc1..13 run1..8 shoot1..9 prowl_1..24",
    "progs/tarbaby.mdl": "walk1..25 run1..25 jump1..6 fly1..4 exp",
    "progs/wizard.mdl": "hover1..15 fly1..14 magatt1..13 pain1..4 death1..8",
    "progs/zombie.mdl": "stand1..15 walk1..19 run1..18 atta1..13 attb1..14 attc1..12 paina1..12 "
        + "painb1..28 painc1..18 paind1..13 paine1..30 cruc_1..6"
};

"""A run of frame names written with `..` ranges, one name a frame."""
def expand_frames(text: str) -> list[str] {
    names: list[str] = [];
    for word in text.split() {
        cut = word.find("..");
        if cut < 0 {
            names.append(word);
            continue;
        }
        head = word[:cut];
        digits = len(head);
        while digits > 0 and head[digits - 1].isdigit() {
            digits -= 1;
        }
        for number in range(int(head[digits:]), int(word[cut + 2:]) + 1) {
            names.append(head[:digits] + str(number));
        }
    }
    return names;
}

"""A model's frames in Quake's standard order, when Quake's own model at that
path has `count` frames; none otherwise."""
def standard_frames(path: str, count: int) -> list[str] {
    text = QUAKE_FRAME_ORDER.get(path, "");
    if not text {
        return [];
    }
    names = expand_frames(text);
    return names if len(names) == count else [];
}
