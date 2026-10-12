"""Makers: groups whose brushes stay as they are in the document and are
built as something made from them: a shell of walls, the walls alone, or
an arch. A tool of the studio in a module of its own (see
editor/tools/host.jac); what is built is worked out in
editor/document/generate.jac."""
import from editor.tools.host { ToolHost, StudioTool }
import from editor.document.scene { Scene, Item }
import from editor.document.generate { MAKER_KEYS, makes }

obj Makers(StudioTool) {
    def commands -> list[tuple[str, str, str]] {
        return [
            (
                "ed_maker",
                "ed_maker [hollow <thickness> | walls <thickness> | arch <count> [thickness] | off]",
                "have the selected group (or the selected brushes, as a new group) built as shells of walls, as walls alone or as arches, the brushes themselves kept as they are"
            )
        ];
    }

    def command(host: ToolHost, scene: Scene, args: list[str]) -> bool {
        if args[0] != "ed_maker" {
            return False;
        }
        how = args[1] if len(args) > 1 else "";
        if not how {
            count = 0;
            for item in scene.items() {
                if makes(item.fields) {
                    said = " ".join([key + "=" + item.fields[key].replace(" ", ",") for key in MAKER_KEYS if key in item.fields]);
                    print("studio: maker #" + str(item.serial) + " " + said + " brushes=" + str(len(scene.solids_of(item))));
                    count += 1;
                }
            }
            print("studio: makers " + str(count));
            host.say(str(count) + (" maker" if count == 1 else " makers") + " in the scene" if count > 0 else "No makers: ed_maker hollow|walls|arch <number> on a group");
            return True;
        }
        numbers: list[str] = [];
        for word in args[2:] {
            try {
                float(word);
                numbers.append(word);
            } except ValueError {
                break;
            }
        }
        if how not in ["hollow", "walls", "arch", "off"] or (how != "off" and (len(numbers) == 0 or float(numbers[0]) <= 0.0)) {
            host.say("ed_maker [hollow <thickness> | walls <thickness> | arch <count> [thickness] | off]");
            return True;
        }
        groups: list[Item] = [item for item in scene.selection() if len(scene.solids_of(item)) > 0 and item.classname() != "worldspawn"];
        if len(groups) == 0 and len(scene.selected_solids()) > 0 and how != "off" {
            # Loose brushes: a group of their own, which is then the maker.
            made = scene.tie_selection("func_group");
            if made is not None {
                groups = [made];
            }
        }
        if len(groups) == 0 {
            host.say("Select the group to make something of, or the brushes for a new one");
            return True;
        }
        scene.clear_selection();
        for item in groups {
            scene.select(item, add=True);
        }
        # Whatever it made before is taken off; then what it is to make now.
        change: dict[str, str | None] = {};
        for key in MAKER_KEYS {
            change[key] = " ".join(numbers[:2] if how == "arch" else numbers[:1]) if key == "_" + how else None;
        }
        if not scene.set_fields(change, "Maker") {
            host.say("They are so already");
            return True;
        }
        print("studio: maker " + how + " " + " ".join(numbers[:2]) + " groups=" + str(len(groups)));
        host.say(
            str(len(groups)) + (" group is" if len(groups) == 1 else " groups are") + " built as "
                + {"hollow": "shells of walls", "walls": "walls alone", "arch": "arches", "off": "they are"}[how]
        );
        return True;
    }

    def tick(host: ToolHost, dt: float) {}

    def draw_through(host: ToolHost, scene: Scene) {}

    def dump_lines(host: ToolHost, scene: Scene) -> list[str] {
        return [];
    }

    def settings_lines(host: ToolHost) -> list[str] {
        return [];
    }
}
