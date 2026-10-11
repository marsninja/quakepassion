"""The studio's 2D drawing surface.

Widgets draw through a Canvas and never call raylib themselves: the screen
canvas draws with raylib, and the trace canvas records what was drawn so the
toolkit's tests run without a window. Coordinates are screen units."""
import os;
import from vendor.raylib {
    # raylib's value types, declared beside the calls that take them as
    # renderer.jac and quake.jac do, so the toolkit builds without the engine.
    obj Color {
        has r: u8,
            g: u8,
            b: u8,
            a: u8;
    }  obj Vector2 {
        has x: f32,
            y: f32;
    }  obj Texture2D {
        has id: u32,
            width: i32,
            height: i32,
            mipmaps: i32,
            format: i32;
    }  def DrawRectangle(x: i32, y: i32, width: i32, height: i32, color: Color) -> None;  def DrawRectangleLines(
        x: i32, y: i32, width: i32, height: i32, color: Color
    ) -> None;  def DrawLine(
        startPosX: i32, startPosY: i32, endPosX: i32, endPosY: i32, color: Color
    ) -> None;  def DrawTriangle(v1: Vector2, v2: Vector2, v3: Vector2, color: Color) -> None;  def BeginScissorMode(
        x: i32, y: i32, width: i32, height: i32
    ) -> None;  def EndScissorMode -> None;  obj UiFont {
        has baseSize: i32,
            glyphCount: i32,
            glyphPadding: i32,
            texture: Texture2D,
            recs: u64,
            glyphs: u64;
    }  def LoadFontEx(
        fileName: str, fontSize: i32, codepoints: u64, codepointCount: i32
    ) -> UiFont;  def GetFontDefault -> UiFont;  def UnloadFont(font: UiFont) -> None;  def DrawTextEx(
        font: UiFont, text: str, position: Vector2, fontSize: f32, spacing: f32, tint: Color
    ) -> None;  def MeasureTextEx(
        font: UiFont, text: str, fontSize: f32, spacing: f32
    ) -> Vector2;  def SetTextureFilter(texture: Texture2D, filter: i32) -> None;  def GetWindowScaleDPI -> Vector2;  def GetClipboardText -> str;  def SetClipboardText(
        text: str
    ) -> None;  def rlLoadTexture(
        data: bytes, width: i32, height: i32, format: i32, mipmapCount: i32
    ) -> u32;  def rlUnloadTexture(id: u32) -> None;  obj UiImage {
        has data: u64,
            width: i32,
            height: i32,
            mipmaps: i32,
            format: i32;
    }  def LoadImageFromMemory(
        fileType: str, fileData: bytes, dataSize: i32
    ) -> UiImage;  def LoadTextureFromImage(image: UiImage) -> Texture2D;  def UnloadImage(
        image: UiImage
    ) -> None;  def rlSetTexture(id: u32) -> None;  def rlBegin(
        mode: i32
    ) -> None;  def rlEnd -> None;  def rlTexCoord2f(x: f32, y: f32) -> None;  def rlVertex2f(
        x: f32, y: f32
    ) -> None;  def rlColor4ub(r: u8, g: u8, b: u8, a: u8) -> None;
}

"""A colour, as the theme and the trace canvas keep it."""
obj Ink {
    has r: int = 255,
        g: int = 255,
        b: int = 255,
        a: int = 255;

    def faded(alpha: int) -> Ink {
        return Ink(r=self.r, g=self.g, b=self.b, a=alpha);
    }
}

"""An Ink from 0xRRGGBB."""
def ink(rgb: int, alpha: int = 255) -> Ink {
    return Ink(r=(rgb >> 16) & 255, g=(rgb >> 8) & 255, b=rgb & 255, a=alpha);
}

"""A rectangle in screen units."""
obj Rect {
    has x: int = 0,
        y: int = 0,
        w: int = 0,
        h: int = 0;

    def right -> int {
        return self.x + self.w;
    }

    def bottom -> int {
        return self.y + self.h;
    }

    def holds(px: int, py: int) -> bool {
        return px >= self.x and py >= self.y and px < self.x + self.w and py < self.y + self.h;
    }

    """This rectangle shrunk by `margin` on every side."""
    def inset(margin: int) -> Rect {
        return Rect(
            x=self.x + margin,
            y=self.y + margin,
            w=max(0, self.w - 2 * margin),
            h=max(0, self.h - 2 * margin)
        );
    }

    """The part of this rectangle inside `other`."""
    def within(other: Rect) -> Rect {
        x0 = max(self.x, other.x);
        y0 = max(self.y, other.y);
        x1 = min(self.x + self.w, other.x + other.w);
        y1 = min(self.y + self.h, other.y + other.h);
        return Rect(x=x0, y=y0, w=max(0, x1 - x0), h=max(0, y1 - y0));
    }

    def same(other: Rect) -> bool {
        return self.x == other.x and self.y == other.y and self.w == other.w and self.h == other.h;
    }
}

"""The studio's colours and metrics."""
obj Theme {
    has window: Ink = ink(0x151412),
        panel: Ink = ink(0x211f1c),
        raised: Ink = ink(0x2c2925),
        header: Ink = ink(0x191715),
        border: Ink = ink(0x3a3530),
        field: Ink = ink(0x141311),
        text: Ink = ink(0xe6dfd4),
        dim: Ink = ink(0x9a9186),
        faint: Ink = ink(0x6b645b),
        accent: Ink = ink(0xff7a18),
        on_accent: Ink = ink(0x1a0f04),
        hover: Ink = ink(0x38332d),
        press: Ink = ink(0x4a4239),
        select: Ink = ink(0x6b3a12),
        warn: Ink = ink(0xe5484d),
        good: Ink = ink(0x4cc38a);
    has font: int = 13,
        small: int = 11,
        row: int = 22,
        pad: int = 6,
        gap: int = 4,
        bar: int = 10;
}

"""A drawing surface."""
obj Canvas {
    has theme: Theme = Theme(),
        # Seconds the interface has run, for blinking cursors.
        clock: float = 0.0;

    def fill(area: Rect, color: Ink) abst;
    def outline(area: Rect, color: Ink) abst;
    def line(x0: int, y0: int, x1: int, y1: int, color: Ink) abst;
    """A filled triangle; the corners run counter-clockwise on screen."""
    def triangle(x0: int, y0: int, x1: int, y1: int, x2: int, y2: int, color: Ink) abst;
    def text(words: str, x: int, y: int, color: Ink, size: int = 0) abst;
    def text_width(words: str, size: int = 0) -> int abst;
    """Keep drawing inside `area` until the next clip."""
    def clip(area: Rect) abst;
    def unclip abst;
    """The system clipboard's text."""
    def copied -> str abst;
    def copy(words: str) abst;
    """Keep an image by name: `rgba` is its pixels, four bytes each, rows
    from the top."""
    def keep_picture(key: str, width: int, height: int, rgba: bytes) abst;
    """Keep an image by name from a file's bytes (`extension` as ".tga",
    ".jpg" or ".png" says which kind). False when it does not decode."""
    def keep_encoded(key: str, extension: str, data: bytes) -> bool abst;
    """A kept image's width and height ([0, 0] when no image has that name)."""
    def picture_size(key: str) -> list[int] abst;
    def has_picture(key: str) -> bool abst;
    """Draw a kept image over `area`, as solid as `alpha` of 255. False when
    no image has that name."""
    def picture(key: str, area: Rect, alpha: int = 255) -> bool abst;

    """Text centred on the height of `area`: at its left edge (`align` -1,
    after `pad`), its middle (0) or its right edge (1)."""
    def label(
        words: str, area: Rect, color: Ink, align: int = -1, pad: int = 0, size: int = 0
    ) {
        height = size if size > 0 else self.theme.font;
        room = area.w - 2 * pad;
        shown = self.fitted(words, room, size);
        width = self.text_width(shown, size);
        x = area.x + pad;
        if align == 0 {
            x = area.x + (area.w - width) // 2;
        } elif align > 0 {
            x = area.x + area.w - pad - width;
        }
        self.text(shown, x, area.y + (area.h - height) // 2, color, size);
    }

    """`words` cut to fit `width`, ending in an ellipsis when cut."""
    def fitted(words: str, width: int, size: int = 0) -> str {
        if self.text_width(words, size) <= width {
            return words;
        }
        low = 0;
        high = len(words);
        while low < high {
            middle = (low + high + 1) // 2;
            if self.text_width(words[:middle] + "..", size) <= width {
                low = middle;
            } else {
                high = middle - 1;
            }
        }
        return words[:low] + ".." if low > 0 else "";
    }
}

"""One recorded drawing call."""
obj Stroke {
    has kind: str,
        area: Rect = Rect(),
        words: str = "",
        color: Ink = Ink();
}

"""A canvas that records its calls and measures text by a fixed advance, so
tests lay out and draw without a window."""
obj TraceCanvas(Canvas) {
    has strokes: list[Stroke] = [],
        board: str = "",
        kept: list[str] = [];

    def copied -> str {
        return self.board;
    }

    def keep_picture(key: str, width: int, height: int, rgba: bytes) {
        if key not in self.kept {
            self.kept.append(key);
        }
    }

    def has_picture(key: str) -> bool {
        return key in self.kept;
    }

    def keep_encoded(key: str, extension: str, data: bytes) -> bool {
        if len(data) == 0 {
            return False;
        }
        if key not in self.kept {
            self.kept.append(key);
        }
        return True;
    }

    def picture_size(key: str) -> list[int] {
        return [64, 64] if key in self.kept else [0, 0];
    }

    def picture(key: str, area: Rect, alpha: int = 255) -> bool {
        if key not in self.kept {
            return False;
        }
        self.strokes.append(Stroke(kind="picture", area=area, words=key));
        return True;
    }

    def copy(words: str) {
        self.board = words;
    }

    def line(x0: int, y0: int, x1: int, y1: int, color: Ink) {
        self.strokes.append(
            Stroke(kind="line", area=Rect(x=x0, y=y0, w=x1 - x0, h=y1 - y0), color=color)
        );
    }

    def triangle(x0: int, y0: int, x1: int, y1: int, x2: int, y2: int, color: Ink) {
        self.strokes.append(
            Stroke(kind="triangle", area=Rect(x=x0, y=y0, w=x1 - x2, h=y1 - y2), color=color)
        );
    }

    def text_width(words: str, size: int = 0) -> int {
        height = size if size > 0 else self.theme.font;
        return (len(words) * height * 11) // 20;
    }

    def unclip {
        self.strokes.append(Stroke(kind="unclip"));
    }

    def fill(area: Rect, color: Ink) {
        self.strokes.append(Stroke(kind="fill", area=area, color=color));
    }

    def outline(area: Rect, color: Ink) {
        self.strokes.append(Stroke(kind="outline", area=area, color=color));
    }

    def text(words: str, x: int, y: int, color: Ink, size: int = 0) {
        self.strokes.append(
            Stroke(kind="text", area=Rect(x=x, y=y, h=size), words=words, color=color)
        );
    }

    def clip(area: Rect) {
        self.strokes.append(Stroke(kind="clip", area=area));
    }

    """Every piece of text drawn, in order."""
    def words -> list[str] {
        return [stroke.words for stroke in self.strokes if stroke.kind == "text"];
    }
}

"""Font files tried in order when ed_font names none: the first that exists
is used, else raylib's built-in font."""
glob UI_FONT_PATHS: list[str] = [
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Geneva.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    "/usr/share/fonts/TTF/DejaVuSans.ttf",
    "/usr/share/fonts/dejavu/DejaVuSans.ttf",
    "C:/Windows/Fonts/segoeui.ttf"
];

"""The window's canvas."""
obj ScreenCanvas(Canvas) {
    has font: UiFont | None = None,
        font_path: str = "",
        loaded: bool = False,
        clipped: bool = False,
        clip_area: Rect = Rect(),
        # Kept images, by name, as the graphics card knows them, and their sizes.
        pictures: dict[str, int] = {},
        sizes: dict[str, list[int]] = {};

    """Load the interface font at the display's pixel density. Needs a window."""
    def open(path: str = "") {
        if self.loaded {
            return;
        }
        self.loaded = True;
        candidates = ([path] if path else []) + UI_FONT_PATHS;
        scale = max(1.0, float(GetWindowScaleDPI().x));
        for candidate in candidates {
            if os.path.isfile(candidate) {
                font = LoadFontEx(candidate, i32(int(18.0 * scale)), u64(0), i32(0));
                if int(font.glyphCount) > 0 {
                    SetTextureFilter(font.texture, i32(1));
                    self.font = font;
                    self.font_path = candidate;
                    return;
                }
            }
        }
    }

    def close {
        font = self.font;
        if font is not None {
            UnloadFont(font);
            self.font = None;
        }
        self.loaded = False;
    }

    def fill(area: Rect, color: Ink) {
        if area.w > 0 and area.h > 0 {
            DrawRectangle(i32(area.x), i32(area.y), i32(area.w), i32(area.h), screen_color(color));
        }
    }

    def outline(area: Rect, color: Ink) {
        if area.w > 0 and area.h > 0 {
            DrawRectangleLines(i32(area.x), i32(area.y), i32(area.w), i32(area.h), screen_color(color));
        }
    }

    def line(x0: int, y0: int, x1: int, y1: int, color: Ink) {
        DrawLine(i32(x0), i32(y0), i32(x1), i32(y1), screen_color(color));
    }

    def triangle(x0: int, y0: int, x1: int, y1: int, x2: int, y2: int, color: Ink) {
        DrawTriangle(
            Vector2(x=f32(x0), y=f32(y0)),
            Vector2(x=f32(x1), y=f32(y1)),
            Vector2(x=f32(x2), y=f32(y2)),
            screen_color(color)
        );
    }

    def text(words: str, x: int, y: int, color: Ink, size: int = 0) {
        if not words {
            return;
        }
        height = size if size > 0 else self.theme.font;
        font = self.font;
        if font is None {
            font = GetFontDefault();
        }
        DrawTextEx(
            font, words, Vector2(x=f32(x), y=f32(y)), f32(height), f32(0.0), screen_color(color)
        );
    }

    def text_width(words: str, size: int = 0) -> int {
        if not words {
            return 0;
        }
        height = size if size > 0 else self.theme.font;
        font = self.font;
        if font is None {
            font = GetFontDefault();
        }
        return int(float(MeasureTextEx(font, words, f32(height), f32(0.0)).x) + 0.999);
    }

    def clip(area: Rect) {
        if self.clipped {
            if area.same(self.clip_area) {
                return;
            }
            EndScissorMode();
        }
        BeginScissorMode(i32(area.x), i32(area.y), i32(max(0, area.w)), i32(max(0, area.h)));
        self.clipped = True;
        self.clip_area = area;
    }

    def copied -> str {
        return GetClipboardText();
    }

    def keep_picture(key: str, width: int, height: int, rgba: bytes) {
        if width <= 0 or height <= 0 or len(rgba) < width * height * 4 {
            return;
        }
        old = self.pictures.get(key, 0);
        if old != 0 {
            rlUnloadTexture(u32(old));
        }
        # 7 is eight bits each of red, green, blue and alpha.
        self.pictures[key] = int(rlLoadTexture(rgba, i32(width), i32(height), i32(7), i32(1)));
        self.sizes[key] = [width, height];
    }

    def keep_encoded(key: str, extension: str, data: bytes) -> bool {
        if len(data) == 0 {
            return False;
        }
        image = LoadImageFromMemory(extension, data, i32(len(data)));
        if image.data == u64(0) {
            return False;
        }
        gpu = LoadTextureFromImage(image);
        self.sizes[key] = [int(image.width), int(image.height)];
        UnloadImage(image);
        if gpu.id == u32(0) {
            return False;
        }
        old = self.pictures.get(key, 0);
        if old != 0 {
            rlUnloadTexture(u32(old));
        }
        self.pictures[key] = int(gpu.id);
        return True;
    }

    def picture_size(key: str) -> list[int] {
        return self.sizes.get(key, [0, 0]);
    }

    def has_picture(key: str) -> bool {
        return self.pictures.get(key, 0) != 0;
    }

    def picture(key: str, area: Rect, alpha: int = 255) -> bool {
        known = self.pictures.get(key, 0);
        if known == 0 {
            return False;
        }
        left = f32(area.x);
        top = f32(area.y);
        right = f32(area.x + area.w);
        bottom = f32(area.y + area.h);
        rlSetTexture(u32(known));
        rlBegin(i32(7));
        rlColor4ub(u8(255), u8(255), u8(255), u8(max(0, min(255, alpha))));
        rlTexCoord2f(f32(0.0), f32(0.0));
        rlVertex2f(left, top);
        rlTexCoord2f(f32(0.0), f32(1.0));
        rlVertex2f(left, bottom);
        rlTexCoord2f(f32(1.0), f32(1.0));
        rlVertex2f(right, bottom);
        rlTexCoord2f(f32(1.0), f32(0.0));
        rlVertex2f(right, top);
        rlEnd();
        rlSetTexture(u32(0));
        return True;
    }

    def copy(words: str) {
        SetClipboardText(words);
    }

    def unclip {
        if self.clipped {
            EndScissorMode();
            self.clipped = False;
        }
    }
}

def:priv screen_color(color: Ink) -> Color {
    return Color(r=u8(color.r), g=u8(color.g), b=u8(color.b), a=u8(color.a));
}
