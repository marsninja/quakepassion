"""Materials that move, played in the browser: a row of frames shown one
after another at its game's pace, and liquids warping. `ed_animate` turns
it on and off; off, every picture is the still one again."""

import from engine.formats.bsp { Texture }
import from editor.document.scene { Scene }
import from editor.assets.materials { small_picture }
import from editor.assets.moving { warps_name, frames_rate, frame_now, warped }
import from editor.tools.host { ToolHost, StudioTool }

obj MovingPictures(StudioTool) {
    has playing: bool = False,
        clock: float = 0.0,
        # Seconds since the pictures were last changed, and how many times they have been.
        since: float = 0.0,
        turns: int = 0,
        # What is known of each material seen: its row of frames (itself
        # alone when it does not move) and whether it warps.
        rows: dict[str, list[str]] = {},
        warping: dict[str, bool] = {},
        # Small pictures by material, and the materials whose picture in
        # the browser is no longer its own.
        small: dict[str, Texture] = {},
        changed: list[str] = [],
        # How many of those listed now move, for the dump.
        moving_now: int = 0,
        warping_now: int = 0;

    def commands -> list[tuple[str, str, str]] {
        return [
            (
                "ed_animate",
                "ed_animate [on|off]",
                "play the materials that move in the browser: a row of frames at its game's pace, and liquids warping"
            )
        ];
    }

    """A material's picture, small, or None when nothing holds it."""
    def little(host: ToolHost, material: str) -> Texture | None {
        if material in self.small {
            return self.small[material];
        }
        whole = host.picture(material);
        if whole is None {
            return None;
        }
        made = small_picture(whole, 64);
        self.small[material] = made;
        return made;
    }

    """Give every changed picture back its own."""
    def still(host: ToolHost) {
        for material in self.changed {
            plain = self.little(host, material);
            if plain is not None {
                host.show_picture(material, plain.width, plain.height, plain.rgba);
            }
        }
        self.changed = [];
    }

    def command(host: ToolHost, scene: Scene, args: list[str]) -> bool {
        if args[0] != "ed_animate" {
            return False;
        }
        word = args[1] if len(args) > 1 else "";
        if word not in ["", "on", "off"] {
            host.say("ed_animate [on|off]");
            return True;
        }
        self.playing = word == "on" or (not word and not self.playing);
        self.since = 1.0;
        if not self.playing {
            self.still(host);
            self.moving_now = 0;
            self.warping_now = 0;
        }
        host.say(
            "Materials that move are played in the browser: rows of frames, and liquids warping"
            if self.playing
            else "Materials are shown still"
        );
        return True;
    }

    def tick(host: ToolHost, dt: float) {
        if not self.playing {
            return;
        }
        self.clock += dt;
        self.since += dt;
        if self.since < 0.1 {
            return;
        }
        self.since = 0.0;
        self.turns += 1;
        moving = 0;
        waves = 0;
        # Only so many are looked up a turn: a game's whole list is long.
        learned = 0;
        for material in host.materials_shown() {
            if material not in self.rows {
                if learned >= 24 {
                    continue;
                }
                learned += 1;
                self.rows[material] = host.frames_of(material);
                self.warping[material] = host.warps(material);
            }
            row = self.rows[material];
            shown: Texture | None = None;
            if self.warping[material] {
                plain = self.little(host, material);
                if plain is not None {
                    shown = Texture(
                        name=material, width=plain.width, height=plain.height, rgba=warped(plain.rgba, plain.width, plain.height, self.clock)
                    );
                    waves += 1;
                }
            } elif len(row) > 1 {
                lead = row.index(material) if material in row else 0;
                shown = self.little(host, row[frame_now(len(row), self.clock, frames_rate(material), lead)]);
                moving += 1;
            }
            if shown is not None {
                host.show_picture(material, shown.width, shown.height, shown.rgba);
                if material not in self.changed {
                    self.changed.append(material);
                }
            }
        }
        self.moving_now = moving;
        self.warping_now = waves;
    }

    def draw_through(host: ToolHost, scene: Scene) {}

    def dump_lines(host: ToolHost, scene: Scene) -> list[str] {
        if not self.playing {
            return [];
        }
        return [
            "studio: moving on=1 rows=" + str(self.moving_now) + " warping=" + str(self.warping_now)
        ];
    }

    def settings_lines(host: ToolHost) -> list[str] {
        return [];
    }
}
