"""Pause menu and archive-backed map catalogue."""
import os;
import from zipfile { ZipFile }
import from ..assets.pak { open_pak }
import from ..formats.q1.bsp { i32_at, require_range, parse_entities }
import from ..render.renderer { Color }
import from ..input.input { IsKeyPressed, IsMouseButtonPressed, GetMouseX, GetMouseY }
import from vendor.raylib {
    def DrawRectangle(x: i32, y: i32, width: i32, height: i32, color: Color) -> None;  def DrawText(
        text: str, x: i32, y: i32, size: i32, color: Color
    ) -> None;  def GetMouseWheelMove -> f32;
}

def game_directory(game: str) -> str {
    if game == os.getenv("QP_GAME", "q1") and os.getenv("QP_ASSETS", "") != "" {
        return os.getenv("QP_ASSETS", "");
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

obj LevelMenu {
    has opened: bool = False,
        restore_mouse: bool = False,
        game: int = 0,
        selected: int = 0,
        offset: int = 0,
        maps: list[str] = [],
        message: str = "",
        games: list[str] = ["q1", "q2", "q3"];

    def scan() {
        self.maps = [];
        self.selected = 0;
        self.offset = 0;
        self.message = "";
        names: list[str] = [];
        try {
            directory = game_directory(self.games[self.game]);
            for filename in sorted(os.listdir(directory)) {
                path = directory + "/" + filename;
                if self.game == 2 and filename.lower().endswith(".pk3") {
                    with ZipFile(path) as archive {
                        names.extend(archive.namelist());
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
            if len(self.maps) == 0 {
                self.message = "No maps found in " + directory;
            }
        } except Exception as error {
            self.message = "Cannot list maps: " + str(error);
        }
    }

    def hit(x: int, y: int, w: int, h: int) -> bool {
        mx = int(GetMouseX());
        my = int(GetMouseY());
        return mx >= x and mx < x + w and my >= y and my < y + h;
    }

    # Returns load, quit, or an empty string. Escape is handled by the app.
    def update() -> str {
        click = IsMouseButtonPressed(i32(0));
        for i in range(3) {
            if click and self.hit(310 + i * 220, 145, 210, 40) {
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

    def draw() {
        white = Color(r=235, g=229, b=215, a=255);
        amber = Color(r=255, g=184, b=107, a=255);
        DrawRectangle(i32(0), i32(0), i32(1280), i32(720), Color(r=0, g=0, b=0, a=200));
        DrawRectangle(
            i32(280), i32(65), i32(720), i32(610), Color(r=27, g=25, b=23, a=255)
        );
        DrawText("QUAKEPASSION", i32(310), i32(85), i32(30), amber);
        DrawText("Choose a level  |  Esc: resume", i32(310), i32(120), i32(18), white);
        titles = ["Quake", "Quake II", "Quake III"];
        for i in range(3) {
            color = Color(r=99, g=64, b=35, a=255)
                if i == self.game
                else Color(r=48, g=45, b=41, a=255);
            DrawRectangle(i32(310 + i * 220), i32(145), i32(210), i32(40), color);
            DrawText(titles[i], i32(325 + i * 220), i32(155), i32(22), white);
        }
        for row in range(11) {
            index = self.offset + row;
            if index >= len(self.maps) {
                break;
            }
            if index == self.selected {
                DrawRectangle(
                    i32(310),
                    i32(205 + row * 30),
                    i32(650),
                    i32(28),
                    Color(r=99, g=64, b=35, a=255)
                );
            }
            DrawText(self.maps[index], i32(322), i32(209 + row * 30), i32(20), white);
        }
        DrawText(
            str(len(self.maps)) + " maps | Scroll / Up / Down | Enter: load",
            i32(310),
            i32(550),
            i32(18),
            white
        );
        DrawText(self.message[:75], i32(310), i32(580), i32(16), amber);
        DrawRectangle(
            i32(310), i32(610), i32(260), i32(42), Color(r=99, g=64, b=35, a=255)
        );
        DrawText("Render selected level", i32(322), i32(622), i32(20), white);
        DrawRectangle(
            i32(760), i32(610), i32(200), i32(42), Color(r=75, g=35, b=30, a=255)
        );
        DrawText("Quit", i32(825), i32(622), i32(20), white);
    }
}
