"""The studio's archives changed in place: a PAK's or a PK3's files listed,
one put in or put in place of another, one or a folder dropped.
Declarations live in studio.jac."""

"""The files an archive on disk holds. None when it is not one this reads."""
def:priv archive_read(path: str) -> list[tuple[str, bytes]] | None {
    try {
        if path.lower().endswith(".pak") {
            data = b"";
            with open(path, "rb") as file {
                data = file.read();
            }
            return pak_files(data);
        }
        return zip_files(path);
    } except Exception {
        return None;
    }
}

impl Studio.archive_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_pack" or len(args) < 2 or args[1] not in ["add", "drop", "list"] {
        return False;
    }
    how = args[1];
    path = args[2] if len(args) > 2 else "";
    is_pak = path.lower().endswith(".pak");
    if not (is_pak or path.lower().endswith(".pk3")) {
        self.say("ed_pack list <archive.pak|.pk3> | add <archive> <file> [name inside] | drop <archive> <name, or folder/>");
        return True;
    }
    held: list[tuple[str, bytes]] = [];
    if os.path.isfile(path) {
        read = archive_read(path);
        if read is None {
            self.say("ed_pack: " + path + " is not an archive this reads");
            return True;
        }
        held = read;
    } elif how != "add" {
        self.say("ed_pack: no such archive " + path);
        return True;
    }
    label = os.path.basename(path);
    if how == "list" {
        total = 0;
        for (inner, data) in held {
            total += len(data);
        }
        print("studio: archive " + label + " files=" + str(len(held)) + " bytes=" + str(total));
        for (inner, data) in held[:60] {
            print("studio: packed " + inner + " " + str(len(data)));
        }
        self.say(label + " holds " + str(len(held)) + " files, " + str(total) + " bytes");
        return True;
    }
    if lies_in(path, [game_directory(game) for game in ["q1", "q2", "q3"]]) {
        # A game's own archives are left as they are.
        print("studio: archive " + label + " refused");
        self.say("ed_pack: " + label + " is one of a game's own archives; copy it and change the copy");
        return True;
    }
    after = held;
    named = "";
    if how == "add" {
        if len(args) < 4 or not os.path.isfile(args[3]) {
            self.say("ed_pack add <archive> <file> [name inside]: no such file " + (args[3] if len(args) > 3 else ""));
            return True;
        }
        fresh = b"";
        with open(args[3], "rb") as file {
            fresh = file.read();
        }
        named = args[4] if len(args) > 4 else os.path.basename(args[3]);
        after = files_with(held, named, fresh);
    } else {
        if len(args) < 4 {
            self.say("ed_pack drop <archive> <name, or folder/>");
            return True;
        }
        named = args[3];
        after = files_without(held, named);
        if len(after) == len(held) {
            self.say("Nothing in " + label + " is called " + named);
            return True;
        }
    }
    packed = b"";
    try {
        packed = write_pak(after) if is_pak else write_zip(after);
    } except ValueError as error {
        self.say(str(error));
        return True;
    }
    # Written beside it and put in its place, so a write cut short leaves the archive as it was.
    try {
        folder = os.path.dirname(path);
        if folder {
            os.makedirs(folder, exist_ok=True);
        }
        with open(path + ".new", "wb") as file {
            file.write(packed);
        }
        os.replace(path + ".new", path);
    } except OSError {
        self.say("ed_pack: could not write " + path);
        return True;
    }
    print(
        "studio: archive " + label + " files=" + str(len(after)) + " bytes=" + str(len(packed)) + " " + how + "=" + named
            + " was=" + str(len(held))
    );
    self.say(
        ("Put " + named + " in " if how == "add" else "Dropped " + named + " from ") + label + ": " + str(len(after))
            + " files now"
    );
    return True;
}
