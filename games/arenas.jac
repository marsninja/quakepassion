"""Q3's single-player arena ladder and bot roster, read from scripts/arenas.txt
and scripts/bots.txt exactly as the original UI and game module did."""
import os;
import from engine.assets.library { AssetLibrary }

obj ArenaInfo {
    has map: str,
        longname: str = "",
        bots: list[str] = [],
        fraglimit: int = 20,
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
                fraglimit=int(block.get("fraglimit", "20")),
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
    return parse_arenas(library.read("scripts/arenas.txt").decode("utf-8", errors="replace"));
}

def load_bots(library: AssetLibrary) -> list[BotInfo] {
    return parse_bots(library.read("scripts/bots.txt").decode("utf-8", errors="replace"));
}

"""Completed ladder arenas and their best finishing place, kept beside settings."""
obj ArenaProgress {
    has best: dict[str, int] = {};

    def path() -> str {
        return os.getenv("HOME", ".") + "/.quakepassion-arena.txt";
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
