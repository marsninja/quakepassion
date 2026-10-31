"""The library of hand-made prefabs: every original's stretches, each by
the original it was drawn from, its name, and the part it plays in a
level:

- `start`: holds the level's start;
- `flow`: a stretch passed through, a way in and a way on;
- `hub`: a stretch with ways on enough for a branch to leave it too;
- `keyroom`: holds a key (silver or gold, as asked), the end of a branch;
- `end`: holds the way out;
- `gate`: holds the way out behind a door that wants a key.

Each original's module says its stretches and makes them by name."""
import from ..prefab { Prefab }
import from .e1m1 { E1M1_STRETCHES, make_e1m1 }
import from .e1m2 { E1M2_STRETCHES, make_e1m2 }
import from .e1m3 { E1M3_STRETCHES, make_e1m3 }
import from .e1m4 { E1M4_STRETCHES, make_e1m4 }
import from .e1m5 { E1M5_STRETCHES, make_e1m5 }
import from .e1m6 { E1M6_STRETCHES, make_e1m6 }
import from .e1m7 { E1M7_STRETCHES, make_e1m7 }
import from .e1m8 { E1M8_STRETCHES, make_e1m8 }
import from .e2m1 { E2M1_STRETCHES, make_e2m1 }
import from .e2m2 { E2M2_STRETCHES, make_e2m2 }
import from .e2m3 { E2M3_STRETCHES, make_e2m3 }
import from .e2m4 { E2M4_STRETCHES, make_e2m4 }
import from .e2m5 { E2M5_STRETCHES, make_e2m5 }
import from .e2m6 { E2M6_STRETCHES, make_e2m6 }
import from .e2m7 { E2M7_STRETCHES, make_e2m7 }
import from .e3m1 { E3M1_STRETCHES, make_e3m1 }
import from .e3m2 { E3M2_STRETCHES, make_e3m2 }
import from .e3m3 { E3M3_STRETCHES, make_e3m3 }
import from .e3m4 { E3M4_STRETCHES, make_e3m4 }
import from .e3m5 { E3M5_STRETCHES, make_e3m5 }
import from .e3m6 { E3M6_STRETCHES, make_e3m6 }
import from .e3m7 { E3M7_STRETCHES, make_e3m7 }
import from .e4m1 { E4M1_STRETCHES, make_e4m1 }
import from .e4m2 { E4M2_STRETCHES, make_e4m2 }
import from .e4m3 { E4M3_STRETCHES, make_e4m3 }
import from .e4m4 { E4M4_STRETCHES, make_e4m4 }
import from .e4m5 { E4M5_STRETCHES, make_e4m5 }
import from .e4m6 { E4M6_STRETCHES, make_e4m6 }
import from .e4m7 { E4M7_STRETCHES, make_e4m7 }
import from .e4m8 { E4M8_STRETCHES, make_e4m8 }
import from .end { END_STRETCHES, make_end }
import from .base1 { BASE1_STRETCHES, make_base1 }
import from .base2 { BASE2_STRETCHES, make_base2 }
import from .base3 { BASE3_STRETCHES, make_base3 }
import from .train { TRAIN_STRETCHES, make_train }
import from .bunk1 { BUNK1_STRETCHES, make_bunk1 }
import from .ware1 { WARE1_STRETCHES, make_ware1 }
import from .ware2 { WARE2_STRETCHES, make_ware2 }
import from .jail1 { JAIL1_STRETCHES, make_jail1 }
import from .jail2 { JAIL2_STRETCHES, make_jail2 }
import from .jail3 { JAIL3_STRETCHES, make_jail3 }
import from .jail4 { JAIL4_STRETCHES, make_jail4 }
import from .jail5 { JAIL5_STRETCHES, make_jail5 }
import from .security { SECURITY_STRETCHES, make_security }
import from .mintro { MINTRO_STRETCHES, make_mintro }
import from .mine1 { MINE1_STRETCHES, make_mine1 }
import from .mine2 { MINE2_STRETCHES, make_mine2 }
import from .mine3 { MINE3_STRETCHES, make_mine3 }
import from .mine4 { MINE4_STRETCHES, make_mine4 }
import from .fact1 { FACT1_STRETCHES, make_fact1 }
import from .fact2 { FACT2_STRETCHES, make_fact2 }
import from .fact3 { FACT3_STRETCHES, make_fact3 }
import from .power1 { POWER1_STRETCHES, make_power1 }
import from .power2 { POWER2_STRETCHES, make_power2 }
import from .cool1 { COOL1_STRETCHES, make_cool1 }
import from .waste1 { WASTE1_STRETCHES, make_waste1 }
import from .waste2 { WASTE2_STRETCHES, make_waste2 }
import from .waste3 { WASTE3_STRETCHES, make_waste3 }
import from .biggun { BIGGUN_STRETCHES, make_biggun }
import from .hangar1 { HANGAR1_STRETCHES, make_hangar1 }
import from .hangar2 { HANGAR2_STRETCHES, make_hangar2 }
import from .lab { LAB_STRETCHES, make_lab }
import from .command { COMMAND_STRETCHES, make_command }
import from .strike { STRIKE_STRETCHES, make_strike }
import from .space { SPACE_STRETCHES, make_space }
import from .city1 { CITY1_STRETCHES, make_city1 }
import from .city2 { CITY2_STRETCHES, make_city2 }
import from .city3 { CITY3_STRETCHES, make_city3 }
import from .boss1 { BOSS1_STRETCHES, make_boss1 }
import from .boss2 { BOSS2_STRETCHES, make_boss2 }
import from .q3dm0 { Q3DM0_STRETCHES, make_q3dm0 }
import from .q3dm1 { Q3DM1_STRETCHES, make_q3dm1 }
import from .q3dm2 { Q3DM2_STRETCHES, make_q3dm2 }
import from .q3dm3 { Q3DM3_STRETCHES, make_q3dm3 }
import from .q3dm4 { Q3DM4_STRETCHES, make_q3dm4 }
import from .q3dm5 { Q3DM5_STRETCHES, make_q3dm5 }
import from .q3dm6 { Q3DM6_STRETCHES, make_q3dm6 }
import from .q3dm7 { Q3DM7_STRETCHES, make_q3dm7 }
import from .q3dm8 { Q3DM8_STRETCHES, make_q3dm8 }
import from .q3dm9 { Q3DM9_STRETCHES, make_q3dm9 }
import from .q3dm10 { Q3DM10_STRETCHES, make_q3dm10 }
import from .q3dm11 { Q3DM11_STRETCHES, make_q3dm11 }
import from .q3dm12 { Q3DM12_STRETCHES, make_q3dm12 }
import from .q3dm13 { Q3DM13_STRETCHES, make_q3dm13 }
import from .q3dm14 { Q3DM14_STRETCHES, make_q3dm14 }
import from .q3dm15 { Q3DM15_STRETCHES, make_q3dm15 }
import from .q3dm16 { Q3DM16_STRETCHES, make_q3dm16 }
import from .q3dm17 { Q3DM17_STRETCHES, make_q3dm17 }
import from .q3dm18 { Q3DM18_STRETCHES, make_q3dm18 }
import from .q3dm19 { Q3DM19_STRETCHES, make_q3dm19 }
import from .q3tourney1 { Q3TOURNEY1_STRETCHES, make_q3tourney1 }
import from .q3tourney2 { Q3TOURNEY2_STRETCHES, make_q3tourney2 }
import from .q3tourney3 { Q3TOURNEY3_STRETCHES, make_q3tourney3 }
import from .q3tourney4 { Q3TOURNEY4_STRETCHES, make_q3tourney4 }
import from .q3tourney5 { Q3TOURNEY5_STRETCHES, make_q3tourney5 }
import from .q3tourney6 { Q3TOURNEY6_STRETCHES, make_q3tourney6 }

"""The families of originals a level is made of, each a set that belongs
together (an episode, a unit, a run of arenas of one kind), so that one level
holds together and the next differs from it."""
glob FAMILIES: list[list[str]] = [
         ["e1m1", "e1m2", "e1m3", "e1m4", "e1m5", "e1m6", "e1m7", "e1m8"],
         ["e2m1", "e2m2", "e2m3", "e2m4", "e2m5", "e2m6", "e2m7"],
         ["e3m1", "e3m2", "e3m3", "e3m4", "e3m5", "e3m6", "e3m7"],
         ["e4m1", "e4m2", "e4m3", "e4m4", "e4m5", "e4m6", "e4m7", "e4m8", "end"],
         ["base1", "base2", "base3"],
         ["bunk1", "ware1", "ware2"],
         ["jail1", "jail2", "jail3", "jail4", "jail5", "security"],
         ["mintro", "mine1", "mine2", "mine3", "mine4"],
         ["fact1", "fact2", "fact3", "power1", "power2", "biggun"],
         ["hangar1", "hangar2", "lab", "command", "strike", "space"],
         ["city1", "city2", "city3", "boss1", "boss2"],
         ["cool1", "waste1", "waste2", "waste3"],
         ["q3dm1", "q3dm2", "q3dm3", "q3dm4", "q3dm5", "q3dm6", "q3dm7", "q3dm8"],
         ["q3dm0", "q3dm9", "q3dm10", "q3dm11", "q3dm12", "q3dm13", "q3dm14", "q3dm15", "q3dm16"],
         ["q3dm17", "q3dm18", "q3dm19", "q3tourney1", "q3tourney2", "q3tourney3", "q3tourney4", "q3tourney5", "q3tourney6"]
     ];

"""The library's stretches, [original, name, role] each."""
def library_stretches -> list[list[str]] {
    found: list[list[str]] = [];
    for row in E1M1_STRETCHES {
        found.append(["e1m1", row[0], row[1]]);
    }
    for row in E1M2_STRETCHES {
        found.append(["e1m2", row[0], row[1]]);
    }
    for row in E1M3_STRETCHES {
        found.append(["e1m3", row[0], row[1]]);
    }
    for row in E1M4_STRETCHES {
        found.append(["e1m4", row[0], row[1]]);
    }
    for row in E1M5_STRETCHES {
        found.append(["e1m5", row[0], row[1]]);
    }
    for row in E1M6_STRETCHES {
        found.append(["e1m6", row[0], row[1]]);
    }
    for row in E1M7_STRETCHES {
        found.append(["e1m7", row[0], row[1]]);
    }
    for row in E1M8_STRETCHES {
        found.append(["e1m8", row[0], row[1]]);
    }
    for row in E2M1_STRETCHES {
        found.append(["e2m1", row[0], row[1]]);
    }
    for row in E2M2_STRETCHES {
        found.append(["e2m2", row[0], row[1]]);
    }
    for row in E2M3_STRETCHES {
        found.append(["e2m3", row[0], row[1]]);
    }
    for row in E2M4_STRETCHES {
        found.append(["e2m4", row[0], row[1]]);
    }
    for row in E2M5_STRETCHES {
        found.append(["e2m5", row[0], row[1]]);
    }
    for row in E2M6_STRETCHES {
        found.append(["e2m6", row[0], row[1]]);
    }
    for row in E2M7_STRETCHES {
        found.append(["e2m7", row[0], row[1]]);
    }
    for row in E3M1_STRETCHES {
        found.append(["e3m1", row[0], row[1]]);
    }
    for row in E3M2_STRETCHES {
        found.append(["e3m2", row[0], row[1]]);
    }
    for row in E3M3_STRETCHES {
        found.append(["e3m3", row[0], row[1]]);
    }
    for row in E3M4_STRETCHES {
        found.append(["e3m4", row[0], row[1]]);
    }
    for row in E3M5_STRETCHES {
        found.append(["e3m5", row[0], row[1]]);
    }
    for row in E3M6_STRETCHES {
        found.append(["e3m6", row[0], row[1]]);
    }
    for row in E3M7_STRETCHES {
        found.append(["e3m7", row[0], row[1]]);
    }
    for row in E4M1_STRETCHES {
        found.append(["e4m1", row[0], row[1]]);
    }
    for row in E4M2_STRETCHES {
        found.append(["e4m2", row[0], row[1]]);
    }
    for row in E4M3_STRETCHES {
        found.append(["e4m3", row[0], row[1]]);
    }
    for row in E4M4_STRETCHES {
        found.append(["e4m4", row[0], row[1]]);
    }
    for row in E4M5_STRETCHES {
        found.append(["e4m5", row[0], row[1]]);
    }
    for row in E4M6_STRETCHES {
        found.append(["e4m6", row[0], row[1]]);
    }
    for row in E4M7_STRETCHES {
        found.append(["e4m7", row[0], row[1]]);
    }
    for row in E4M8_STRETCHES {
        found.append(["e4m8", row[0], row[1]]);
    }
    for row in END_STRETCHES {
        found.append(["end", row[0], row[1]]);
    }
    for row in BASE1_STRETCHES {
        found.append(["base1", row[0], row[1]]);
    }
    for row in BASE2_STRETCHES {
        found.append(["base2", row[0], row[1]]);
    }
    for row in BASE3_STRETCHES {
        found.append(["base3", row[0], row[1]]);
    }
    for row in TRAIN_STRETCHES {
        found.append(["train", row[0], row[1]]);
    }
    for row in BUNK1_STRETCHES {
        found.append(["bunk1", row[0], row[1]]);
    }
    for row in WARE1_STRETCHES {
        found.append(["ware1", row[0], row[1]]);
    }
    for row in WARE2_STRETCHES {
        found.append(["ware2", row[0], row[1]]);
    }
    for row in JAIL1_STRETCHES {
        found.append(["jail1", row[0], row[1]]);
    }
    for row in JAIL2_STRETCHES {
        found.append(["jail2", row[0], row[1]]);
    }
    for row in JAIL3_STRETCHES {
        found.append(["jail3", row[0], row[1]]);
    }
    for row in JAIL4_STRETCHES {
        found.append(["jail4", row[0], row[1]]);
    }
    for row in JAIL5_STRETCHES {
        found.append(["jail5", row[0], row[1]]);
    }
    for row in SECURITY_STRETCHES {
        found.append(["security", row[0], row[1]]);
    }
    for row in MINTRO_STRETCHES {
        found.append(["mintro", row[0], row[1]]);
    }
    for row in MINE1_STRETCHES {
        found.append(["mine1", row[0], row[1]]);
    }
    for row in MINE2_STRETCHES {
        found.append(["mine2", row[0], row[1]]);
    }
    for row in MINE3_STRETCHES {
        found.append(["mine3", row[0], row[1]]);
    }
    for row in MINE4_STRETCHES {
        found.append(["mine4", row[0], row[1]]);
    }
    for row in FACT1_STRETCHES {
        found.append(["fact1", row[0], row[1]]);
    }
    for row in FACT2_STRETCHES {
        found.append(["fact2", row[0], row[1]]);
    }
    for row in FACT3_STRETCHES {
        found.append(["fact3", row[0], row[1]]);
    }
    for row in POWER1_STRETCHES {
        found.append(["power1", row[0], row[1]]);
    }
    for row in POWER2_STRETCHES {
        found.append(["power2", row[0], row[1]]);
    }
    for row in COOL1_STRETCHES {
        found.append(["cool1", row[0], row[1]]);
    }
    for row in WASTE1_STRETCHES {
        found.append(["waste1", row[0], row[1]]);
    }
    for row in WASTE2_STRETCHES {
        found.append(["waste2", row[0], row[1]]);
    }
    for row in WASTE3_STRETCHES {
        found.append(["waste3", row[0], row[1]]);
    }
    for row in BIGGUN_STRETCHES {
        found.append(["biggun", row[0], row[1]]);
    }
    for row in HANGAR1_STRETCHES {
        found.append(["hangar1", row[0], row[1]]);
    }
    for row in HANGAR2_STRETCHES {
        found.append(["hangar2", row[0], row[1]]);
    }
    for row in LAB_STRETCHES {
        found.append(["lab", row[0], row[1]]);
    }
    for row in COMMAND_STRETCHES {
        found.append(["command", row[0], row[1]]);
    }
    for row in STRIKE_STRETCHES {
        found.append(["strike", row[0], row[1]]);
    }
    for row in SPACE_STRETCHES {
        found.append(["space", row[0], row[1]]);
    }
    for row in CITY1_STRETCHES {
        found.append(["city1", row[0], row[1]]);
    }
    for row in CITY2_STRETCHES {
        found.append(["city2", row[0], row[1]]);
    }
    for row in CITY3_STRETCHES {
        found.append(["city3", row[0], row[1]]);
    }
    for row in BOSS1_STRETCHES {
        found.append(["boss1", row[0], row[1]]);
    }
    for row in BOSS2_STRETCHES {
        found.append(["boss2", row[0], row[1]]);
    }
    for row in Q3DM0_STRETCHES {
        found.append(["q3dm0", row[0], row[1]]);
    }
    for row in Q3DM1_STRETCHES {
        found.append(["q3dm1", row[0], row[1]]);
    }
    for row in Q3DM2_STRETCHES {
        found.append(["q3dm2", row[0], row[1]]);
    }
    for row in Q3DM3_STRETCHES {
        found.append(["q3dm3", row[0], row[1]]);
    }
    for row in Q3DM4_STRETCHES {
        found.append(["q3dm4", row[0], row[1]]);
    }
    for row in Q3DM5_STRETCHES {
        found.append(["q3dm5", row[0], row[1]]);
    }
    for row in Q3DM6_STRETCHES {
        found.append(["q3dm6", row[0], row[1]]);
    }
    for row in Q3DM7_STRETCHES {
        found.append(["q3dm7", row[0], row[1]]);
    }
    for row in Q3DM8_STRETCHES {
        found.append(["q3dm8", row[0], row[1]]);
    }
    for row in Q3DM9_STRETCHES {
        found.append(["q3dm9", row[0], row[1]]);
    }
    for row in Q3DM10_STRETCHES {
        found.append(["q3dm10", row[0], row[1]]);
    }
    for row in Q3DM11_STRETCHES {
        found.append(["q3dm11", row[0], row[1]]);
    }
    for row in Q3DM12_STRETCHES {
        found.append(["q3dm12", row[0], row[1]]);
    }
    for row in Q3DM13_STRETCHES {
        found.append(["q3dm13", row[0], row[1]]);
    }
    for row in Q3DM14_STRETCHES {
        found.append(["q3dm14", row[0], row[1]]);
    }
    for row in Q3DM15_STRETCHES {
        found.append(["q3dm15", row[0], row[1]]);
    }
    for row in Q3DM16_STRETCHES {
        found.append(["q3dm16", row[0], row[1]]);
    }
    for row in Q3DM17_STRETCHES {
        found.append(["q3dm17", row[0], row[1]]);
    }
    for row in Q3DM18_STRETCHES {
        found.append(["q3dm18", row[0], row[1]]);
    }
    for row in Q3DM19_STRETCHES {
        found.append(["q3dm19", row[0], row[1]]);
    }
    for row in Q3TOURNEY1_STRETCHES {
        found.append(["q3tourney1", row[0], row[1]]);
    }
    for row in Q3TOURNEY2_STRETCHES {
        found.append(["q3tourney2", row[0], row[1]]);
    }
    for row in Q3TOURNEY3_STRETCHES {
        found.append(["q3tourney3", row[0], row[1]]);
    }
    for row in Q3TOURNEY4_STRETCHES {
        found.append(["q3tourney4", row[0], row[1]]);
    }
    for row in Q3TOURNEY5_STRETCHES {
        found.append(["q3tourney5", row[0], row[1]]);
    }
    for row in Q3TOURNEY6_STRETCHES {
        found.append(["q3tourney6", row[0], row[1]]);
    }
    return found;
}

"""Make a stretch of an original by its name; `key` the key a key room
holds or a gate wants."""
def make_stretch(source: str, name: str, key: str = "") -> Prefab {
    if source == "e1m2" {
        return make_e1m2(name, key);
    }
    if source == "e1m3" {
        return make_e1m3(name, key);
    }
    if source == "e1m4" {
        return make_e1m4(name, key);
    }
    if source == "e1m5" {
        return make_e1m5(name, key);
    }
    if source == "e1m6" {
        return make_e1m6(name, key);
    }
    if source == "e1m7" {
        return make_e1m7(name, key);
    }
    if source == "e1m8" {
        return make_e1m8(name, key);
    }
    if source == "e2m1" {
        return make_e2m1(name, key);
    }
    if source == "e2m2" {
        return make_e2m2(name, key);
    }
    if source == "e2m3" {
        return make_e2m3(name, key);
    }
    if source == "e2m4" {
        return make_e2m4(name, key);
    }
    if source == "e2m5" {
        return make_e2m5(name, key);
    }
    if source == "e2m6" {
        return make_e2m6(name, key);
    }
    if source == "e2m7" {
        return make_e2m7(name, key);
    }
    if source == "e3m1" {
        return make_e3m1(name, key);
    }
    if source == "e3m2" {
        return make_e3m2(name, key);
    }
    if source == "e3m3" {
        return make_e3m3(name, key);
    }
    if source == "e3m4" {
        return make_e3m4(name, key);
    }
    if source == "e3m5" {
        return make_e3m5(name, key);
    }
    if source == "e3m6" {
        return make_e3m6(name, key);
    }
    if source == "e3m7" {
        return make_e3m7(name, key);
    }
    if source == "e4m1" {
        return make_e4m1(name, key);
    }
    if source == "e4m2" {
        return make_e4m2(name, key);
    }
    if source == "e4m3" {
        return make_e4m3(name, key);
    }
    if source == "e4m4" {
        return make_e4m4(name, key);
    }
    if source == "e4m5" {
        return make_e4m5(name, key);
    }
    if source == "e4m6" {
        return make_e4m6(name, key);
    }
    if source == "e4m7" {
        return make_e4m7(name, key);
    }
    if source == "e4m8" {
        return make_e4m8(name, key);
    }
    if source == "end" {
        return make_end(name, key);
    }
    if source == "base1" {
        return make_base1(name, key);
    }
    if source == "base2" {
        return make_base2(name, key);
    }
    if source == "base3" {
        return make_base3(name, key);
    }
    if source == "train" {
        return make_train(name, key);
    }
    if source == "bunk1" {
        return make_bunk1(name, key);
    }
    if source == "ware1" {
        return make_ware1(name, key);
    }
    if source == "ware2" {
        return make_ware2(name, key);
    }
    if source == "jail1" {
        return make_jail1(name, key);
    }
    if source == "jail2" {
        return make_jail2(name, key);
    }
    if source == "jail3" {
        return make_jail3(name, key);
    }
    if source == "jail4" {
        return make_jail4(name, key);
    }
    if source == "jail5" {
        return make_jail5(name, key);
    }
    if source == "security" {
        return make_security(name, key);
    }
    if source == "mintro" {
        return make_mintro(name, key);
    }
    if source == "mine1" {
        return make_mine1(name, key);
    }
    if source == "mine2" {
        return make_mine2(name, key);
    }
    if source == "mine3" {
        return make_mine3(name, key);
    }
    if source == "mine4" {
        return make_mine4(name, key);
    }
    if source == "fact1" {
        return make_fact1(name, key);
    }
    if source == "fact2" {
        return make_fact2(name, key);
    }
    if source == "fact3" {
        return make_fact3(name, key);
    }
    if source == "power1" {
        return make_power1(name, key);
    }
    if source == "power2" {
        return make_power2(name, key);
    }
    if source == "cool1" {
        return make_cool1(name, key);
    }
    if source == "waste1" {
        return make_waste1(name, key);
    }
    if source == "waste2" {
        return make_waste2(name, key);
    }
    if source == "waste3" {
        return make_waste3(name, key);
    }
    if source == "biggun" {
        return make_biggun(name, key);
    }
    if source == "hangar1" {
        return make_hangar1(name, key);
    }
    if source == "hangar2" {
        return make_hangar2(name, key);
    }
    if source == "lab" {
        return make_lab(name, key);
    }
    if source == "command" {
        return make_command(name, key);
    }
    if source == "strike" {
        return make_strike(name, key);
    }
    if source == "space" {
        return make_space(name, key);
    }
    if source == "city1" {
        return make_city1(name, key);
    }
    if source == "city2" {
        return make_city2(name, key);
    }
    if source == "city3" {
        return make_city3(name, key);
    }
    if source == "boss1" {
        return make_boss1(name, key);
    }
    if source == "boss2" {
        return make_boss2(name, key);
    }
    if source == "q3dm0" {
        return make_q3dm0(name, key);
    }
    if source == "q3dm1" {
        return make_q3dm1(name, key);
    }
    if source == "q3dm2" {
        return make_q3dm2(name, key);
    }
    if source == "q3dm3" {
        return make_q3dm3(name, key);
    }
    if source == "q3dm4" {
        return make_q3dm4(name, key);
    }
    if source == "q3dm5" {
        return make_q3dm5(name, key);
    }
    if source == "q3dm6" {
        return make_q3dm6(name, key);
    }
    if source == "q3dm7" {
        return make_q3dm7(name, key);
    }
    if source == "q3dm8" {
        return make_q3dm8(name, key);
    }
    if source == "q3dm9" {
        return make_q3dm9(name, key);
    }
    if source == "q3dm10" {
        return make_q3dm10(name, key);
    }
    if source == "q3dm11" {
        return make_q3dm11(name, key);
    }
    if source == "q3dm12" {
        return make_q3dm12(name, key);
    }
    if source == "q3dm13" {
        return make_q3dm13(name, key);
    }
    if source == "q3dm14" {
        return make_q3dm14(name, key);
    }
    if source == "q3dm15" {
        return make_q3dm15(name, key);
    }
    if source == "q3dm16" {
        return make_q3dm16(name, key);
    }
    if source == "q3dm17" {
        return make_q3dm17(name, key);
    }
    if source == "q3dm18" {
        return make_q3dm18(name, key);
    }
    if source == "q3dm19" {
        return make_q3dm19(name, key);
    }
    if source == "q3tourney1" {
        return make_q3tourney1(name, key);
    }
    if source == "q3tourney2" {
        return make_q3tourney2(name, key);
    }
    if source == "q3tourney3" {
        return make_q3tourney3(name, key);
    }
    if source == "q3tourney4" {
        return make_q3tourney4(name, key);
    }
    if source == "q3tourney5" {
        return make_q3tourney5(name, key);
    }
    if source == "q3tourney6" {
        return make_q3tourney6(name, key);
    }
    return make_e1m1(name, key);
}
