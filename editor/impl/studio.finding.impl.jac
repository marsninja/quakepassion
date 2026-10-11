"""The studio's finding: tags hung on the explorer's files, and what there
is to know of a texture. Declarations live in studio.jac."""

impl Studio.tags_path -> str {
    return override_folder() + "/asset_tags.txt";
}

impl Studio.read_tags {
    if self.tags_read {
        return;
    }
    self.tags_read = True;
    try {
        with open(self.tags_path(), "r") as file {
            self.asset_tags = tags_from(file.read());
        }
    } except OSError {
        self.asset_tags = {};
    }
}

impl Studio.finding_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_assettag" {
        self.read_tags();
        shown = self.asset_now;
        how = args[1] if len(args) > 1 else "";
        if how == "list" or (not how and shown is None) {
            for key in sorted(list(self.asset_tags.keys())) {
                print("studio: tagged " + key + " " + " ".join(self.asset_tags[key]));
            }
            self.say(str(len(self.asset_tags)) + " files have tags (ed_assetfind tag:<word> finds them)");
            return True;
        }
        if shown is None or shown.kind == "figure" {
            self.say("ed_assettag <word> | drop <word> | list: show a file in the explorer first");
            return True;
        }
        key = shown.game + ":" + shown.name;
        if how {
            word = args[2] if how == "drop" and len(args) > 2 else how;
            after = tags_with(self.asset_tags, key, word, how != "drop");
            if after == self.asset_tags {
                self.say("A tag is one word, and this changes nothing: " + word);
                return True;
            }
            self.asset_tags = after;
            try {
                os.makedirs(os.path.dirname(self.tags_path()), exist_ok=True);
                with open(self.tags_path(), "w") as file {
                    file.write(tags_text(after));
                }
            } except OSError {
                self.say("The tags could not be kept in " + self.tags_path());
            }
            self.folds += 1;
        }
        had = self.asset_tags.get(key, []);
        print("studio: tags " + key + " " + (" ".join(had) if len(had) > 0 else "none"));
        self.say(shown.name + ": " + (" ".join(had) if len(had) > 0 else "no tags"));
        return True;
    }
    if name != "ed_texinfo" {
        return False;
    }
    wanted = args[1] if len(args) > 1 else self.material;
    stock = self.archive;
    image = self.materials.texture(wanted);
    words = "size=" + str(image.width) + "x" + str(image.height);
    said = str(image.width) + " by " + str(image.height);
    frames: list[str] = [wanted];
    if wanted.startswith("q2:") {
        facts = wal_facts(self.wal_bytes(wanted));
        if facts is not None {
            words += " flags=" + bits_named("q2", "flags", facts.flags).replace(" ", ",") + " contents="
                + bits_named("q2", "contents", facts.contents).replace(" ", ",") + " value=" + str(facts.value) + " next="
                + (facts.next_name if facts.next_name else "none");
            said += "; flags " + bits_named("q2", "flags", facts.flags) + "; contents " + bits_named("q2", "contents", facts.contents);
        }
        # Each names the one shown after it, until the chain comes round.
        frames = [];
        at = wanted;
        while at and at not in frames and len(frames) < 32 {
            link = wal_facts(self.wal_bytes(at));
            if link is None {
                break;
            }
            frames.append(at);
            at = "q2:" + link.next_name if link.next_name else "";
        }
        if len(frames) == 0 {
            frames = [wanted];
        }
    } elif wanted.startswith("q1:") and stock is not None {
        frames = quake_frames(stock.names("q1:" + wanted[3:].split("/")[0]), wanted);
    } elif wanted.startswith("q3:") {
        scripted = False;
        try {
            if stock is not None {
                scripted = wanted[3:] in stock.reader().catalog.source("q3").pk3.shaders;
            }
        } except Exception {
            scripted = False;
        }
        words += " shader=" + ("1" if scripted else "0");
        said += "; " + ("drawn by a shader script" if scripted else "a plain image");
    }
    words += " frames=" + str(len(frames));
    if len(image.rgba) > 0 {
        used = colours_used(image.rgba);
        words += " colours=" + str(used[0]) + " clear=" + str(used[1]);
        said += "; " + str(used[0]) + " colours" + (", " + str(used[1]) + " texels clear" if used[1] > 0 else "");
    }
    if len(frames) > 1 {
        said += "; one of " + str(len(frames)) + " frames";
    }
    print("studio: texinfo " + wanted + " " + words);
    self.say(wanted + ": " + said);
    return True;
}
