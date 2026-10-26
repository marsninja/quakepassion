"""Pause menu and archive-backed map catalogue: a tab for each game, the
content packs installed for it, and the maps of the pack chosen."""
import os;
import time;
import from zipfile { ZipFile }
import from ..assets.pak { open_pak }
import from ..assets.content {
    ContentPack,
    shelf,
    game_packs,
    playing,
    pack_folder,
    archive_paths,
    game_directory as content_directory
}
import from ..formats.bsp { i32_at, require_range, parse_entities }
import from ..formats.q1.bsp { is_q1_bsp }
import from ..render.renderer { Color }
import from ..input.input { IsKeyPressed, IsMouseButtonPressed, GetMouseX, GetMouseY }
import from vendor.raylib {
    def DrawRectangle(x: i32, y: i32, width: i32, height: i32, color: Color) -> None;  def DrawText(
        text: str, x: i32, y: i32, size: i32, color: Color
    ) -> None;  def GetMouseWheelMove -> f32;
}

import from games.arenas { ArenaProgress, parse_arenas, ladder }
import from games.passion.generate { level_name, run_of, level_engine, VERSION, PREFAB_VERSION, HANDMADE_VERSION }
import from ..world.arena { ordinal }

# The settings rows' pitch: all of them above the buttons under the list.
glob SETTING_PITCH: int = 24;

"""The search path of what a game is playing (engine/assets/content.jac)."""
def game_directory(game: str) -> str {
    return content_directory(game);
}

def map_names(names: list[str]) -> list[str] {
    maps: set[str] = set();
    for name in names {
        if name.startswith("maps/") and name.lower().endswith(".bsp") {
            maps.add(name[5:-4]);
        }
    }
    return sorted(maps);
}

"""The map files lying loose in a folder's maps/, named as archives name
them (maps/<name>.bsp)."""
def loose_maps(folder: str) -> list[str] {
    found: list[str] = [];
    within = folder + "/maps";
    if not os.path.isdir(within) {
        return found;
    }
    for filename in sorted(os.listdir(within)) {
        if filename.lower().endswith(".bsp") and os.path.isfile(within + "/" + filename) {
            found.append("maps/" + filename);
        }
    }
    return found;
}

"""A Quake or Quake II map file a pack lists: its name, and the title its
worldspawn gives it. Quake's brush models for items are not levels."""
def note_level(game: str, name: str, data: bytes, names: list[str], titles: dict[str, str]) {
    if game == "q1" and not is_q1_level(data) {
        return;
    }
    names.append(name);
    try {
        titles[name[5:-4]] = map_title(data, game);
    } except ValueError {
        titles[name[5:-4]] = "";
    }
}

"""A map file's entities: Quake's lump table follows its four-byte version,
Quake II's follows its magic and version. Their text is bytes, not UTF-8."""
def map_entity_text(data: bytes, game: str) -> str {
    at = 8 if game == "q2" else 4;
    offset = i32_at(data, at);
    length = i32_at(data, at + 4);
    require_range(data, offset, length);
    return data[offset:offset + length].decode("latin-1");
}

# Quake also stores standalone brush models under maps/*.bsp.
def is_q1_level(data: bytes) -> bool {
    if not is_q1_bsp(data) {
        return False;
    }
    for entity in parse_entities(map_entity_text(data, "q1")) {
        if entity.fields.get("classname", "")
            in ["info_player_start", "info_player_deathmatch"] {
            return True;
        }
    }
    return False;
}

"""The name a map gives itself, its worldspawn's `message`: "" when it has
none, or only a key into the re-release's string tables ($map_...)."""
def map_title(data: bytes, game: str) -> str {
    for entity in parse_entities(map_entity_text(data, game)) {
        if entity.fields.get("classname", "") == "worldspawn" {
            title = entity.fields.get("message", "").replace("\\n", " ").strip();
            return "" if title.startswith("$") else title;
        }
    }
    return "";
}

"""The pause menu: the level list, the settings and the controls (Q1/Q2
Customize Controls). Its 720 by 610 panel is laid out for a 1280 by 720
window and stays centred in the live one."""
obj LevelMenu {
    has opened: bool = False,
        settings_open: bool = False,
        setting_selected: int = 0,
        settings_labels: list[str] = [],
        controls_open: bool = False,
        controls_selected: int = 0,
        controls_offset: int = 0,
        controls_labels: list[str] = [],
        controls_keys: list[str] = [],
        grabbing: bool = False,
        ox: int = 0,
        oy: int = 0,
        restore_mouse: bool = False,
        game: int = 0,
        selected: int = 0,
        offset: int = 0,
        maps: list[str] = [],
        labels: list[str] = [],
        message: str = "",
        seed_cursor: int = 0,
        # Passion's seed as typed, and the characters typed this frame (the
        # app hands them over while the menu is open).
        seed_text: str = "",
        # The engine Passion's run is made by: essences (v4) or prefabs.
        passion_engine: str = "v4",
        typed: list[str] = [],
        games: list[str] = ["q1", "q2", "q3", "passion"],
        # The chosen game's installed packs, and the one whose maps are listed.
        pack: int = 0,
        packs: list[str] = [],
        pack_titles: list[str] = [],
        # A pack's maps and their titles, by pack id, once listed.
        listed_maps: dict[str, list[str]] = {},
        listed_titles: dict[str, list[str]] = {},
        arena_texts: dict[str, str] = {};

    """List the chosen game: its installed packs, and the maps of the one it
    is playing."""
    def scan() {
        self.packs = [];
        self.pack_titles = [];
        self.pack = 0;
        game = self.games[self.game];
        if game != "passion" {
            current = playing(game);
            for pack in game_packs(game) {
                if current is not None and pack.id == current.id {
                    self.pack = len(self.packs);
                }
                self.packs.append(pack.id);
                self.pack_titles.append(pack.title);
            }
        }
        self.list_maps();
    }

    """The id of the pack whose maps are listed; "" for Passion."""
    def chosen_pack() -> str {
        return self.packs[self.pack] if self.pack < len(self.packs) else "";
    }

    """List another of the game's packs."""
    def choose_pack(index: int) {
        if index >= 0 and index < len(self.packs) and index != self.pack {
            self.pack = index;
            self.list_maps();
        }
    }

    """List the chosen pack's own maps: those in its folder, not the ones
    beneath it. Each is named by its file and titled by its worldspawn, with
    a pack's start map first."""
    def list_maps() {
        self.maps = [];
        self.labels = [];
        self.selected = 0;
        self.offset = 0;
        self.message = "";
        game = self.games[self.game];
        if game == "passion" {
            if not self.seed_text {
                self.roll_seed();
            }
            self.choose_seed();
            return;
        }
        pack = shelf().find(self.chosen_pack());
        if pack is None {
            self.message = "No maps found in " + game_directory(game);
            return;
        }
        try {
            if pack.id not in self.listed_maps {
                self.read_pack(pack);
            }
            self.maps = list(self.listed_maps[pack.id]);
            self.labels = list(self.listed_titles[pack.id]);
            if self.arena_texts.get(pack.id, "") {
                self.order_arenas(self.arena_texts[pack.id]);
            }
            if len(self.maps) == 0 {
                self.message = "No maps found in " + pack_folder(pack);
            }
        } except Exception as error {
            self.message = "Cannot list maps: " + str(error);
        }
    }

    """A fresh seed for Passion, from the clock."""
    def roll_seed() {
        seed = max(int(time.time()), self.seed_cursor + 1) % 2147483000 + 1;
        self.seed_cursor = seed;
        self.seed_text = str(seed);
    }

    """The run the typed seed starts: its first level is the one loaded."""
    def choose_seed() {
        self.selected = 0;
        self.offset = 0;
        digits = self.seed_text.lstrip("0");
        seed = int(digits) if digits else 0;
        if seed < 1 or seed > 2147483646 {
            self.maps = [];
            self.labels = [];
            self.message = "A seed is a whole number from 1 to 2147483646";
            return;
        }
        self.maps = [level_name(seed, 1, self.passion_engine)];
        self.labels = list(self.maps);
        self.message = "";
    }

    """The seed of the Passion run a level belongs to, typed in."""
    def show_run(name: str) {
        try {
            self.seed_text = str(run_of(name)[0]);
            self.passion_engine = level_engine(name);
        } except ValueError {
            return;
        }
        self.choose_seed();
    }

    """Read a pack's archives for its maps and their titles."""
    def read_pack(pack: ContentPack) {
        folder = pack_folder(pack);
        names: list[str] = [];
        titles: dict[str, str] = {};
        arena_text = "";
        if pack.game == "q3" {
            for path in archive_paths(folder, ".pk3") {
                with ZipFile(path) as archive {
                    listed = archive.namelist();
                    names.extend(listed);
                    if "scripts/arenas.txt" in listed {
                        arena_text = archive.read("scripts/arenas.txt").decode("latin-1");
                    }
                }
            }
        } else {
            for path in archive_paths(folder, ".pak") {
                pak = open_pak(path);
                for name in pak.names() {
                    if name.startswith("maps/") and name.lower().endswith(".bsp") {
                        note_level(pack.game, name, pak.read_file(name), names, titles);
                    }
                }
            }
            # Map files lying loose beside the paks.
            for name in loose_maps(folder) {
                if name not in names {
                    with open(folder + "/" + name, "rb") as handle {
                        note_level(pack.game, name, handle.read(), names, titles);
                    }
                }
            }
        }
        maps = map_names(names);
        if "start" in maps {
            maps.remove("start");
            maps.insert(0, "start");
        }
        self.listed_maps[pack.id] = maps;
        self.listed_titles[pack.id] = [
            name + ("  " + titles[name] if titles.get(name, "") else "") for name in maps
        ];
        self.arena_texts[pack.id] = arena_text;
    }

    """Q3 lists its single-player ladder first, with names and best finishes."""
    def order_arenas(text: str) {
        progress = ArenaProgress();
        try {
            progress.load();
        } except Exception as error {
            self.message = "Arena progress: " + str(error);
        }
        ordered: list[str] = [];
        labels: list[str] = [];
        for arena in ladder(parse_arenas(text)) {
            if arena.map in self.maps and arena.map not in ordered {
                ordered.append(arena.map);
                place = progress.best.get(arena.map, 0);
                labels.append(
                    arena.map
                        + "  "
                        + arena.longname
                        + ("  [" + ordinal(place) + "]" if place > 0 else "")
                );
            }
        }
        for name in self.maps {
            if name not in ordered {
                ordered.append(name);
                labels.append(name);
            }
        }
        self.maps = ordered;
        self.labels = labels;
    }

    """Where the panel's 1280 by 720 layout sits in a `width` by `height`
    window."""
    def place(width: int, height: int) {
        self.ox = (width - 1280) // 2;
        self.oy = (height - 720) // 2;
    }

    def hit(x: int, y: int, w: int, h: int) -> bool {
        mx = int(GetMouseX()) - self.ox;
        my = int(GetMouseY()) - self.oy;
        return mx >= x and mx < x + w and my >= y and my < y + h;
    }

    """A rectangle in panel coordinates."""
    def box(x: int, y: int, w: int, h: int, color: Color) {
        DrawRectangle(i32(self.ox + x), i32(self.oy + y), i32(w), i32(h), color);
    }

    """Text in panel coordinates."""
    def label(text: str, x: int, y: int, size: int, color: Color) {
        DrawText(text, i32(self.ox + x), i32(self.oy + y), i32(size), color);
    }

    """Open one page: "levels", "settings" or "controls"."""
    def show(page: str) {
        self.settings_open = page == "settings";
        self.controls_open = page == "controls";
        self.grabbing = False;
    }

    # Returns load, quit, a settings or controls action, or an empty string.
    # Escape is handled by the app.
    def update(width: int, height: int) -> str {
        self.place(width, height);
        click = IsMouseButtonPressed(i32(0));
        if self.grabbing {
            return "";
        }
        if click and self.hit(800, 82, 160, 32) {
            self.show("levels" if self.settings_open else "settings");
            return "";
        }
        if click and self.hit(630, 82, 160, 32) {
            self.show("levels" if self.controls_open else "controls");
            return "";
        }
        if self.controls_open {
            return self.update_controls(click);
        }
        if self.settings_open {
            if IsKeyPressed(i32(264)) {
                self.setting_selected = min(
                    len(self.settings_labels) - 1, self.setting_selected + 1
                );
            }
            if IsKeyPressed(i32(265)) {
                self.setting_selected = max(0, self.setting_selected - 1);
            }
            for row in range(len(self.settings_labels)) {
                if click and self.hit(310, 150 + row * SETTING_PITCH, 650, SETTING_PITCH - 2) {
                    self.setting_selected = row;
                    return "setting_left"
                        if self.hit(810, 150 + row * SETTING_PITCH, 65, SETTING_PITCH - 2)
                        else "setting_right";
                }
            }
            if IsKeyPressed(i32(263)) {
                return "setting_left";
            }
            if IsKeyPressed(i32(262)) or IsKeyPressed(i32(257)) {
                return "setting_right";
            }
            if click and self.hit(310, 610, 260, 42) {
                return "settings_reset";
            }
            if click and self.hit(760, 610, 200, 42) {
                return "quit";
            }
            return "";
        }
        for i in range(len(self.games)) {
            if click and self.hit(310 + i * 165, 145, 155, 40) {
                self.game = i;
                self.scan();
            }
        }
        if self.games[self.game] == "passion" {
            return self.update_seed(click);
        }
        for row in range(len(self.packs)) {
            if click and self.hit(750, 205 + row * 30, 210, 28) {
                self.choose_pack(row);
            }
        }
        if IsKeyPressed(i32(262)) {
            self.choose_pack(self.pack + 1);
        }
        if IsKeyPressed(i32(263)) {
            self.choose_pack(self.pack - 1);
        }
        self.offset -= int(GetMouseWheelMove()) * 3;
        if IsKeyPressed(i32(264)) {
            self.selected += 1;
        }
        if IsKeyPressed(i32(265)) {
            self.selected -= 1;
        }
        self.selected = max(0, min(self.selected, len(self.maps) - 1));
        if IsKeyPressed(i32(264)) or IsKeyPressed(i32(265)) {
            if self.selected < self.offset {
                self.offset = self.selected;
            }
            if self.selected >= self.offset + 11 {
                self.offset = self.selected - 10;
            }
        }
        self.offset = max(0, min(self.offset, len(self.maps) - 11));
        for row in range(11) {
            index = self.offset + row;
            if index < len(self.maps)
                and click
                and self.hit(310, 205 + row * 30, 425, 28) {
                self.selected = index;
            }
        }
        if click and self.hit(760, 610, 200, 42) {
            return "quit";
        }
        if len(self.maps) > 0
            and (IsKeyPressed(i32(257)) or (click and self.hit(310, 610, 260, 42))) {
            return "load";
        }
        return "";
    }

    """Passion's page: digits typed into the seed, Backspace taking one
    away, the dice for a fresh one, and Enter (or the button) to start the
    run."""
    def update_seed(click: bool) -> str {
        changed = False;
        for character in self.typed {
            if character.isdigit() and len(self.seed_text) < 10 {
                self.seed_text += character;
                changed = True;
            }
        }
        self.typed = [];
        if IsKeyPressed(i32(259)) and self.seed_text {
            self.seed_text = self.seed_text[:-1];
            changed = True;
        }
        if click and self.hit(560, 260, 160, 44) {
            self.roll_seed();
            changed = True;
        }
        for (column, engine) in enumerate([VERSION, HANDMADE_VERSION, PREFAB_VERSION]) {
            if click and self.hit(380 + column * 195, 322, 185, 40) and self.passion_engine != engine {
                self.passion_engine = engine;
                changed = True;
            }
        }
        if changed {
            self.choose_seed();
        }
        if click and self.hit(760, 610, 200, 42) {
            return "quit";
        }
        if len(self.maps) > 0
            and (IsKeyPressed(i32(257)) or (click and self.hit(310, 610, 260, 42))) {
            return "load";
        }
        return "";
    }

    """M_Keys_Key: Up and Down choose an action, Enter (or a click on the
    chosen one) waits for the key to bind to it, Backspace and Delete clear
    its keys."""
    def update_controls(click: bool) -> str {
        count = len(self.controls_labels);
        if IsKeyPressed(i32(264)) {
            self.controls_selected = min(count - 1, self.controls_selected + 1);
        }
        if IsKeyPressed(i32(265)) {
            self.controls_selected = max(0, self.controls_selected - 1);
        }
        self.controls_offset -= int(GetMouseWheelMove()) * 3;
        if self.controls_selected < self.controls_offset {
            self.controls_offset = self.controls_selected;
        }
        if self.controls_selected >= self.controls_offset + 14 {
            self.controls_offset = self.controls_selected - 13;
        }
        self.controls_offset = max(0, min(self.controls_offset, count - 14));
        for row in range(14) {
            index = self.controls_offset + row;
            if index < count and click and self.hit(310, 150 + row * 30, 650, 28) {
                if index == self.controls_selected {
                    self.grabbing = True;
                    return "";
                }
                self.controls_selected = index;
            }
        }
        if IsKeyPressed(i32(257)) and count > 0 {
            self.grabbing = True;
            return "";
        }
        if IsKeyPressed(i32(259)) or IsKeyPressed(i32(261)) {
            return "unbind";
        }
        if click and self.hit(310, 610, 260, 42) {
            return "controls_reset";
        }
        if click and self.hit(760, 610, 200, 42) {
            return "quit";
        }
        return "";
    }

    def draw(width: int, height: int) {
        self.place(width, height);
        white = Color(r=235, g=229, b=215, a=255);
        amber = Color(r=255, g=184, b=107, a=255);
        brown = Color(r=99, g=64, b=35, a=255);
        DrawRectangle(i32(0), i32(0), i32(width), i32(height), Color(r=0, g=0, b=0, a=200));
        self.box(280, 65, 720, 610, Color(r=27, g=25, b=23, a=255));
        self.label("QUAKEPASSION", 310, 85, 30, amber);
        self.box(630, 82, 160, 32, brown);
        self.label("Levels" if self.controls_open else "Controls", 645, 89, 20, white);
        self.box(800, 82, 160, 32, brown);
        self.label("Levels" if self.settings_open else "Settings", 815, 89, 20, white);
        if self.controls_open {
            self.draw_controls(white, amber, brown);
            return;
        }
        if self.settings_open {
            self.label(
                "Settings | Esc: resume | Up/Down: select | Left/Right: change",
                310,
                120,
                18,
                white
            );
            for row in range(len(self.settings_labels)) {
                color = brown
                    if row == self.setting_selected
                    else Color(r=48, g=45, b=41, a=255);
                self.box(310, 150 + row * SETTING_PITCH, 650, SETTING_PITCH - 2, color);
                self.label(self.settings_labels[row], 322, 152 + row * SETTING_PITCH, 18, white);
                self.label("<     >", 830, 152 + row * SETTING_PITCH, 18, amber);
            }
            self.label(
                self.message[:75]
                    if self.message
                    else "Changes are saved automatically",
                310,
                666,
                16,
                white
            );
            self.box(310, 610, 260, 42, brown);
            self.label("Reset defaults", 322, 622, 20, white);
            self.box(760, 610, 200, 42, Color(r=75, g=35, b=30, a=255));
            self.label("Quit", 825, 622, 20, white);
            return;
        }
        self.label("Choose a level  |  Esc: resume", 310, 120, 18, white);
        titles = ["Quake", "Quake II", "Quake III", "Passion"];
        for i in range(len(self.games)) {
            color = brown if i == self.game else Color(r=48, g=45, b=41, a=255);
            self.box(310 + i * 165, 145, 155, 40, color);
            self.label(titles[i], 325 + i * 165, 155, 22, white);
        }
        if self.games[self.game] == "passion" {
            self.draw_seed(white, amber, brown);
            return;
        }
        for row in range(11) {
            index = self.offset + row;
            if index >= len(self.maps) {
                break;
            }
            if index == self.selected {
                self.box(310, 205 + row * 30, 425, 28, brown);
            }
            self.label(
                (self.labels[index] if index < len(self.labels) else self.maps[index])[:38],
                322,
                209 + row * 30,
                20,
                white
            );
        }
        # The game's packs, beside its maps.
        for row in range(len(self.packs)) {
            color = brown if row == self.pack else Color(r=48, g=45, b=41, a=255);
            self.box(750, 205 + row * 30, 210, 28, color);
            self.label(self.pack_titles[row][:26], 758, 211 + row * 30, 16, white);
        }
        self.label(
            str(len(self.maps))
                + " maps | Up / Down: map | Left / Right: pack | Enter: load",
            310,
            550,
            18,
            white
        );
        self.label(self.message[:75], 310, 580, 16, amber);
        self.box(310, 610, 260, 42, brown);
        self.label("Render selected level", 322, 622, 20, white);
        self.box(760, 610, 200, 42, Color(r=75, g=35, b=30, a=255));
        self.label("Quit", 825, 622, 20, white);
    }

    """Passion's page: the seed of the run, and how a run goes."""
    def draw_seed(white: Color, amber: Color, brown: Color) {
        self.label("Seed", 310, 222, 22, white);
        self.box(380, 260, 170, 44, Color(r=48, g=45, b=41, a=255));
        caret = "_" if int(time.time() * 2.0) % 2 == 0 else " ";
        self.label(self.seed_text + caret, 392, 270, 26, amber);
        self.box(560, 260, 160, 44, brown);
        self.label("Roll the dice", 572, 272, 20, white);
        self.label("Made by", 310, 332, 18, white);
        titles = {VERSION: "Essences", HANDMADE_VERSION: "Hand-made prefabs", PREFAB_VERSION: "Originals' stretches"};
        for (column, engine) in enumerate([VERSION, HANDMADE_VERSION, PREFAB_VERSION]) {
            chosen = self.passion_engine == engine;
            self.box(380 + column * 195, 322, 185, 40, brown if chosen else Color(r=48, g=45, b=41, a=255));
            self.label(titles[engine], 388 + column * 195, 333, 17, white);
        }
        lines = [
            "Type a seed, or roll one. A seed is a whole run:",
            "each level's way out leads on to the next,",
            "made while you play the one before.",
            "The same seed always plays the same run.",
            "Health, armour and weapons carry on; keys do not."
        ];
        for (row, line) in enumerate(lines) {
            self.label(line, 310, 390 + row * 28, 20, white);
        }
        self.label(self.message[:75], 310, 580, 16, amber);
        self.box(310, 610, 260, 42, brown);
        self.label("Start the run", 322, 622, 20, white);
        self.box(760, 610, 200, 42, Color(r=75, g=35, b=30, a=255));
        self.label("Quit", 825, 622, 20, white);
    }

    """M_Keys_Draw: each action with the keys bound to it."""
    def draw_controls(white: Color, amber: Color, brown: Color) {
        self.label(
            "Controls | Esc: resume | Enter: change | Backspace: clear",
            310,
            120,
            18,
            white
        );
        for row in range(14) {
            index = self.controls_offset + row;
            if index >= len(self.controls_labels) {
                break;
            }
            color = brown if index == self.controls_selected else Color(r=48, g=45, b=41, a=255);
            self.box(310, 150 + row * 30, 650, 28, color);
            self.label(self.controls_labels[index], 322, 154 + row * 30, 20, white);
            keys = self.controls_keys[index] if index < len(self.controls_keys) else "";
            if self.grabbing and index == self.controls_selected {
                keys = "=";
            }
            self.label(keys if keys else "???", 620, 154 + row * 30, 20, amber);
        }
        prompt = "Press a key or button for this action | Esc: cancel"
            if self.grabbing
            else (self.message[:75] if self.message else "Each game keeps its own bindings");
        self.label(prompt, 310, 580, 16, amber if self.grabbing else white);
        self.box(310, 610, 260, 42, brown);
        self.label("Reset defaults", 322, 622, 20, white);
        self.box(760, 610, 200, 42, Color(r=75, g=35, b=30, a=255));
        self.label("Quit", 825, 622, 20, white);
    }
}
