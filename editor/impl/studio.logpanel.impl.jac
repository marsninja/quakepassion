"""The studio's log panel: the console's last lines kept in sight along the
foot of the level views, and scrolled back through. Declarations live in
studio.jac."""

impl Studio.log_area -> Rect {
    # Along the foot of the level views that are showing, across all of them.
    left = 0;
    right = 0;
    foot = 0;
    for index in range(min(self.showing(), len(self.ports))) {
        area = self.ports[index].view.area;
        if area.w <= 0 {
            continue;
        }
        if right == 0 {
            left = area.x;
            right = area.x + area.w;
            foot = area.y + area.h;
        }
        left = min(left, area.x);
        right = max(right, area.x + area.w);
        foot = max(foot, area.y + area.h);
    }
    tall = self.log_rows * 16 + 22;
    return Rect(x=left, y=foot - tall, w=right - left, h=tall);
}

impl Studio.log_said -> list[str] {
    app = self.app;
    return app.shell.log.lines if app is not None else [];
}

impl Studio.draw_log_panel {
    if not self.log_panel {
        return;
    }
    canvas = self.canvas;
    area = self.log_area();
    if area.w <= 0 {
        return;
    }
    said = self.log_said();
    self.log_back = max(0, min(self.log_back, log_reach(len(said), self.log_rows)));
    canvas.clip(area);
    canvas.fill(area, canvas.theme.header.faded(246));
    canvas.fill(Rect(x=area.x, y=area.y, w=area.w, h=1), canvas.theme.accent);
    title = "Log   " + str(len(said)) + " lines";
    if self.log_back > 0 {
        title += "   " + str(self.log_back) + " back (ed_log panel end)";
    }
    canvas.text(title, area.x + 8, area.y + 4, canvas.theme.dim, canvas.theme.small);
    letters = max(8, (area.w - 16) // max(1, canvas.text_width("n", canvas.theme.small)));
    row = 0;
    for line in log_window(said, self.log_rows, self.log_back) {
        canvas.text(log_fitted(line, letters), area.x + 8, area.y + 20 + row * 16, canvas.theme.text, canvas.theme.small);
        row += 1;
    }
    canvas.unclip();
}

impl Studio.log_panel_words -> str {
    said = self.log_said();
    held = log_window(said, self.log_rows, self.log_back);
    return "studio: logpanel rows=" + str(self.log_rows) + " lines=" + str(len(said)) + " back=" + str(self.log_back)
        + " shown=" + str(len(held)) + " last=" + (held[-1].replace(" ", "_")[:60] if len(held) > 0 else "");
}

impl Studio.logpanel_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_log" or len(args) < 2 or args[1] != "panel" {
        return False;
    }
    word = args[2] if len(args) > 2 else "";
    reach = log_reach(len(self.log_said()), self.log_rows);
    was_open = self.log_panel;
    was_rows = self.log_rows;
    if word in ["", "on", "off"] {
        self.log_panel = (not self.log_panel) if not word else word == "on";
        if len(args) > 3 and args[3].isdigit() {
            self.log_rows = max(2, min(24, int(args[3])));
        }
        self.log_back = 0;
    } elif word.isdigit() {
        self.log_rows = max(2, min(24, int(word)));
        self.log_panel = True;
        self.log_back = 0;
    } elif word in ["up", "down"] {
        notches = self.log_rows - 1;
        if len(args) > 3 and args[3].isdigit() {
            notches = int(args[3]);
        }
        self.log_back = max(0, min(reach, self.log_back + (notches if word == "up" else -notches)));
        self.log_panel = True;
        return True;
    } elif word == "end" {
        self.log_back = 0;
        return True;
    } else {
        self.say("ed_log panel [on|off] [rows] | <rows> | up [n] | down [n] | end");
        return True;
    }
    if self.log_panel == was_open and self.log_rows == was_rows {
        # As it was: nothing to say, and nothing to keep.
        return True;
    }
    self.keep_settings();
    self.say(
        "The console's last " + str(self.log_rows) + " lines stay along the foot of the views (ed_log panel up, down, end)"
        if self.log_panel
        else "The log panel is put away"
    );
    return True;
}
