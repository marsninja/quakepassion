impl App.passion_forge(name: str) -> Forge {
    run = run_of_level(self.passion_run, name, game_directory("passion"));
    self.passion_run = run;
    forge = run.forge_for(name);
    run.opening = forge;
    while not forge.advance(0.05) {
        if not self.quiet_load and not self.smoke {
            self.renderer.draw_loading(run_title(name), forge.stage, forge.share());
        }
    }
    return forge;
}

impl App.keep_passion_entry() {
    run = self.passion_run;
    if run is None {
        return;
    }
    arrival = Player();
    arrival.health = self.player.health;
    arrival.max_health = self.player.max_health;
    arrival.armor = self.player.armor;
    arrival.armor_capacity = self.player.armor_capacity;
    arrival.armor_ratio = self.player.armor_ratio;
    copied = self.player.inventory spawn CopyInventory(skip_keys=False, skip_flags=False);
    arrival.inventory = copied.result;
    run.arrival = arrival;
    run.arrival_weapon = self.combat.weapon;
}

impl App.restart_passion() -> bool {
    run = self.passion_run;
    if run is None {
        return False;
    }
    arrival = run.arrival;
    here = run.here;
    if arrival is None or here is None or here.name != self.level.name {
        return False;
    }
    # The player comes back as they came in: carried into the level again,
    # with a copy of what they held (the one kept stays for the next death).
    self.player.health = max(1, arrival.health);
    self.player.max_health = arrival.max_health;
    self.player.armor = arrival.armor;
    self.player.armor_capacity = arrival.armor_capacity;
    self.player.armor_ratio = arrival.armor_ratio;
    copied = arrival.inventory spawn CopyInventory(skip_keys=False, skip_flags=False);
    self.player.inventory = copied.result;
    self.combat.weapon = run.arrival_weapon;
    self.load_destination("passion", self.level.name, carry=True);
    return True;
}

impl App.passion_cleared() {
    run = self.passion_run;
    if run is not None and run.plays(self.level.name) {
        run.cleared(self.combat.kills, self.total_monsters, time.time());
        print("PASSION cleared", self.level.name, "kills", self.combat.kills, "of", self.total_monsters);
    }
}

impl App.passion_onward(asked: bool) {
    run = self.passion_run;
    if run is None {
        self.render_frame();
        return;
    }
    if asked {
        run.leaving = True;
    }
    made = run.forge_ahead(WAIT_BUDGET if run.leaving else PLAY_BUDGET);
    ahead = run.ahead;
    if made and run.leaving and ahead is not None and not ahead.failure {
        self.load_destination("passion", ahead.name, carry=True);
        return;
    }
    self.render_frame();
}
