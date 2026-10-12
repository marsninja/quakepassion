"""A held game's opponents, doors and pickups: called over, and changed by
their numbers. Declarations live in studio.jac."""

"""Three numbers of a command's words from `at` on, or None."""
def:priv place_from(args: list[str], at: int) -> Vec3 | None {
    if len(args) < at + 3 {
        return None;
    }
    try {
        return Vec3(x=float(args[at]), y=float(args[at + 1]), z=float(args[at + 2]));
    } except ValueError {
        return None;
    }
}

impl Studio.live_others(args: list[str]) -> bool {
    app = self.app;
    if app is None {
        return True;
    }
    # A walker goes out from the world to what it holds of each kind.
    roll = app.world spawn LiveRoll();
    what = args[1];
    if what == "opponents" {
        for (number, each) in enumerate(roll.opponents) {
            print("studio: live " + opponent_words(number, each));
        }
        self.say(str(len(roll.opponents)) + " opponents live (ed_live opponent <number> health <n> | at <x y z>)");
        return True;
    }
    if what == "doors" {
        for (number, gate) in enumerate(roll.doors) {
            print("studio: live " + door_words(number, gate));
        }
        self.say(str(len(roll.doors)) + " doors and things that move like them (ed_live door <number> open|lock|unlock)");
        return True;
    }
    if what == "pickups" {
        for (number, lying) in enumerate(roll.pickups) {
            print("studio: live " + pickup_words(number, lying));
        }
        self.say(str(len(roll.pickups)) + " pickups lie in the level (ed_live pickup <number> at <x y z>)");
        return True;
    }
    index = int(args[2]) if len(args) > 2 and args[2].isdigit() else -1;
    how = args[3] if len(args) > 3 else "";
    if what == "opponent" {
        if index < 0 or index >= len(roll.opponents) {
            self.say("ed_live opponent <number> health <n> | at <x y z> (ed_live opponents numbers them)");
            return True;
        }
        found = roll.opponents[index];
        spot = place_from(args, 4);
        if how == "health" and len(args) > 4 and args[4].isdigit() and int(args[4]) > 0 {
            found.health = min(99999, int(args[4]));
        } elif how == "at" and spot is not None {
            # Where it is, and where its step is taking it: it stands there.
            found.pos = spot;
            found.stride_to = spot;
            found.stride_at = spot;
            found.velocity = Vec3();
        } else {
            self.say("ed_live opponent " + str(index) + " health <n> | at <x y z>");
            return True;
        }
        print("studio: live " + opponent_words(index, found));
        return True;
    }
    if what == "door" {
        if index < 0 or index >= len(roll.doors) or how not in ["open", "lock", "unlock"] {
            self.say("ed_live door <number> open|lock|unlock (ed_live doors numbers them)");
            return True;
        }
        gate = roll.doors[index];
        if how == "open" {
            # As if it had been used: it opens when the game goes on.
            gate.requested = True;
        } else {
            gate.enabled = how == "unlock";
        }
        print("studio: live " + door_words(index, gate) + " asked=" + ("1" if gate.requested else "0"));
        return True;
    }
    spot = place_from(args, 4);
    if index < 0 or index >= len(roll.pickups) or how != "at" or spot is None {
        self.say("ed_live pickup <number> at <x y z> (ed_live pickups numbers them)");
        return True;
    }
    lying = roll.pickups[index];
    lying.pos = spot;
    print("studio: live " + pickup_words(index, lying));
    return True;
}
