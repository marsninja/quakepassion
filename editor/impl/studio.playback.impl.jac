"""How the explorer's model is offered and drawn: how fast, which frames,
with frames between; with or without the faces turned away; every point
ticked; and its box kept as a part. Declarations live in studio.jac."""

def:priv play_numbers(words: list[str]) -> list[float] {
    found: list[float] = [];
    for word in words {
        try {
            found.append(float(word));
        } except ValueError {
            return found;
        }
    }
    return found;
}

impl Studio.playview_words -> str {
    return "studio: modelview fps=" + str(round(self.model_rate, 1)) + " range=" + str(self.model_first) + ".."
        + str(self.model_last) + " loops=" + ("1" if self.model_loops else "0") + " smooth="
        + ("1" if self.model_smooth else "0") + (" between=" + str(self.model_between) if self.model_between > 0 else "")
        + " backs=" + ("1" if self.model_backs else "0") + " ticks="
        + str(round(self.model_ticks, 1)) + " edges=" + str(len(self.model_edges));
}

impl Studio.shown_edges(frame: int) -> list[list[Vec3]] {
    figure = self.model_now;
    if figure is None {
        return [];
    }
    if self.model_backs {
        return figure.edges(frame);
    }
    # Only the triangles that face the eye.
    return facing_edges(figure.model, frame, self.model_camera.eye);
}

impl Studio.play_model(dt: float) {
    figure = self.model_now;
    if figure is None {
        return;
    }
    if not self.model_playing {
        if not self.model_backs {
            # The eye may have moved: what faces it is found again.
            self.model_edges = self.shown_edges(self.model_frame);
        }
        return;
    }
    pace = 1.0 / max(0.5, self.model_rate);
    self.model_clock += dt;
    if self.model_clock >= pace {
        self.model_clock = 0.0;
        self.set_frame(frame_after(self.model_frame, self.model_first, self.model_last, figure.frames, self.model_loops));
    }
    if self.model_smooth or not self.model_backs {
        coming = frame_after(self.model_frame, self.model_first, self.model_last, figure.frames, self.model_loops);
        self.model_edges = edges_between(
            self.shown_edges(self.model_frame), self.shown_edges(coming),
            share_stepped(self.model_clock / pace, self.model_between) if self.model_smooth else 0.0
        );
    }
}

impl Studio.draw_model_ticks {
    figure = self.model_now;
    if figure is None or self.model_ticks <= 0.0 {
        return;
    }
    reach = max(0.25, self.model_reach * 0.004 * self.model_ticks);
    drawn = 0;
    for surface in figure.model.surfaces {
        if len(surface.frames) == 0 {
            continue;
        }
        for point in surface.frames[max(0, min(self.model_frame, len(surface.frames) - 1))].vertices {
            if drawn >= 6000 {
                return;
            }
            self.draw_mark(point, reach, ink(0x4cc38a));
            drawn += 1;
        }
    }
}

impl Studio.playview_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    how = args[1] if len(args) > 1 else "";
    numbers = play_numbers(args[2:]);
    if name == "ed_frame" and how == "clip" {
        figure = self.model_now;
        stock = self.archive;
        pieces = figure.name.split("/") if figure is not None else [];
        if figure is None or stock is None or figure.game != "q3" or len(pieces) != 4 or pieces[1].lower() != "players"
            or pieces[3].lower() not in ["lower.md3", "upper.md3"] {
            self.say("ed_frame clip <sequence|list>: show the lower.md3 or upper.md3 of one of Quake III's players first");
            return True;
        }
        known = self.asset_index;
        if known is None {
            known = AssetIndex(shelf=stock);
            self.asset_index = known;
        }
        table = known.read("q3", "/".join(pieces[:3]) + "/animation.cfg");
        table_rows = animation_settings(table.decode("utf-8")).frames if table is not None else [];
        legs = pieces[3].lower() == "lower.md3";
        word = args[2] if len(args) > 2 else "list";
        if word not in SEQUENCES {
            offered = [each for (number, each) in enumerate(SEQUENCES) if sequence_range(table_rows, number, legs) is not None];
            print("studio: clips " + pieces[2] + " " + ("legs" if legs else "torso") + ": " + " ".join(offered));
            self.say(
                "Its sequences: " + " ".join(offered) if len(offered) > 0 else pieces[2] + " has no table of sequences (animation.cfg)"
            );
            return True;
        }
        span = sequence_range(table_rows, SEQUENCES.index(word), legs);
        if span is None {
            self.say(("The legs do not play " if legs else "The torso does not play ") + word);
            return True;
        }
        self.model_first = int(span[0]);
        self.model_last = int(span[1]);
        self.model_rate = span[2];
        self.model_loops = span[3] > 0.0;
        self.set_frame(self.model_first);
        print(
            "studio: clip " + word + " frames=" + str(self.model_first) + ".." + str(self.model_last) + " fps="
                + str(round(self.model_rate, 1)) + " loops=" + ("1" if self.model_loops else "0")
        );
        self.say(
            word + ": frames " + str(self.model_first) + " to " + str(self.model_last) + " at " + str(round(self.model_rate, 1))
                + " a second" + ("" if self.model_loops else ", once")
        );
        return True;
    }
    if name == "ed_frame" and how in ["fps", "range", "smooth", "once", "loop"] {
        figure = self.model_now;
        if how == "fps" and len(numbers) > 0 {
            self.model_rate = max(0.5, min(120.0, numbers[0]));
        } elif how == "range" and len(numbers) >= 2 {
            self.model_first = int(numbers[0]);
            self.model_last = int(numbers[1]);
            if figure is not None and (self.model_frame < self.model_first or self.model_frame > self.model_last) {
                self.set_frame(frame_after(self.model_frame, self.model_first, self.model_last, figure.frames));
            }
        } elif how == "range" and len(args) > 2 and args[2] == "all" {
            self.model_first = 0;
            self.model_last = -1;
        } elif how == "smooth" and len(args) > 2 and args[2] in ["on", "off"] {
            self.model_smooth = args[2] == "on";
            self.model_between = 0;
        } elif how == "smooth" and len(numbers) > 0 {
            # So many frames drawn between one frame and the next, and no more.
            self.model_between = max(0, min(16, int(numbers[0])));
            self.model_smooth = self.model_between > 0;
        } elif how == "once" or how == "loop" {
            self.model_loops = how == "loop";
        } else {
            self.say("ed_frame fps <n> | range <first> <last>|all | smooth on|off|<frames between> | once | loop | clip <sequence|list>");
            return True;
        }
        print(self.playview_words());
        self.say(
            "Frames " + (str(self.model_first) + " to " + str(self.model_last) if self.model_last >= 0 else "all") + " at "
                + str(round(self.model_rate, 1)) + " a second" + (
                    ", with " + (str(self.model_between) + " " if self.model_between > 0 else "") + "frames between"
                    if self.model_smooth
                    else ""
                )
                + ("" if self.model_loops else ", once")
        );
        return True;
    }
    if name == "ed_model" and how in ["backs", "ticks", "boxpart"] {
        if how == "backs" and len(args) > 2 and args[2] in ["on", "off"] {
            self.model_backs = args[2] == "on";
            self.model_edges = self.shown_edges(self.model_frame);
        } elif how == "ticks" and (len(numbers) > 0 or (len(args) > 2 and args[2] == "off")) {
            self.model_ticks = max(0.0, min(16.0, numbers[0])) if len(numbers) > 0 else 0.0;
        } elif how == "boxpart" {
            doc = self.model_doc;
            if doc is None or len(doc.parts()) == 0 {
                self.say("ed_model boxpart: edit a model first (ed_model new <kind>, ed_model edit)");
                return True;
            }
            # Round the whole model at each frame, or round what is picked of the part in hand.
            held_part = doc.part();
            only = len(args) > 2 and args[2] == "picked";
            if only and (held_part is None or len(held_part.picked_points) == 0) {
                self.say("ed_model boxpart picked: pick the points or faces the box goes round first");
                return True;
            }
            # Measured before the box is one of the model's parts.
            boxes: list[list[Vec3]] = [];
            for each in range(doc.frames()) {
                if only and held_part is not None {
                    stood = doc.mesh(held_part, each).points;
                    boxes.append(box_round([stood[index] for index in held_part.picked_points if index < len(stood)]));
                } else {
                    boxes.append(doc.bounds(each));
                }
            }
            kept_part = doc.part_now;
            boxed = doc.add_part("bbox_" + held_part.name if only and held_part is not None else "bbox", box_mesh(boxes[0][0], boxes[0][1]));
            for (place, pose) in enumerate(doc.poses(boxed)) {
                if place < len(boxes) {
                    pose.points = box_corners(boxes[place][0], boxes[place][1]);
                }
            }
            doc.part_now = kept_part;
            doc.revision += 1;
            print(
                "studio: boxpart frames=" + str(len(boxes)) + " low=" + str(int(round(boxes[0][0].x))) + ","
                    + str(int(round(boxes[0][0].y))) + "," + str(int(round(boxes[0][0].z))) + " high="
                    + str(int(round(boxes[0][1].x))) + "," + str(int(round(boxes[0][1].y))) + ","
                    + str(int(round(boxes[0][1].z)))
            );
            self.say(
                ("The box round what is picked" if only else "The model's box") + " at each of its " + str(len(boxes))
                    + " frames is kept as a part named " + boxed.name
            );
            return True;
        } else {
            self.say("ed_model backs on|off | ticks <size>|off | boxpart [picked]");
            return True;
        }
        print(self.playview_words());
        self.say(
            ("Every face is drawn" if self.model_backs else "Faces turned away are not drawn") + "; "
                + ("every point is ticked" if self.model_ticks > 0.0 else "points are not ticked")
        );
        return True;
    }
    return False;
}
