"""The studio's table of the Passion districts' materials: listed, a slot
given another material, a district another name, checked against the
archives, and put back. Declarations live in studio.jac."""

impl Studio.keep_districts(table: DistrictTable) -> bool {
    path = districts_path();
    try {
        os.makedirs(os.path.dirname(path), exist_ok=True);
        with open(path, "w") as file {
            file.write(table_text(table));
        }
    } except OSError {
        self.say("The districts could not be written to " + path);
        return False;
    }
    return True;
}

impl Studio.district_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_district" {
        return False;
    }
    table = kept_table();
    how = args[1] if len(args) > 1 else "";
    if not how or how == "list" {
        for (index, district) in enumerate(table.slots) {
            words = "studio: district " + str(index) + " " + table.names[index].replace(" ", "_");
            for (slot, spec) in enumerate(district) {
                words += " " + SLOT_NAMES[slot] + "=" + material_word(spec);
            }
            print(words);
        }
        self.say(str(len(table.slots)) + " districts of " + str(len(SLOT_NAMES)) + " slots: " + ", ".join(table.names));
        return True;
    }
    if how == "reset" {
        plain = district_table();
        if len(args) > 2 and args[2].isdigit() and int(args[2]) < len(table.slots) {
            # One district alone goes back to what it was built with.
            table.names[int(args[2])] = plain.names[int(args[2])];
            table.slots[int(args[2])] = plain.slots[int(args[2])];
            if self.keep_districts(table) {
                self.say(plain.names[int(args[2])] + " has its own materials again");
            }
            return True;
        }
        try {
            if os.path.isfile(districts_path()) {
                os.remove(districts_path());
            }
            self.say("Every district has its own materials again");
        } except OSError {
            self.say("The districts' file could not be taken away");
        }
        return True;
    }
    stock = self.archive;
    if how == "check" {
        if stock is None {
            self.say("No game archives were found");
            return True;
        }
        missing = 0;
        reader = stock.reader();
        for (index, district) in enumerate(table.slots) {
            for (slot, spec) in enumerate(district) {
                try {
                    image = reader.load(spec);
                    if image.width <= 0 and len(image.encoded) == 0 {
                        missing += 1;
                        print("studio: district slot " + str(index) + " " + SLOT_NAMES[slot] + " " + material_word(spec) + " missing");
                    }
                } except Exception {
                    missing += 1;
                    print("studio: district slot " + str(index) + " " + SLOT_NAMES[slot] + " " + material_word(spec) + " missing");
                }
            }
        }
        # What a level is made with, through the game's own way in.
        try {
            made_with = load_materials(stock.directory);
            for index in range(len(table.slots)) {
                print(
                    "studio: district loads " + str(index) + " "
                        + " ".join([made_with[index * len(SLOT_NAMES) + slot].name for slot in range(len(SLOT_NAMES))])
                );
            }
        } except Exception {
            print("studio: district loads nothing");
        }
        print("studio: districts missing=" + str(missing));
        self.say("Every slot's material is there" if missing == 0 else str(missing) + " slots name materials that are not there: levels use the built-in ones for those");
        return True;
    }
    if not how.isdigit() or int(how) >= len(table.slots) or len(args) < 3 {
        self.say(
            "ed_district [list] | <0-" + str(len(table.slots) - 1) + "> <" + "|".join(SLOT_NAMES)
                + "> [material] | <n> name <words> | check | reset [n]"
        );
        return True;
    }
    number = int(how);
    what = args[2];
    if what == "name" and len(args) > 3 {
        table.names[number] = " ".join(args[3:]);
        if self.keep_districts(table) {
            print("studio: district " + str(number) + " name " + table.names[number].replace(" ", "_"));
            self.say("District " + str(number) + " is called " + table.names[number]);
        }
        return True;
    }
    if what not in SLOT_NAMES {
        self.say("A district's slots are " + ", ".join(SLOT_NAMES));
        return True;
    }
    word = args[3] if len(args) > 3 else self.material;
    wanted_spec = material_spec(word);
    if wanted_spec is None {
        self.say("A slot takes a game's own texture (q1:<map>/<name>, q2:<name>, q3:<name>), not " + word);
        return True;
    }
    found_it = False;
    if stock is not None {
        try {
            image = stock.reader().load(wanted_spec);
            found_it = image.width > 0 or len(image.encoded) > 0;
        } except Exception {
            found_it = False;
        }
    }
    if not found_it {
        self.say("There is no material " + word + " in the archives");
        return True;
    }
    table.slots[number][SLOT_NAMES.index(what)] = wanted_spec;
    if self.keep_districts(table) {
        print("studio: district " + str(number) + " " + what + " " + word);
        self.say(table.names[number] + " takes " + word + " for its " + what);
    }
    return True;
}
