"""Content packs: the games and what was published on top of them.

A game's data is a stack of folders. Quake is `id1`; Scourge of Armagon is
`hipnotic` laid over `id1`, as the original engines' `-game hipnotic` searched
the mission pack before the base game; Dimension of the Machine is `mg1` over
the 2021 re-release's `id1` over the original. Each pack is a node, an `Over`
edge joins it to the pack beneath it, and a walker that climbs those edges
reads off the folders to search, base first.

A pack names the game whose formats and rules its maps use (`game`: q1, q2 or
q3), so a mission pack is that game with more in it, not a fifth game. Free
games made for those engines are packs with nothing beneath them: LibreQuake
plays by Quake's rules on its own data, OpenArena by Quake III's. The folders
hang off one assets root, laid out as the Steam installs lay them out:

    id1/  baseq2/  baseq3/           the three games
    quake/hipnotic  quake/rogue      Quake's mission packs
    quake/rerelease/<folder>         the 2021 re-release's id1, dopa, mg1, mg3, ctf
    quake2/xatrix  quake2/rogue  quake2/ctf
    quake3/missionpack
    librequake/id1                   LibreQuake
    openarena/baseoa                 OpenArena

Everything that opens archives takes a search path: the folders joined by
`;`, later ones over earlier ones. A lone folder is a search path of one.
"""

import os;

"""Joins a search path's folders."""
glob PATH_SEPARATOR: str = ";";

edge Stocks: Shelf --> ContentPack {}
edge Over: ContentPack --> ContentPack {}

"""One published body of maps and assets. `folder` is relative to the assets
root; `order` places it in its game's list."""
node ContentPack {
    has id: str,
        game: str,
        title: str,
        folder: str,
        order: int = 0;
}

"""A pack and the packs beneath it, base first."""
walker Layers {
    has packs: list[ContentPack] = [];

    can climb with ContentPack entry {
        self.packs.insert(0, here);
        visit [here->:Over:->];
    }
}

"""The pack an id names."""
walker FindPack {
    has id: str,
        found: ContentPack | None = None;

    can start with Shelf entry {
        visit [here->:Stocks:->];
    }

    can check with ContentPack entry {
        if here.id == self.id {
            self.found = here;
            disengage;
        }
    }
}

"""A game's packs."""
walker GamePacks {
    has game: str,
        packs: list[ContentPack] = [];

    can start with Shelf entry {
        visit [here->:Stocks:->];
    }

    can check with ContentPack entry {
        if here.game == self.game {
            self.packs.append(here);
        }
    }
}

"""Every pack QuakePassion knows."""
node Shelf {
    has stocked: int = 0;

    """Stock a pack, over the pack `base` names when it has one."""
    def stock(id: str, game: str, title: str, folder: str, base: str = "") -> ContentPack {
        pack = ContentPack(id=id, game=game, title=title, folder=folder, order=self.stocked);
        self.stocked += 1;
        self +>:Stocks:+> pack;
        if base {
            beneath = self.find(base);
            if beneath is not None {
                pack +>:Over:+> beneath;
            }
        }
        return pack;
    }

    def find(id: str) -> ContentPack | None {
        search = self spawn FindPack(id=id);
        return search.found;
    }

    """A game's packs in the order they were stocked."""
    def packs(game: str) -> list[ContentPack] {
        listed = self spawn GamePacks(game=game);
        ordered: list[ContentPack] = [];
        for pack in listed.packs {
            at = len(ordered);
            while at > 0 and ordered[at - 1].order > pack.order {
                at -= 1;
            }
            ordered.insert(at, pack);
        }
        return ordered;
    }
}

"""What is stocked and what is being played: the shelf, once built, and the
pack each game is playing (by game, a pack id)."""
obj ContentState {
    has shelf: Shelf | None = None,
        playing: dict[str, str] = {},
        # The folders someone has set for their packs (by pack id, and "root"
        # for the folder they are all under), once read.
        folders: dict[str, str] = {},
        folders_read: bool = False;
}

glob _content: ContentState = ContentState();

"""The shelf, stocked on first use."""
def shelf() -> Shelf {
    known = _content.shelf;
    if known is not None {
        return known;
    }
    made = Shelf();
    made.stock("q1", "q1", "Quake", "id1");
    made.stock("librequake", "q1", "LibreQuake", "librequake/id1");
    made.stock("hipnotic", "q1", "Scourge of Armagon", "quake/hipnotic", "q1");
    made.stock("rogue", "q1", "Dissolution of Eternity", "quake/rogue", "q1");
    made.stock("q1r", "q1", "Quake (2021 re-release)", "quake/rerelease/id1", "q1");
    made.stock("dopa", "q1", "Dimension of the Past", "quake/rerelease/dopa", "q1r");
    made.stock("mg1", "q1", "Dimension of the Machine", "quake/rerelease/mg1", "q1r");
    made.stock("mg3", "q1", "The Thirtieth Passing (mg3)", "quake/rerelease/mg3", "q1r");
    made.stock("q1ctf", "q1", "Threewave CTF", "quake/rerelease/ctf", "q1r");
    made.stock("q2", "q2", "Quake II", "baseq2");
    made.stock("xatrix", "q2", "The Reckoning", "quake2/xatrix", "q2");
    made.stock("groundzero", "q2", "Ground Zero", "quake2/rogue", "q2");
    made.stock("q2ctf", "q2", "Capture the Flag", "quake2/ctf", "q2");
    made.stock("q3", "q3", "Quake III Arena", "baseq3");
    made.stock("openarena", "q3", "OpenArena", "openarena/baseoa");
    made.stock("teamarena", "q3", "Team Arena", "quake3/missionpack", "q3");
    _content.shelf = made;
    return made;
}

"""The file that keeps the folders someone has set for their games, beside
the settings."""
def folders_path() -> str {
    configured = os.getenv("QP_CONFIG_DIR", "");
    return (configured if configured else os.path.expanduser("~")) + "/.quakepassion-folders.txt";
}

"""The folders such a file's text names: a line is a pack's id (or `root`,
for the folder every pack is under) and then its folder, which may have
spaces in it. A line that begins with # says nothing."""
def read_folders(text: str) -> dict[str, str] {
    found: dict[str, str] = {};
    for raw in text.replace("\r", "").split("\n") {
        line = raw.strip();
        cut = line.find(" ");
        if line.startswith("#") or cut <= 0 {
            continue;
        }
        folder = line[cut + 1:].strip();
        if folder {
            found[line[:cut]] = folder;
        }
    }
    return found;
}

"""The text of such a file."""
def folders_text(folders: dict[str, str]) -> str {
    lines = ["# QuakePassion: where each game's files are (ed_game <game> dir <folder>)"];
    for id in sorted(folders.keys()) {
        lines.append(id + " " + folders[id]);
    }
    return "\n".join(lines) + "\n";
}

"""The folders set, read from their file on first use."""
def set_folders() -> dict[str, str] {
    if not _content.folders_read {
        _content.folders_read = True;
        try {
            with open(folders_path(), "r") as file {
                _content.folders = read_folders(file.read());
            }
        } except OSError {
            _content.folders = {};
        }
    }
    return _content.folders;
}

"""Set a pack's folder (or the root's), or with no folder give it up, and
keep it. What is opened from then on is looked for there. False when the
file could not be written."""
def keep_folder(id: str, folder: str) -> bool {
    folders = set_folders();
    if folder {
        folders[id] = folder;
    } else {
        folders.pop(id, None);
    }
    try {
        with open(folders_path(), "w") as file {
            file.write(folders_text(folders));
        }
    } except OSError {
        return False;
    }
    return True;
}

"""The folder every pack's folder is under. QP_ASSETS names the base folder
of the game QP_GAME selects (for Passion, the root itself), so the root is
that folder's parent; without it, the root someone has set, or
~/quake-assets."""
def assets_root() -> str {
    configured = os.getenv("QP_ASSETS", "");
    if configured == "" {
        chosen = set_folders().get("root", "");
        return chosen if chosen else os.path.expanduser("~") + "/quake-assets";
    }
    if os.getenv("QP_GAME", "q1") == "passion" {
        return configured;
    }
    trimmed = configured.replace("\\", "/").rstrip("/");
    cut = trimmed.rfind("/");
    return trimmed[:cut] if cut > 0 else ".";
}

"""Where a pack's own folder is on disk."""
def pack_folder(pack: ContentPack) -> str {
    configured = os.getenv("QP_ASSETS", "");
    if configured != "" and pack.id == os.getenv("QP_GAME", "q1") {
        return configured;
    }
    chosen = set_folders().get(pack.id, "");
    if chosen {
        return chosen;
    }
    return assets_root() + "/" + pack.folder;
}

"""Whether a pack's folder is there to play from."""
def installed(pack: ContentPack) -> bool {
    return os.path.isdir(pack_folder(pack));
}

"""A pack's search path: its folder and those beneath it, base first."""
def pack_path(pack: ContentPack) -> str {
    layers = pack spawn Layers();
    return PATH_SEPARATOR.join([pack_folder(layer) for layer in layers.packs]);
}

"""A game's installed packs, the game itself first."""
def game_packs(game: str) -> list[ContentPack] {
    return [pack for pack in shelf().packs(game) if installed(pack)];
}

"""Whether a pack plays on its own data, with no pack beneath it: a game,
or a free game made for its engine."""
def stands_alone(pack: ContentPack) -> bool {
    layers = pack spawn Layers();
    return len(layers.packs) == 1;
}

"""The pack a game is playing: the game itself until another is chosen. When
the game's own data is not there, the first installed pack that stands alone
(LibreQuake for Quake, OpenArena for Quake III)."""
def playing(game: str) -> ContentPack | None {
    stocked = shelf();
    chosen = stocked.find(_content.playing.get(game, ""));
    if chosen is not None {
        return chosen;
    }
    itself = stocked.find(game);
    if itself is not None and not installed(itself) {
        for pack in game_packs(game) {
            if stands_alone(pack) {
                return pack;
            }
        }
    }
    return itself;
}

"""Play a pack: its game's maps and assets now come from its search path.
Returns the game whose rules it plays by, or "" for an unknown pack."""
def play_pack(id: str) -> str {
    pack = shelf().find(id);
    if pack is None {
        return "";
    }
    _content.playing[pack.game] = pack.id;
    return pack.game;
}

"""The map a pack opens on. Quake's packs each have a `start` (LibreQuake's
too); the others' first maps are their campaigns' own, OpenArena's the first
arena of its ladder."""
def pack_start_map(id: str) -> str {
    starts = {
        "xatrix": "xswamp",
        "groundzero": "rmine1",
        "q2ctf": "q2ctf1",
        "teamarena": "mpteam1",
        "openarena": "oa_rpg3dm2",
        "q1ctf": "ctf1",
        "q2": "base1",
        "q3": "q3dm1",
        "q1": "e1m1"
    };
    return starts.get(id, "start");
}

"""The search path of what a game is playing. Passion draws on all three
games, so its path is the assets root."""
def game_directory(game: str) -> str {
    if game == "passion" {
        return assets_root();
    }
    pack = playing(game);
    if pack is None {
        return assets_root() + "/" + game;
    }
    return pack_path(pack);
}

"""The folders of a search path, base first."""
def search_folders(path: str) -> list[str] {
    return [folder for folder in path.split(PATH_SEPARATOR) if folder != ""];
}

"""The archives of a search path with `extension` (".pak", ".pk3"), in the
order they are opened: folder by folder, each folder's by name, so that a
later archive's files replace an earlier one's. A folder that is missing has
none."""
def archive_paths(path: str, extension: str) -> list[str] {
    found: list[str] = [];
    for folder in search_folders(path) {
        if not os.path.isdir(folder) {
            continue;
        }
        for filename in sorted(os.listdir(folder)) {
            if filename.lower().endswith(extension) {
                found.append(folder + "/" + filename);
            }
        }
    }
    return found;
}

"""A file lying loose in a search path's folders, the topmost first; "" when
there is none."""
def loose_file(path: str, name: str) -> str {
    if not path or not name or name.startswith("/") or ".." in name {
        return "";
    }
    folders = search_folders(path);
    for i in range(len(folders)) {
        candidate = folders[len(folders) - 1 - i] + "/" + name.replace("\\", "/");
        if os.path.exists(candidate) {
            return candidate;
        }
    }
    return "";
}
