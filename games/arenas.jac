"""Q3's single-player arena ladder and bot roster, read from scripts/arenas.txt
and scripts/bots.txt exactly as the original UI and game module did."""
import os;
import from engine.assets.library { AssetLibrary }

obj ArenaInfo {
    has map: str,
        longname: str = "",
        bots: list[str] = [],
        fraglimit: int = 20,
        timelimit: int = 0,
        types: list[str] = [],
        special: str = "";
}

obj BotInfo {
    has name: str,
        model: str = "sarge",
        skin: str = "default",
        aifile: str = "",
        arena_lord: bool = False;
}

"""Brace-delimited `key value` blocks. Values may be quoted; `//` comments end a line."""
def info_blocks(text: str) -> list[dict[str, str]] {
    blocks: list[dict[str, str]] = [];
    current: dict[str, str] | None = None;
    for raw in text.splitlines() {
        line = raw.split("//")[0].strip();
        if not line {
            continue;
        }
        if line == "{" {
            current = {};
            continue;
        }
        if line == "}" {
            if current is not None {
                blocks.append(current);
            }
            current = None;
            continue;
        }
        if current is None {
            continue;
        }
        parts = line.replace("\t", " ").split(" ", 1);
        if len(parts) != 2 {
            continue;
        }
        value = parts[1].strip();
        if len(value) >= 2 and value[0] == "\"" and value[-1] == "\"" {
            value = value[1:-1];
        }
        current[parts[0].lower()] = value;
    }
    return blocks;
}

"""g_bot.c G_InitBots: the frag limit and the time limit in minutes a
single-player arena is played to, from its `fraglimit` and `timelimit` keys;
a missing key is no limit, and an arena with neither is played to 10 frags."""
def arena_limits(block: dict[str, str]) -> tuple[int, int] {
    frags = int(block.get("fraglimit", "0"));
    minutes = int(block.get("timelimit", "0"));
    if frags == 0 and minutes == 0 {
        return (10, 0);
    }
    return (frags, minutes);
}

def parse_arenas(text: str) -> list[ArenaInfo] {
    arenas: list[ArenaInfo] = [];
    for block in info_blocks(text) {
        if "map" not in block {
            continue;
        }
        arenas.append(
            ArenaInfo(
                map=block["map"].lower(),
                longname=block.get("longname", block["map"]),
                bots=[name.lower() for name in block.get("bots", "").split()],
                fraglimit=arena_limits(block)[0],
                timelimit=arena_limits(block)[1],
                types=block.get("type", "").lower().split(),
                special=block.get("special", "").lower()
            )
        );
    }
    return arenas;
}

def parse_bots(text: str) -> list[BotInfo] {
    bots: list[BotInfo] = [];
    for block in info_blocks(text) {
        if "name" not in block {
            continue;
        }
        parts = block.get("model", "sarge").lower().split("/");
        bots.append(
            BotInfo(
                name=block["name"],
                model=parts[0],
                skin=parts[1] if len(parts) > 1 and parts[1] else "default",
                aifile=block.get("aifile", ""),
                arena_lord=block.get("arenalord", "0") == "1"
            )
        );
    }
    return bots;
}

"""The single-player order: training, then tiers of four, then the final."""
def ladder(arenas: list[ArenaInfo]) -> list[ArenaInfo] {
    training = [arena for arena in arenas if arena.special == "training"];
    final = [arena for arena in arenas if arena.special == "final"];
    tiers = [
        arena
        for arena in arenas
        if "single" in arena.types and arena.special not in ["training", "final"]
    ];
    return training + tiers + final;
}

"""cg_info.c CG_DrawInformation's lines for a local game: the map's message
(the arena's long name), the game type and the frag limit. An arena of the
single-player ladder says "Single Player"; any other map is run free for
all with twenty frags."""
def arena_loading_lines(arena: ArenaInfo | None) -> list[str] {
    if arena is None {
        return ["Free For All", "fraglimit 20"];
    }
    lines: list[str] = [];
    if arena.longname {
        lines.append(arena.longname);
    }
    lines.append("Single Player" if "single" in arena.types else "Free For All");
    if arena.fraglimit > 0 {
        lines.append("fraglimit " + str(arena.fraglimit));
    }
    return lines;
}

def find_arena(arenas: list[ArenaInfo], name: str) -> ArenaInfo | None {
    for arena in arenas {
        if arena.map == name.lower() {
            return arena;
        }
    }
    return None;
}

def find_bot(bots: list[BotInfo], name: str) -> BotInfo {
    for bot in bots {
        if bot.name.lower() == name.lower() {
            return bot;
        }
    }
    return BotInfo(name=name[:1].upper() + name[1:].lower());
}

def load_arenas(library: AssetLibrary) -> list[ArenaInfo] {
    return parse_arenas(library.read("scripts/arenas.txt").decode("utf-8"));
}

def load_bots(library: AssetLibrary) -> list[BotInfo] {
    return parse_bots(library.read("scripts/bots.txt").decode("utf-8"));
}

"""Completed ladder arenas and their best finishing place, kept beside settings."""
obj ArenaProgress {
    has best: dict[str, int] = {};

    def path() -> str {
        return os.path.expanduser("~") + "/.quakepassion-arena.txt";
    }

    def load() {
        self.best = {};
        if not os.path.exists(self.path()) {
            return;
        }
        with open(self.path(), "r") as stream {
            lines = stream.read().splitlines();
        }
        if not lines or lines[0] != "QUAKEPASSION ARENA 1" {
            raise ValueError("Invalid arena progress version");
        }
        for line in lines[1:] {
            parts = line.split();
            if len(parts) == 2 and int(parts[1]) >= 1 {
                self.best[parts[0]] = int(parts[1]);
            }
        }
    }

    def record(name: str, place: int) {
        if name not in self.best or place < self.best[name] {
            self.best[name] = place;
        }
        text = "QUAKEPASSION ARENA 1\n";
        for key in sorted(self.best.keys()) {
            text += key + " " + str(self.best[key]) + "\n";
        }
        with open(self.path() + ".tmp", "w") as stream {
            stream.write(text);
        }
        os.replace(self.path() + ".tmp", self.path());
    }
}

"""The arena after `name` in the single-player order, or "" at the end."""
def next_arena(arenas: list[ArenaInfo], name: str) -> str {
    order = ladder(arenas);
    for index in range(len(order)) {
        if order[index].map == name.lower() and index + 1 < len(order) {
            return order[index + 1].map;
        }
    }
    return "";
}

# ui_local.h: the ladder's tiers are four arenas each.
glob ARENAS_PER_TIER: int = 4;

"""The arenas UI_LoadArenas numbers as the tiers': those of type "single"
without a `special` tag, less any left over from whole tiers."""
def tier_arenas(arenas: list[ArenaInfo]) -> list[ArenaInfo] {
    singles = [arena for arena in arenas if "single" in arena.types and not arena.special];
    return singles[:len(singles) - len(singles) % ARENAS_PER_TIER];
}

"""ui_gameinfo.c UI_TierCompleted for the arena just won, given every
arena's best finish: 0 for the training arena, a tier's number (from 1) once
all four of its arenas have been won, one past the last tier for the final
arena, and -1 when nothing was completed."""
def tier_completed(arenas: list[ArenaInfo], best: dict[str, int], name: str) -> int {
    won = name.lower();
    tiered = tier_arenas(arenas);
    for index in range(len(tiered)) {
        if tiered[index].map == won {
            tier = index // ARENAS_PER_TIER;
            for member in tiered[tier * ARENAS_PER_TIER:(tier + 1) * ARENAS_PER_TIER] {
                if best.get(member.map, 0) != 1 {
                    return -1;
                }
            }
            return tier + 1;
        }
    }
    specials = [arena for arena in arenas if "single" in arena.types and arena.special];
    for arena in specials {
        if arena.map == won {
            if arena.special == "training" {
                return 0;
            }
            finals = [other for other in specials if other.special == "final"];
            if not finals or finals[0].map == won {
                return len(tiered) // ARENAS_PER_TIER + 1;
            }
        }
    }
    return -1;
}

"""UI_SPPostgameMenu_f's lastTier: the tiers, and one more for a final arena."""
def last_tier(arenas: list[ArenaInfo]) -> int {
    tiers = len(tier_arenas(arenas)) // ARENAS_PER_TIER;
    finals = [arena for arena in arenas if "single" in arena.types and arena.special == "final"];
    return tiers + 1 if finals else tiers;
}

"""q_shared.c Info_ValueForKey: a key's value in a `\\key\\value` string."""
def info_value(info: str, key: str) -> str {
    parts = info.split("\\");
    index = 1;
    while index + 1 < len(parts) {
        if parts[index].lower() == key.lower() {
            return parts[index + 1];
        }
        index += 2;
    }
    return "";
}

"""q_shared.c Info_SetValueForKey: the string with `key` set to `value`
(the old pair removed, the new one added at the end)."""
def info_with(info: str, key: str, value: str) -> str {
    parts = info.split("\\");
    kept = "";
    index = 1;
    while index + 1 < len(parts) {
        if parts[index].lower() != key.lower() {
            kept += "\\" + parts[index] + "\\" + parts[index + 1];
        }
        index += 2;
    }
    return kept + "\\" + key + "\\" + value if value else kept;
}

"""UI_SPPostgameMenu_MenuDraw's film for a completed tier, with the command
that follows it (`nextmap`): end.RoQ after the last tier and then nothing,
else the next tier's film (tier1.RoQ after the training arena) and then the
level menu."""
def postgame_film(won: int, last: int) -> tuple[str, str] {
    if won == last {
        return ("end.RoQ", "");
    }
    return ("tier" + str(won + 1) + ".RoQ", "levelselect");
}

"""UI_ShowTierVideo's test: a tier's film is shown once, `videos` being
g_spVideos' record of the ones already seen."""
def tier_video_due(videos: str, tier: int) -> bool {
    if tier <= 0 {
        return False;
    }
    seen = info_value(videos, "tier" + str(tier));
    return not seen or seen == "0";
}

"""ui_gameinfo.c UI_LogAwardData: the award totals kept across matches
(accuracy medals, impressives, excellents, gauntlet frags, frags and
perfects), in ~/.quakepassion-awards.txt."""
obj AwardLog {
    has totals: dict[str, int] = {};

    def path() -> str {
        return os.path.expanduser("~") + "/.quakepassion-awards.txt";
    }

    def load() {
        self.totals = {};
        if not os.path.exists(self.path()) {
            return;
        }
        with open(self.path(), "r") as stream {
            lines = stream.read().splitlines();
        }
        if not lines or lines[0] != "QUAKEPASSION AWARDS 1" {
            raise ValueError("Invalid award log version");
        }
        for line in lines[1:] {
            parts = line.split();
            if len(parts) == 2 and parts[0] in AWARD_KINDS {
                self.totals[parts[0]] = max(0, int(parts[1]));
            }
        }
    }

    """Add `amount` to an award's total (UI_LogAwardData) and save."""
    def log(kind: str, amount: int) {
        self.totals[kind] = self.totals.get(kind, 0) + max(0, amount);
        text = "QUAKEPASSION AWARDS 1\n";
        for key in AWARD_KINDS {
            if key in self.totals {
                text += key + " " + str(self.totals[key]) + "\n";
            }
        }
        with open(self.path() + ".tmp", "w") as stream {
            stream.write(text);
        }
        os.replace(self.path() + ".tmp", self.path());
    }
}

# ui_sppostgame.c's medals in presentation order.
glob AWARD_KINDS: list[str] = ["accuracy", "impressive", "excellent", "gauntlet", "frags", "perfect"];

"""One medal of the postgame presentation: its kind and the number shown
under it (a percentage for accuracy)."""
obj Medal {
    has kind: str,
        amount: int;
}

"""UI_SPPostgameMenu_f's awards from the match: accuracy of 50% or better,
any impressives, excellents and gauntlet frags, a frags medal each time the
career total passes another hundred, and perfect. `career` is the frag
total before this match."""
def postgame_medals(accuracy: int, impressive: int, excellent: int, gauntlet: int, frags: int, perfect: bool, career: int) -> list[Medal] {
    medals: list[Medal] = [];
    if accuracy >= 50 {
        medals.append(Medal(kind="accuracy", amount=accuracy));
    }
    if impressive > 0 {
        medals.append(Medal(kind="impressive", amount=impressive));
    }
    if excellent > 0 {
        medals.append(Medal(kind="excellent", amount=excellent));
    }
    if gauntlet > 0 {
        medals.append(Medal(kind="gauntlet", amount=gauntlet));
    }
    reached = (career + max(0, frags)) // 100;
    if reached > career // 100 {
        medals.append(Medal(kind="frags", amount=reached * 100));
    }
    if perfect {
        medals.append(Medal(kind="perfect", amount=1));
    }
    return medals;
}
