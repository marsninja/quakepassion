"""Folders of image files used as materials where they lie, and lists of
materials kept by name. Declarations live in studio.jac."""

impl Studio.all_links -> dict[str, str] {
    both: dict[str, str] = {};
    for link in self.tex_links.keys() {
        both[link] = self.tex_links[link];
    }
    project = self.project;
    if project is not None {
        # The project's own have the last word on a name.
        for link in project.links.keys() {
            both[link] = project.links[link];
        }
    }
    return both;
}

impl Studio.all_lists -> dict[str, list[str]] {
    both: dict[str, list[str]] = {};
    for kept in self.tex_lists.keys() {
        both[kept] = self.tex_lists[kept];
    }
    project = self.project;
    if project is not None {
        for kept in project.lists.keys() {
            both[kept] = project.lists[kept];
        }
    }
    return both;
}

impl Studio.texlink_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name != "ed_texlink" and name != "ed_texlist" {
        return False;
    }
    project = self.project;
    stock = self.archive;
    first = args[1] if len(args) > 1 else "";
    if name == "ed_texlink" {
        links = self.all_links();
        if not first {
            for link in sorted(links.keys()) {
                held = len(stock.extra_names("link:" + link)) if stock is not None else 0;
                print("studio: texlink " + link + " " + links[link] + " materials=" + str(held));
            }
            self.say(
                "Folders linked to: " + ", ".join(sorted(links.keys()))
                if links
                else "No folder is linked to (ed_texlink <name> <folder>: its image files become materials where they lie)"
            );
            return True;
        }
        if first == "drop" {
            sought = file_name(args[2]).lower() if len(args) > 2 else "";
            if project is not None and sought in project.links {
                project.links.pop(sought, None);
                self.save_project();
            } elif sought in self.tex_links {
                self.tex_links.pop(sought, None);
                self.keep_settings();
            } else {
                self.say("ed_texlink drop <name>: no folder is linked to by that name");
                return True;
            }
            self.sync_addons();
            self.say("The link " + sought + " is dropped: its folder is as it was");
            return True;
        }
        called = file_name(first).lower();
        folder = " ".join(args[2:]).strip().rstrip("/");
        if not called or not folder {
            self.say("ed_texlink <name> <folder> | drop <name>");
            return True;
        }
        whole = folder if folder.startswith("/") or project is None else self.project_folder + "/" + folder;
        if not os.path.isdir(whole) {
            self.say("ed_texlink: there is no folder " + whole);
            return True;
        }
        if project is not None {
            # The project's own: named in its manifest, to come with it.
            project.links[called] = folder;
            self.save_project();
        } else {
            self.tex_links[called] = os.path.abspath(whole);
            self.keep_settings();
        }
        self.sync_addons();
        count = len(stock.extra_names("link:" + called)) if stock is not None else 0;
        print("studio: texlink " + called + " " + folder + " materials=" + str(count));
        self.say(
            str(count) + " materials linked to as link:" + called + "/... (nothing is copied)"
            if count > 0
            else "Linked to " + folder + ", which holds no image files yet"
        );
        return True;
    }
    lists = self.all_lists();
    if not first {
        for kept in sorted(lists.keys()) {
            print("studio: texlist " + kept + " " + str(len(lists[kept])) + " " + " ".join(lists[kept]));
        }
        self.say(
            "Lists of materials: " + ", ".join(sorted(lists.keys()))
            if lists
            else "No list is kept (ed_texlist <name> add: puts the material in hand on a list)"
        );
        return True;
    }
    called = file_name(first).lower();
    how = args[2] if len(args) > 2 else "";
    if not called or how not in ["", "add", "drop", "remove"] {
        self.say("ed_texlist <name> [add|drop [material ...] | remove]");
        return True;
    }
    if not how {
        if called not in lists {
            self.say("There is no list called " + called + " (ed_texlist " + called + " add makes it)");
            return True;
        }
        self.shelf = "list:" + called;
        self.materials_changed += 1;
        return True;
    }
    # A project's lists are the project's; the others are the studio's own.
    held_in = project.lists if project is not None else self.tex_lists;
    if how == "remove" {
        if called not in held_in {
            self.say("ed_texlist " + called + " remove: no such list" + (" in the project" if project is not None else ""));
            return True;
        }
        held_in.pop(called, None);
        if self.shelf == "list:" + called {
            self.shelf = "scene";
        }
    } else {
        named = args[3:] if len(args) > 3 else [self.material];
        row = list(held_in.get(called, []));
        for material in named {
            if how == "add" and material and material not in row {
                row.append(material);
            } elif how == "drop" and material in row {
                row.remove(material);
            }
        }
        held_in[called] = row;
        print("studio: texlist " + called + " " + str(len(row)) + " " + " ".join(row));
    }
    if project is not None {
        self.save_project();
    } else {
        self.keep_settings();
    }
    self.materials_changed += 1;
    self.say(
        "The list " + called + " is removed" if how == "remove"
        else "The list " + called + " holds " + str(len(held_in.get(called, []))) + " materials"
    );
    return True;
}
