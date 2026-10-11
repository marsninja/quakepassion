"""Sounds brought in and converted, a Quake II texture's own facts read and
changed, and the frames of animated textures. Declarations live in
studio.jac."""

impl Studio.sound_path(name: str) -> str {
    if name.startswith("/") {
        return name;
    }
    folder = os.getenv("QP_SOUNDS", "");
    if self.project_folder {
        folder = self.project_folder + "/sounds";
    } elif not folder {
        folder = os.getcwd() + "/sounds";
    }
    return folder + "/" + (name if name.lower().endswith(".wav") else name + ".wav");
}

impl Studio.wal_bytes(source: str) -> bytes {
    # A file on disk, or a Quake II material by its name in the archives.
    if os.path.isfile(source) {
        try {
            with open(source, "rb") as file {
                return file.read();
            }
        } except OSError {
            return b"";
        }
    }
    known = self.asset_index;
    stock = self.archive;
    if known is None and stock is not None {
        known = AssetIndex(shelf=stock);
        self.asset_index = known;
    }
    if known is not None and source.startswith("q2:") {
        found = known.read("q2", "textures/" + source[3:] + ".wal");
        if found is not None {
            return found;
        }
    }
    return b"";
}

impl Studio.sound_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    how = args[1] if len(args) > 1 else "";
    if name == "ed_sound" {
        if (how != "info" and how != "convert") or len(args) < 3 {
            self.say("ed_sound info <file> | convert <file> <name> [rate] [bits] [loud]: a WAV made one channel at the games' rates");
            return True;
        }
        data = b"";
        try {
            with open(args[2], "rb") as file {
                data = file.read();
            }
        } except OSError {
            self.say("ed_sound: could not read " + args[2]);
            return True;
        }
        if how == "info" {
            print("studio: sound " + args[2].split("/")[-1] + " " + sound_facts(data));
            self.say(sound_facts(data));
            return True;
        }
        if len(args) < 4 {
            self.say("ed_sound convert <file> <name> [rate] [bits] [loud]");
            return True;
        }
        rate = int(args[4]) if len(args) > 4 and args[4].isdigit() else 22050;
        bits = 8 if len(args) > 5 and args[5] == "8" else 16;
        made = converted_sound(data, max(4000, min(48000, rate)), bits, len(args) > 6 and args[6] == "loud");
        if len(made) == 0 {
            self.say("That is not a WAV of plain samples: " + sound_facts(data));
            return True;
        }
        path = self.sound_path(args[3]);
        try {
            os.makedirs(os.path.dirname(path), exist_ok=True);
            with open(path, "wb") as file {
                file.write(made);
            }
        } except OSError {
            self.say("ed_sound: could not write " + path);
            return True;
        }
        print("studio: sound " + os.path.basename(path) + " " + sound_facts(made) + " from " + sound_facts(data));
        self.say("Wrote " + path + ": " + sound_facts(made));
        return True;
    }
    if name == "ed_frames" {
        wanted = how if how else self.material;
        stock = self.archive;
        frames: list[str] = [wanted];
        if wanted.startswith("q1:") and stock is not None {
            group = "q1:" + wanted[3:].split("/")[0];
            frames = quake_frames(stock.names(group), wanted);
        } elif wanted.startswith("q2:") {
            # Each names the one shown after it, until the chain comes round.
            frames = [];
            at = wanted;
            while at and at not in frames and len(frames) < 32 {
                facts = wal_facts(self.wal_bytes(at));
                if facts is None {
                    break;
                }
                frames.append(at);
                at = "q2:" + facts.next_name if facts.next_name else "";
            }
            if len(frames) == 0 {
                frames = [wanted];
            }
        }
        print("studio: frames " + str(len(frames)) + " " + " ".join(frames));
        self.say(
            wanted + " is one of " + str(len(frames)) + " frames: " + ", ".join(frames)
            if len(frames) > 1
            else wanted + " is not animated"
        );
        return True;
    }
    if name != "ed_wal" {
        return False;
    }
    if not how {
        self.say("ed_wal <file.wal|q2:name> [flag <name> on|off] [flags|contents|value <number>] [next <name>|none]");
        return True;
    }
    data = self.wal_bytes(how);
    facts = wal_facts(data);
    if facts is None {
        self.say("ed_wal: " + how + " is not a Quake II texture this can read");
        return True;
    }
    changed = False;
    index = 2;
    while index + 1 < len(args) {
        word = args[index];
        value = args[index + 1];
        if word == "flag" and index + 2 < len(args) {
            facts.flags = flag_named(facts.flags, value, args[index + 2] == "on");
            index += 3;
        } elif word in ["flags", "contents", "value"] and value.lstrip("-").isdigit() {
            if word == "flags" {
                facts.flags = int(value);
            } elif word == "contents" {
                facts.contents = int(value);
            } else {
                facts.value = int(value);
            }
            index += 2;
        } elif word == "next" {
            facts.next_name = "" if value == "none" else value;
            index += 2;
        } else {
            self.say("ed_wal ... [flag <name> on|off] [flags|contents|value <number>] [next <name>|none]");
            return True;
        }
        changed = True;
    }
    if changed {
        # Written among the project's own textures, by its own name.
        stock = self.archive;
        folder = stock.files_folder() if stock is not None else os.getcwd() + "/textures";
        path = folder + "/" + facts.name + ".wal";
        try {
            os.makedirs(os.path.dirname(path), exist_ok=True);
            with open(path, "wb") as file {
                file.write(wal_with(data, facts.flags, facts.contents, facts.value, facts.next_name));
            }
        } except OSError {
            self.say("ed_wal: could not write " + path);
            return True;
        }
        print("studio: wal wrote " + path);
    }
    print(
        "studio: wal name=" + facts.name + " size=" + str(facts.width) + "x" + str(facts.height) + " flags=" + str(facts.flags)
            + " names=" + (",".join(flag_names(facts.flags)) if facts.flags else "-") + " contents=" + str(facts.contents)
            + " value=" + str(facts.value) + " next=" + (facts.next_name if facts.next_name else "-")
    );
    self.say(
        facts.name + ": " + str(facts.width) + " by " + str(facts.height) + ", flags " + (", ".join(flag_names(facts.flags)) if facts.flags else "none")
            + ", contents " + str(facts.contents) + ", value " + str(facts.value) + (", then " + facts.next_name if facts.next_name else "")
    );
    return True;
}
