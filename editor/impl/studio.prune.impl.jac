"""The studio's pruning: sides that make no face taken out of brushes, and
brushes that enclose nothing taken out of the scene. Declarations live in
studio.jac."""

impl Studio.prune_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_prune" {
        return False;
    }
    everywhere = len(args) > 1 and args[1] == "all";
    if len(args) > 1 and not everywhere {
        self.say("ed_prune [all]: take out the sides that make no face, from the selected brushes or from every brush");
        return True;
    }
    told = scene.prune_sides(everywhere);
    print("studio: pruned sides=" + str(told[0]) + " brushes=" + str(told[1]) + " spared=" + str(told[2]));
    if told[0] + told[1] == 0 {
        self.say(
            "Every side of " + ("every brush" if everywhere else "the selected brushes") + " makes a face"
                + (" (" + str(told[2]) + " with linked faces were left as they are)" if told[2] > 0 else "")
        );
    } else {
        self.say(
            "Took out " + str(told[0]) + " sides that made no face" + (" and " + str(told[1]) + " brushes that enclosed nothing" if told[1] > 0 else "")
                + (" (" + str(told[2]) + " with linked faces were left as they are)" if told[2] > 0 else "")
        );
    }
    return True;
}
