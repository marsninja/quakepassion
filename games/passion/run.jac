"""A Passion run: one seed, its levels played one after another.

The run's first level is `v3-<seed>`; reaching a level's way out goes on to
the next (`v3-<seed>-2`, `-3`, ...), each made from the run's seed and its
depth, so a seed always plays the same run. While a level is played the
next is made a few milliseconds a frame (`Forge`), so the way out leads on
at once. Nothing is kept on disk: the level being played is kept in memory
to begin again from after a death, the next until it is reached.

The run is a node, and each level cleared hangs off it in order: what the
end of a level tallies is read off those."""
import from engine.world.world { Player }
import from editor.compile.live { Materials }
import from editor.assets.materials { ArchiveMaterials }
import from .generate { Forge, run_of, next_level }
import from .trace { trace_source }

# Seconds a frame given to making the next level while one is played, and
# while its way out waits on it.
glob PLAY_BUDGET: float = 0.004,
     WAIT_BUDGET: float = 0.03;

"""A run: its seed, how deep it has gone, the forge of the level being
played and of the next, the materials both are built with, and the player
as they came into the level being played (a death begins it again so)."""
node Run {
    has seed: int,
        depth: int = 1,
        directory: str = "",
        materials: Materials | None = None,
        here: Forge | None = None,
        ahead: Forge | None = None,
        # The level being opened, until it has opened.
        opening: Forge | None = None,
        arrival: Player | None = None,
        arrival_weapon: int = 0,
        # The level's way out has been reached and the next is wanted.
        leaving: bool = False,
        # When the level being played began, by the app's clock.
        began: float = 0.0;

    """The materials the run builds with, made once."""
    def shared_materials -> Materials {
        materials = self.materials;
        if materials is None {
            # Every game's archives opened while the first level is made, not
            # in the middle of a level being played.
            opened = ArchiveMaterials(directory=self.directory);
            opened.open_all();
            self.materials = opened;
            return opened;
        }
        return materials;
    }

    """A forge for one of the run's levels: the one made ahead, or the
    level being played (to begin again), when they are that level; else a
    new one."""
    def forge_for(name: str) -> Forge {
        ahead = self.ahead;
        if ahead is not None and ahead.name == name {
            return ahead;
        }
        here = self.here;
        if here is not None and here.name == name and here.finished and not here.failure {
            return here;
        }
        return Forge(name=name, directory=self.directory, materials=self.shared_materials() if self.directory else None);
    }

    """A level of the run has opened: it is the one played now, and the
    next is begun."""
    def entered(forge: Forge, now: float) {
        self.depth = run_of(forge.name)[1];
        self.here = forge;
        self.leaving = False;
        self.began = now;
        following = next_level(forge.name);
        ahead = self.ahead;
        if ahead is None or ahead.name != following {
            self.ahead = Forge(name=following, directory=self.directory, materials=self.shared_materials() if self.directory else None);
        }
    }

    """Whether the level named is the one the run is playing (a scene the
    studio plays is not)."""
    def plays(name: str) -> bool {
        here = self.here;
        return here is not None and here.name == name;
    }

    """The level being opened has opened."""
    def opened(now: float) {
        forge = self.opening;
        if forge is not None {
            self.opening = None;
            self.entered(forge, now);
        }
    }

    """Make more of the next level, for up to `budget` seconds. True once
    it is made (or could not be)."""
    def forge_ahead(budget: float) -> bool {
        ahead = self.ahead;
        if ahead is None {
            return True;
        }
        return ahead.advance(budget);
    }

    """How far the next level has got, from 0 to 1."""
    def ahead_share -> float {
        ahead = self.ahead;
        return ahead.share() if ahead is not None else 0.0;
    }

    """The level being played has been cleared: note it."""
    def cleared(kills: int, monsters: int, now: float) {
        here = self.here;
        if here is None {
            return;
        }
        self +>:Went:+> Cleared(name=here.name, depth=self.depth, kills=kills, monsters=monsters, seconds=max(0.0, now - self.began));
    }

    """The levels cleared so far, in order."""
    def cleared_levels -> list[Cleared] {
        return [self->:Went:->][?:Cleared];
    }

    """The end of a level, in a line: the run, the level, its kills and
    time, and the next level's state."""
    def tally -> str {
        done = self.cleared_levels();
        line = "Run " + str(self.seed) + " | level " + str(self.depth) + " cleared";
        if done {
            last = done[-1];
            line += " | " + str(last.kills) + "/" + str(last.monsters) + " kills | " + clock_text(last.seconds);
        }
        ahead = self.ahead;
        if ahead is not None and ahead.failure {
            return line + " | the next level could not be made";
        }
        if ahead is not None and ahead.finished {
            return line + " | Enter: level " + str(self.depth + 1);
        }
        return line + " | making level " + str(self.depth + 1) + ": " + str(int(self.ahead_share() * 100.0)) + "%"
            + (" (going on when ready)" if self.leaving else " | Enter: go on when ready");
    }
}

"""A level of a run, cleared: which, how deep, its kills and how long it
took."""
node Cleared {
    has name: str,
        depth: int = 1,
        kills: int = 0,
        monsters: int = 0,
        seconds: float = 0.0;
}

edge Went: Run --> Cleared {}

"""Minutes and seconds."""
def clock_text(seconds: float) -> str {
    whole = int(seconds);
    rest = whole % 60;
    return str(whole // 60) + ":" + ("0" if rest < 10 else "") + str(rest);
}

"""The run a level's name belongs to: `run` when it is that run, else a
new run of the name's seed."""
def run_of_level(run: Run | None, name: str, directory: str) -> Run {
    found = run_of(name);
    if run is not None and run.seed == found[0] {
        here = run.here;
        # A run's first level asked for again starts the run afresh, unless
        # it is the level being played (begun again after a death).
        if found[1] > 1 or (here is not None and here.name == name) {
            return run;
        }
    }
    return Run(seed=found[0], directory=directory);
}

"""How a level's name reads on the HUD: the run and the level."""
def run_title(name: str) -> str {
    try {
        traced = trace_source(name);
        if traced is not None {
            return "Traced from " + traced.map;
        }
        found = run_of(name);
        return "Run " + str(found[0]) + ", level " + str(found[1]);
    } except ValueError {
        return name;
    }
}
