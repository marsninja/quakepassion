"""The weights dialog: the bone in hand, the weight it takes of the picked
points, and what carries each of them. Declarations live in studio.jac."""

def:priv share_words(value: float) -> str {
    near = round(value, 3);
    return str(int(near)) if near == float(int(near)) else str(near);
}

impl Studio.keep_weights_box {
    casing = self.weights_box;
    doc = self.model_doc;
    if casing is None {
        return;
    }
    part = doc.part() if doc is not None else None;
    picked = list(part.picked_points) if part is not None else [];
    words = (str(doc.revision) if doc is not None else "none") + "|" + self.bone_now + "|" + ",".join([str(index) for index in picked[:40]])
        + "|" + str(len(picked));
    if words == self.weights_for {
        return;
    }
    self.weights_for = words;
    casing.clear();
    form = Box(pad=8, gap=4, fill="panel");
    casing.adopt(form);
    if doc is None or len(doc.bones()) == 0 {
        form.adopt(Label(text="The model has no bones.", tone="dim"));
        form.adopt(Label(text="ed_bone add <name> <head> <tail> makes one.", tone="faint", small=True));
        return;
    }
    in_hand = self.bone_in_hand();
    names = [bone.name for bone in doc.bones()];
    row = Box(across=True, gap=4);
    form.adopt(row);
    row.adopt(Label(text="bone", tone="dim", size=56));
    row.adopt(
        Dropdown(
            text=in_hand.name if in_hand is not None else "",
            labels=names,
            commands=["ed_bone pick " + quote_command_word(name) for name in names],
            grow=1,
            hint="The bone in hand: the one the weight below is given to"
        )
    );
    row = Box(across=True, gap=4);
    form.adopt(row);
    row.adopt(Label(text="weight", tone="dim", size=56));
    row.adopt(
        TextField(
            ghost="0 to 1", command="ed_bone hold", grow=1,
            hint="Enter gives the bone in hand this share of the picked points; the others keep what is left of one whole"
        )
    );
    row = Box(across=True, gap=4);
    form.adopt(row);
    row.adopt(PushButton(text="All of them", command="ed_bone hold 1", hint="The bone in hand carries the picked points whole"));
    row.adopt(PushButton(text="Let go", command="ed_bone release", hint="The bone in hand lets the picked points go"));
    row.adopt(PushButton(text="Colours", command="ed_bone colours", hint="Show each point in its bones' colours"));
    form.adopt(Spacer(size=4));
    form.adopt(
        Label(
            text=str(len(picked)) + (" point picked" if len(picked) == 1 else " points picked") if len(picked) > 0
                else "Pick points in the view to see what carries them.",
            tone="dim",
            small=True
        )
    );
    for index in picked[:8] {
        shares = doc.point_shares(index);
        form.adopt(
            Label(
                text="point " + str(index) + ":  "
                    + ("   ".join([name + " " + share_words(share) for (name, share) in shares]) if len(shares) > 0 else "carried by none"),
                tone="text",
                small=True
            )
        );
    }
    if len(picked) > 8 {
        form.adopt(Label(text="and " + str(len(picked) - 8) + " more (ed_bone weights lists them all)", tone="faint", small=True));
    }
}

impl Studio.weights_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_weights" {
        return False;
    }
    stage = self.stage;
    how = args[1] if len(args) > 1 else "";
    casing = self.weights_box;
    if how == "close" or (not how and casing is not None) {
        if casing is not None and stage is not None {
            stage.close(casing);
        }
        self.weights_box = None;
        return True;
    }
    if how not in ["", "open"] {
        self.say("ed_weights [open|close]");
        return True;
    }
    if self.model_doc is None {
        self.say("Edit a model first (ed_model new, or ed_model edit on the one the explorer shows)");
        return True;
    }
    if casing is None and stage is not None {
        casing = Floater(title="Weights", command="ed_weights close", least_wide=260, least_tall=150);
        casing.area = Rect(x=max(8, stage.width - 290), y=110, w=270, h=300);
        casing.settle(stage);
        stage.open(casing);
        self.weights_box = casing;
    }
    self.weights_for = "";
    self.keep_weights_box();
    print("studio: weights open bones=" + str(len(self.model_doc.bones())) + " hand=" + self.bone_now);
    return True;
}
