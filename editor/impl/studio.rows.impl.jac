"""The studio's scene tree said in words: every row it shows now, for a
script or a person at the console to read. Declarations live in studio.jac."""

impl Studio.rows_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_tree" {
        return False;
    }
    ui = self.ui;
    if ui is None {
        return True;
    }
    wanted = " ".join(args[1:]).strip().lower();
    told = 0;
    for row in ui.tree.rows {
        if wanted and wanted not in row.text.lower() {
            continue;
        }
        told += 1;
        if told <= 200 {
            print(
                "studio: row " + str(row.depth) + " " + row.key + " " + row.text.strip() + (" [" + row.note + "]" if row.note else "")
                    + (" *" if row.picked else "")
            );
        }
    }
    self.say(str(told) + " rows of the scene tree" + (" hold \"" + wanted + "\"" if wanted else ""));
    return True;
}
