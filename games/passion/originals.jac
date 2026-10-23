"""The original levels Passion takes its essences from: every single-player
level of Quake and Quake II and every arena of Quake III, read from the
player's own game files."""

glob ORIGINALS_Q1: list[str] = [
         "e1m1",
         "e1m2",
         "e1m3",
         "e1m4",
         "e1m5",
         "e1m6",
         "e1m7",
         "e1m8",
         "e2m1",
         "e2m2",
         "e2m3",
         "e2m4",
         "e2m5",
         "e2m6",
         "e2m7",
         "e3m1",
         "e3m2",
         "e3m3",
         "e3m4",
         "e3m5",
         "e3m6",
         "e3m7",
         "e4m1",
         "e4m2",
         "e4m3",
         "e4m4",
         "e4m5",
         "e4m6",
         "e4m7",
         "e4m8",
         "end"
     ];

glob ORIGINALS_Q2: list[str] = [
         "base1",
         "base2",
         "base3",
         "train",
         "bunk1",
         "ware1",
         "ware2",
         "jail1",
         "jail2",
         "jail3",
         "jail4",
         "jail5",
         "security",
         "mintro",
         "mine1",
         "mine2",
         "mine3",
         "mine4",
         "fact1",
         "fact2",
         "fact3",
         "power1",
         "power2",
         "cool1",
         "waste1",
         "waste2",
         "waste3",
         "biggun",
         "hangar1",
         "hangar2",
         "lab",
         "command",
         "strike",
         "space",
         "city1",
         "city2",
         "city3",
         "boss1",
         "boss2"
     ];

glob ORIGINALS_Q3: list[str] = [
         "q3dm0",
         "q3dm1",
         "q3dm2",
         "q3dm3",
         "q3dm4",
         "q3dm5",
         "q3dm6",
         "q3dm7",
         "q3dm8",
         "q3dm9",
         "q3dm10",
         "q3dm11",
         "q3dm12",
         "q3dm13",
         "q3dm14",
         "q3dm15",
         "q3dm16",
         "q3dm17",
         "q3dm18",
         "q3dm19",
         "q3tourney1",
         "q3tourney2",
         "q3tourney3",
         "q3tourney4",
         "q3tourney5",
         "q3tourney6"
     ];

"""Every original, as `game:map`."""
def all_originals() -> list[str] {
    return ["q1:" + name for name in ORIGINALS_Q1] + ["q2:" + name for name in ORIGINALS_Q2] + ["q3:" + name for name in ORIGINALS_Q3];
}

"""The originals of the games named (`q1`, `q2`, `q3`), as `game:map`."""
def originals_of(games: list[str]) -> list[str] {
    return [spec for spec in all_originals() if spec.split(":")[0] in games];
}
