"""Pause menu and archive-backed map catalogue."""
import os;
import time;
import from zipfile { ZipFile }
import from ..assets.pak { open_pak }
import from ..formats.bsp { i32_at, require_range, parse_entities }
import from ..render.renderer { Color }
import from ..input.input { IsKeyPressed, IsMouseButtonPressed, GetMouseX, GetMouseY }
import from vendor.raylib {
    def DrawRectangle(x: i32, y: i32, width: i32, height: i32, color: Color) -> None;  def DrawText(
        text: str, x: i32, y: i32, size: i32, color: Color
    ) -> None;  def GetMouseWheelMove -> f32;
}

import from games.arenas { ArenaProgress, parse_arenas, ladder }
import from ..world.arena { ordinal }

def game_directory(game: str) -> str {
    if game == os.getenv("QP_GAME", "q1") and os.getenv("QP_ASSETS", "") != "" {
        return os.getenv("QP_ASSETS", "");
    }
    if game == "passion" {
        return os.getenv("HOME", "") + "/quake-assets";
    }
    folder = "id1" if game == "q1" else ("baseq2" if game == "q2" else "baseq3");
    return os.getenv("HOME", "") + "/quake-assets/" + folder;
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

# Quake also stores standalone brush models under maps/*.bsp.
def is_q1_level(data: bytes) -> bool {
    if i32_at(data, 0) != 29 {
        return False;
    }
    offset = i32_at(data, 4);
    length = i32_at(data, 8);
    require_range(data, offset, length);
    for entity in parse_entities(data[offset:offset + length].decode("utf-8")) {
        if entity.fields.get("classname", "")
            in ["info_player_start", "info_player_deathmatch"] {
            return True;
        }
    }
    return False;
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
        games: list[str] = ["q1", "q2", "q3", "passion"];

    def scan() {
        self.maps = [];
        self.labels = [];
        self.selected = 0;
        self.offset = 0;
        self.message = "";
        if self.games[self.game] == "passion" {
            seed = max(int(time.time()), self.seed_cursor + 12) % 2147483000 + 1;
            self.seed_cursor = seed;
            self.maps = ["v2-" + str(seed + i) for i in range(12)];
            self.message = "Seeded expeditions | Click Passion for fresh seeds";
            return;
        }
        names: list[str] = [];
        arena_text = "";
        try {
            directory = game_directory(self.games[self.game]);
            for filename in sorted(os.listdir(directory)) {
                path = directory + "/" + filename;
                if self.game == 2 and filename.lower().endswith(".pk3") {
                    with ZipFile(path) as archive {
                        listed = archive.namelist();
                        names.extend(listed);
                        if "scripts/arenas.txt" in listed {
                            arena_text = archive.read("scripts/arenas.txt").decode("utf-8");
                        }
                    }
                } elif self.game != 2 and filename.lower().endswith(".pak") {
                    pak = open_pak(path);
                    for name in pak.names() {
                        if self.game != 0
                            or not name.startswith("maps/")
                            or not name.lower().endswith(".bsp") {
                            names.append(name);
                        } elif is_q1_level(pak.read_file(name)) {
                            names.append(name);
                        }
                    }
                }
            }
            self.maps = map_names(names);
            self.labels = list(self.maps);
            if arena_text {
                self.order_arenas(arena_text);
            }
            if len(self.maps) == 0 {
                self.message = "No maps found in " + directory;
            }
        } except Exception as error {
            self.message = "Cannot list maps: " + str(error);
        }
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
                if click and self.hit(310, 150 + row * 30, 650, 28) {
                    self.setting_selected = row;
                    return "setting_left"
                        if self.hit(810, 150 + row * 30, 65, 28)
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
                and self.hit(310, 205 + row * 30, 650, 28) {
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
                self.box(310, 150 + row * 30, 650, 28, color);
                self.label(self.settings_labels[row], 322, 154 + row * 30, 20, white);
                self.label("<     >", 830, 154 + row * 30, 20, amber);
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
        for row in range(11) {
            index = self.offset + row;
            if index >= len(self.maps) {
                break;
            }
            if index == self.selected {
                self.box(310, 205 + row * 30, 650, 28, brown);
            }
            self.label(
                self.labels[index] if index < len(self.labels) else self.maps[index],
                322,
                209 + row * 30,
                20,
                white
            );
        }
        self.label(
            str(len(self.maps)) + " maps | Scroll / Up / Down | Enter: load",
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
