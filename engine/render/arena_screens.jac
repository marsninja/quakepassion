"""Q3's arena screens in its own 2D art, on the 640x480 virtual screen scaled
to the window's height and centred: the in-game scoreboard
(cg_scoreboard.c CG_DrawOldScoreboard) and the single-player postgame menu
over the podium (q3_ui/ui_sppostgame.c UI_SPPostgameMenu)."""
import math;
import from .hud { HudRenderer }
import from .hud_models { HudModels }
import from .models { ModelRenderer }
import from ..formats.bsp { Texture }
import from ..math.vec3 { Vec3 }

# q3_ui/ui_atoms.c propMap: each character's column, row and width in
# menu/art/font1_prop.tga (256x256, 27 units tall); -1 has no glyph.
glob PROP_MAP: list[list[int]] = [
    [0, 0, 8], [11, 122, 7], [154, 181, 14], [55, 122, 17], [79, 122, 18], [101, 122, 23], [153, 122, 18], [9, 93, 7],
    [207, 122, 8], [230, 122, 9], [177, 122, 18], [30, 152, 18], [85, 181, 7], [34, 93, 11], [110, 181, 6], [130, 152, 14],
    [22, 64, 17], [41, 64, 12], [58, 64, 17], [78, 64, 18], [98, 64, 19], [120, 64, 18], [141, 64, 18], [204, 64, 16],
    [162, 64, 17], [182, 64, 18], [59, 181, 7], [35, 181, 7], [203, 152, 14], [56, 93, 14], [228, 152, 14], [177, 181, 18],
    [28, 122, 22], [5, 4, 18], [27, 4, 18], [48, 4, 18], [69, 4, 17], [90, 4, 13], [106, 4, 13], [121, 4, 18],
    [143, 4, 17], [164, 4, 8], [175, 4, 16], [195, 4, 18], [216, 4, 12], [230, 4, 23], [6, 34, 18], [27, 34, 18],
    [48, 34, 18], [68, 34, 18], [90, 34, 17], [110, 34, 18], [130, 34, 14], [146, 34, 18], [166, 34, 19], [185, 34, 29],
    [215, 34, 18], [234, 34, 18], [5, 64, 14], [60, 152, 7], [106, 151, 13], [83, 152, 7], [128, 122, 17], [4, 152, 21],
    [134, 181, 5], [5, 4, 18], [27, 4, 18], [48, 4, 18], [69, 4, 17], [90, 4, 13], [106, 4, 13], [121, 4, 18],
    [143, 4, 17], [164, 4, 8], [175, 4, 16], [195, 4, 18], [216, 4, 12], [230, 4, 23], [6, 34, 18], [27, 34, 18],
    [48, 34, 18], [68, 34, 18], [90, 34, 17], [110, 34, 18], [130, 34, 14], [146, 34, 18], [166, 34, 19], [185, 34, 29],
    [215, 34, 18], [234, 34, 18], [5, 64, 14], [153, 152, 13], [11, 181, 5], [180, 152, 13], [79, 93, 17], [0, 0, -1]
];

glob PROP_GAP_WIDTH: int = 3,
    PROP_HEIGHT: int = 27;

# ui_sppostgame.c: medal art and announcer lines by award, in order, and where
# the medals stand along the top.
glob MEDAL_NAMES: dict[str, str] = {
    "accuracy": "Accuracy",
    "impressive": "Impressive",
    "excellent": "Excellent",
    "gauntlet": "Gauntlet",
    "frags": "Frags",
    "perfect": "Perfect"
};
glob MEDAL_SOUNDS: dict[str, str] = {
    "accuracy": "sound/feedback/accuracy.wav",
    "impressive": "sound/feedback/impressive_a.wav",
    "excellent": "sound/feedback/excellent_a.wav",
    "gauntlet": "sound/feedback/gauntlet.wav",
    "frags": "sound/feedback/frags.wav",
    "perfect": "sound/feedback/perfect.wav"
};
glob MEDAL_SPOTS: list[int] = [144, 448, 88, 504, 32, 560];

# AWARD_PRESENTATION_TIME: each award takes the stage for two seconds.
glob AWARD_TIME: float = 2.0;

"""Where a proportional string starts for its alignment."""
def prop_width(text: str) -> int {
    width = 0;
    for c in text {
        code = ord(c) & 127;
        if PROP_MAP[max(0, code - 32)][2] != -1 and code >= 32 {
            width += PROP_MAP[code - 32][2] + PROP_GAP_WIDTH;
        }
    }
    return max(0, width - PROP_GAP_WIDTH);
}

"""One scoreboard line (CG_DrawClientScore), ready to draw: `rank` counts
from 0; `skill` is a bot's skill (0 for the human); `icon` the character's
2D icon and `head` its head model, placed at `head_origin`."""
obj BoardLine {
    has name: str,
        score: int,
        minutes: int,
        human: bool,
        rank: int = 0,
        tied: bool = False,
        skill: int = 0,
        icon: str = "",
        head: ModelRenderer | None = None,
        head_origin: Vec3 = Vec3(),
        excellent: int = 0,
        impressive: int = 0,
        gauntlet: int = 0;
}

"""The virtual 640x480 screen on the window: scaled to its height, centred."""
obj Screen {
    has scale: float = 1.0,
        left: float = 0.0,
        width: int = 640,
        height: int = 480;

    def x(value: float) -> float {
        return self.left + value * self.scale;
    }

    def y(value: float) -> float {
        return value * self.scale;
    }

    def size(value: float) -> float {
        return value * self.scale;
    }
}

def screen_for(width: int, height: int) -> Screen {
    scale = float(height) / 480.0;
    return Screen(scale=scale, left=(float(width) - 640.0 * scale) * 0.5, width=width, height=height);
}

"""A solid rectangle (CG_FillRect) from a white texel."""
def fill(hud: HudRenderer, view: Screen, x: float, y: float, w: float, h: float, tint: list[int]) {
    if not hud.has_pic("white") {
        hud.add("white", Texture(name="white", width=1, height=1, pixels=bytes([255, 255, 255, 255])));
    }
    hud.blit("white", view.x(x), view.y(y), view.size(w), view.size(h), tint);
}

"""A line in gfx/2d/bigchars (CG_DrawStringExt), `w` by `h` cells, with the
black drop shadow of CG_DrawBigString."""
def cell_text(hud: HudRenderer, view: Screen, text: str, x: float, y: float, w: float, h: float, tint: list[int], shadow: bool = True) {
    if shadow {
        cell_line(hud, view, text, x + 2.0, y + 2.0, w, h, [0, 0, 0, tint[3]]);
    }
    cell_line(hud, view, text, x, y, w, h, tint);
}

def cell_line(hud: HudRenderer, view: Screen, text: str, x: float, y: float, w: float, h: float, tint: list[int]) {
    for i in range(len(text)) {
        code = ord(text[i]) & 255;
        if code == 32 {
            continue;
        }
        column = float(code % 16) / 16.0;
        row = float(code // 16) / 16.0;
        hud.blit(
            "conchars", view.x(x + float(i) * w), view.y(y), view.size(w), view.size(h), tint,
            column, row, column + 1.0 / 16.0, row + 1.0 / 16.0
        );
    }
}

"""UI_DrawProportionalString in menu/art/font1_prop: `align` is "left",
"center" or "right"; `size` scales it (0.75 for UI_SMALLFONT)."""
def prop_text(hud: HudRenderer, view: Screen, text: str, x: float, y: float, tint: list[int], align: str = "left", size: float = 1.0, shadow: bool = True) {
    width = float(prop_width(text)) * size;
    if align == "center" {
        x -= width * 0.5;
    } elif align == "right" {
        x -= width;
    }
    if shadow {
        prop_line(hud, view, text, x + 2.0, y + 2.0, [0, 0, 0, tint[3]], size);
    }
    prop_line(hud, view, text, x, y, tint, size);
}

def prop_line(hud: HudRenderer, view: Screen, text: str, x: float, y: float, tint: list[int], size: float) {
    for c in text {
        code = ord(c) & 127;
        if code < 32 {
            continue;
        }
        glyph = PROP_MAP[code - 32];
        if glyph[2] == -1 {
            continue;
        }
        if code != 32 {
            u = float(glyph[0]) / 256.0;
            v = float(glyph[1]) / 256.0;
            hud.blit(
                "font_prop", view.x(x), view.y(y), view.size(float(glyph[2]) * size), view.size(float(PROP_HEIGHT) * size),
                tint, u, v, u + float(glyph[2]) / 256.0, v + float(PROP_HEIGHT) / 256.0
            );
        }
        x += float(glyph[2] + PROP_GAP_WIDTH) * size;
    }
}

"""printf's %Ni: `value` right-aligned in `digits` columns."""
def right_aligned(value: int, digits: int) -> str {
    text = str(value);
    while len(text) < digits {
        text = " " + text;
    }
    return text;
}

"""printf's %-Ns: `text` padded to `digits` columns."""
def left_aligned(text: str, digits: int) -> str {
    while len(text) < digits {
        text = text + " ";
    }
    return text;
}

# CG_PlaceString colours: 1st blue, 2nd red, 3rd yellow.
def place_tint(rank: int) -> list[int] {
    if rank == 0 {
        return [0, 0, 255, 255];
    }
    if rank == 1 {
        return [255, 0, 0, 255];
    }
    return [255, 255, 0, 255] if rank == 2 else [255, 255, 255, 255];
}

# CG_DrawClientScore's highlight behind the player's own line, by rank.
def rank_highlight(rank: int) -> list[int] {
    alpha = int(0.7 * 255.0);
    if rank == 0 {
        return [0, 0, 178, alpha];
    }
    if rank == 1 {
        return [178, 0, 0, alpha];
    }
    return [178, 178, 0, alpha] if rank == 2 else [178, 178, 178, alpha];
}

"""CG_DrawOldScoreboard for a free-for-all: "Fragged by" when a killer is
named, the player's place, the column headers, and a 40-unit line per
competitor with its bot skill icon, its head (the 3D head model with
cg_draw3dIcons, or the character icon), score, time and name. There is no
ping to show in a local game; instead each line lists its excellent,
impressive and gauntlet awards under the name, as counted on the match."""
def draw_scoreboard(
    hud: HudRenderer,
    heads: HudModels | None,
    lines: list[BoardLine],
    killer: str,
    width: int,
    height: int,
    clock: float
) {
    if not hud.has_pic("conchars") {
        return;
    }
    view = screen_for(width, height);
    white = [255, 255, 255, 255];
    if killer {
        text = "Fragged by " + killer;
        cell_text(hud, view, text, (640.0 - float(len(text)) * 16.0) * 0.5, 40.0, 16.0, 16.0, white);
    }
    for line in lines {
        if line.human {
            prefix = "Tied for " if line.tied else "";
            place = ["1st", "2nd", "3rd"][line.rank] if line.rank < 3 else str(line.rank + 1) + "th";
            rest = " place with " + str(line.score);
            total = float(len(prefix + place + rest)) * 16.0;
            x = (640.0 - total) * 0.5;
            cell_text(hud, view, prefix, x, 60.0, 16.0, 16.0, white);
            x += float(len(prefix)) * 16.0;
            cell_text(hud, view, place, x, 60.0, 16.0, 16.0, place_tint(line.rank));
            x += float(len(place)) * 16.0;
            cell_text(hud, view, rest, x, 60.0, 16.0, 16.0, white);
        }
    }
    # SB_HEADER: the score, time and name tabs (SB_SCORE_X, SB_TIME_X,
    # SB_NAME_X, each half a rating width in).
    for (pic, x) in [("tab_score", 176.0), ("tab_time", 344.0), ("tab_name", 416.0)] {
        hud.blit(pic, view.x(x), view.y(86.0), view.size(64.0), view.size(32.0));
    }
    y = 118.0;
    for line in lines[:7] {
        draw_score_line(hud, heads, view, line, y, width, height, clock);
        y += 40.0;
    }
}

def draw_score_line(hud: HudRenderer, heads: HudModels | None, view: Screen, line: BoardLine, y: float, width: int, height: int, clock: float) {
    white = [255, 255, 255, 255];
    icon_x = 80.0;
    head_x = 112.0;
    # The bot skill marker (cgs.media.botSkillShaders).
    if line.skill >= 1 and line.skill <= 5 {
        hud.blit("skill" + str(line.skill), view.x(icon_x), view.y(y - 8.0), view.size(32.0), view.size(32.0));
    }
    # CG_DrawHead: the head model turned to face the viewer, or its icon.
    head = line.head;
    if heads is not None and head is not None and heads.target.prepare_size(256, 256) {
        heads.icon(hud, head, line.head_origin, 180.0, 0.0, view.x(head_x), view.y(y - 16.0), view.size(48.0), width, height, clock);
    } elif line.icon {
        hud.blit(line.icon, view.x(head_x), view.y(y - 16.0), view.size(48.0), view.size(48.0));
    }
    if line.human {
        fill(hud, view, 176.0, y, 640.0 - 128.0, 17.0, rank_highlight(line.rank));
    }
    text = right_aligned(line.score, 5) + "      " + right_aligned(line.minutes, 4) + " " + line.name;
    cell_text(hud, view, text, 160.0, y, 16.0, 16.0, white);
    # The awards counted for this competitor, small, under its name.
    x = 416.0;
    for (kind, count) in [("excellent", line.excellent), ("impressive", line.impressive), ("gauntlet", line.gauntlet)] {
        if count <= 0 {
            continue;
        }
        hud.blit("medal_" + kind, view.x(x), view.y(y + 18.0), view.size(16.0), view.size(16.0));
        label = str(count);
        cell_text(hud, view, label, x + 18.0, y + 18.0, 8.0, 16.0, white, False);
        x += 26.0 + 8.0 * float(len(label));
    }
}

"""The postgame menu's state (postgameMenuInfo): three phases timed from
`start` — the finishers' names on the podium for five seconds, each award
presented for two, then the medals with the menu, replay and next buttons —
with the scoreboard lines along the top right."""
obj Postgame {
    has start: float = 0.0,
        board_start: float = 0.0,
        phase: int = 1,
        phase_start: float = 0.0,
        ignore_until: float = 0.0,
        medals: list[str] = [],
        amounts: list[int] = [],
        played: int = 0,
        places: list[str] = [],
        winner_sound: str = "",
        announced: bool = False,
        focus: int = 2,
        won: bool = False,
        scores: list[str] = [];

    """Advance the phases to `now`; returns the sounds to play."""
    def update(now: float) -> list[str] {
        cues: list[str] = [];
        if self.phase == 1 {
            if now - self.phase_start >= 1.0 and not self.announced {
                self.announced = True;
                if self.winner_sound {
                    cues.append(self.winner_sound);
                }
            }
            if now - self.phase_start >= 5.0 {
                self.enter(2, now);
            }
        }
        if self.phase == 2 {
            elapsed = now - self.phase_start;
            shown = int(elapsed / AWARD_TIME);
            while self.played < len(self.medals) and self.played <= shown {
                cues.append(MEDAL_SOUNDS.get(self.medals[self.played], ""));
                self.played += 1;
            }
            if elapsed >= float(len(self.medals)) * AWARD_TIME and elapsed >= 5.0 {
                self.enter(3, now);
            }
        }
        return [cue for cue in cues if cue];
    }

    def enter(phase: int, now: float) {
        self.phase = phase;
        self.phase_start = now;
        self.ignore_until = now + 0.25;
    }

    """UI_SPPostgameMenu_MenuKey: a key skips the podium and then the awards;
    once the buttons show, left and right choose among them. Returns the
    button to act on ("menu", "replay" or "next"), or ""."""
    def key(now: float, pressed: str) -> str {
        if now < self.ignore_until {
            return "";
        }
        if self.phase == 1 {
            self.announced = True;
            self.enter(2, now);
            return "";
        }
        if self.phase == 2 {
            self.played = len(self.medals);
            self.enter(3, now);
            return "";
        }
        if pressed == "left" {
            self.focus = max(0, self.focus - 1);
        } elif pressed == "right" {
            self.focus = min(2, self.focus + 1);
        } elif pressed == "enter" {
            return ["menu", "replay", "next"][self.focus];
        }
        return "";
    }
}

"""UI_SPPostgameMenu_MenuDraw."""
def draw_postgame(hud: HudRenderer, board: Postgame, now: float, width: int, height: int) {
    view = screen_for(width, height);
    white = [255, 255, 255, 255];
    if hud.has_pic("font_prop") {
        # The finishers' names over their pads.
        if len(board.places) > 2 {
            prop_text(hud, view, board.places[2], 510.0, 480.0 - 64.0 - 27.0, white, "center");
        }
        if len(board.places) > 1 {
            prop_text(hud, view, board.places[1], 130.0, 480.0 - 64.0 - 27.0, white, "center");
        }
        if board.places {
            prop_text(hud, view, board.places[0], 320.0, 480.0 - 64.0 - 54.0, white, "center");
        }
    }
    if board.phase == 2 and board.medals {
        elapsed = now - board.phase_start;
        index = min(len(board.medals) - 1, int(elapsed / AWARD_TIME));
        if elapsed < float(len(board.medals)) * AWARD_TIME {
            fade = int(255.0 * max(0.0, (AWARD_TIME - (elapsed - float(index) * AWARD_TIME)) / AWARD_TIME));
            if hud.has_pic("font_prop") {
                prop_text(hud, view, MEDAL_NAMES.get(board.medals[index], ""), 320.0, 64.0, [255, 255, 255, fade], "center", 1.0, False);
            }
            draw_medals(hud, view, board, index + 1);
        }
    }
    if board.phase == 3 {
        draw_medals(hud, view, board, len(board.medals));
        # The menu, replay and next buttons, the focused one lit and pulsing.
        pulse = int(255.0 * (0.75 + 0.25 * math.sin(now * 2.0 * math.pi * 1.5)));
        spots = [0.0, 320.0 - 64.0, 640.0 - 128.0];
        names = ["menu", "replay", "next"];
        for i in range(3) {
            pic = "button_" + names[i] + ("_1" if i == board.focus else "_0");
            tint = [255, 255, 255, pulse] if i == board.focus else white;
            hud.blit(pic, view.x(spots[i]), view.y(480.0 - 64.0), view.size(128.0), view.size(64.0), tint);
        }
    }
    # ui_spScoreboard: three lines at the top right, rolling every 1.5 s
    # when there are more than three players.
    count = len(board.scores);
    first = 0;
    if count > 3 {
        first = int((now - board.board_start) / 1.5) % (count + 2);
    }
    for row in range(3) {
        index = first + row;
        if index > count + 1 {
            index -= count + 2;
        }
        if index < count {
            cell_text(hud, view, board.scores[index], 640.0 - 31.0 * 8.0, float(row) * 16.0, 8.0, 16.0, white, False);
        }
    }
}

"""UI_SPPostgameMenu_DrawAwardsMedals: the first `shown` medals along the
top, each with its count (a percentage for accuracy) in yellow beneath."""
def draw_medals(hud: HudRenderer, view: Screen, board: Postgame, shown: int) {
    for n in range(min(shown, len(board.medals), len(MEDAL_SPOTS))) {
        x = float(MEDAL_SPOTS[n]);
        kind = board.medals[n];
        hud.blit("medal_" + kind, view.x(x), view.y(64.0), view.size(48.0), view.size(48.0));
        amount = board.amounts[n];
        label = "";
        if kind == "accuracy" {
            label = str(amount) + "%";
        } elif amount != 1 {
            label = str(amount);
        }
        if label {
            cell_text(hud, view, label, x + 24.0 - float(len(label)) * 8.0, 64.0 + 52.0, 16.0, 16.0, [255, 255, 0, 255]);
        }
    }
}

"""UI_SPPostgameMenu_MenuDrawScoreLine's text: "#rank: name score", with
"(tie)" before a shared rank."""
def postgame_score_line(rank: int, tied: bool, name: str, score: int) -> str {
    return ("(tie) " if tied else "      ") + "#" + str(rank + 1) + ": " + left_aligned(name[:16], 16) + " " + right_aligned(score, 2);
}
