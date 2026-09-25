"""Local free-for-all matches as a graph.

An `ArenaMatch` node links every competitor through a `Competes` edge that
carries the competitor's name and score. Spawn points are `SpawnPoint` nodes.
Walkers credit frags, announce lead changes and end the match at the limit,
following Q3's g_combat.c scoring, g_client.c spawn selection and cg_event.c
announcer rules."""
import from .world { World, Actor }
import from ..math.vec3 { Vec3 }

edge HasMatch: World --> ArenaMatch {}
node ArenaMatch {
    has fraglimit: int = 20,
        title: str = "",
        elapsed: float = 0.0,
        warmup: float = 0.0,
        finished: bool = False,
        winner: str = "",
        lead: int = 2,
        frags_called: int = 0,
        prepared: bool = False;
}

edge Competes: ArenaMatch --> Actor {
    has name: str = "",
        frags: int = 0,
        deaths: int = 0,
        down: bool = False,
        human: bool = False,
        excellent: int = 0,
        impressive: int = 0,
        humiliation: int = 0,
        last_frag: float = -100.0;
}

edge HasSpawn: World --> SpawnPoint {}
node SpawnPoint {
    has pos: Vec3 = Vec3(),
        yaw: float = 0.0;
}

obj Standing {
    has name: str,
        frags: int,
        deaths: int,
        human: bool;
}

def match_of(world: World) -> ArenaMatch | None {
    matches = [world->:HasMatch:->][?:ArenaMatch];
    return matches[0] if matches else None;
}

def standings(contest: ArenaMatch) -> list[Standing] {
    rows = [
        Standing(name=score.name, frags=score.frags, deaths=score.deaths, human=score.human)
        for score in [edge contest->:Competes:->]
    ];
    ordered: list[Standing] = [];
    for row in rows {
        index = 0;
        while index < len(ordered) and ordered[index].frags >= row.frags {
            index += 1;
        }
        ordered.insert(index, row);
    }
    return ordered;
}

"""Count an Impressive for a competitor on its Competes edge."""
def credit_impressive(contest: ArenaMatch, actor: Actor) {
    entries = [edge contest->:Competes:->];
    actors = [contest->:Competes:->];
    for i in range(len(actors)) {
        if actors[i] is actor {
            entries[i].impressive += 1;
        }
    }
}

def competitor_name(contest: ArenaMatch, actor: Actor) -> str {
    entries = [edge contest->:Competes:->];
    actors = [contest->:Competes:->];
    for i in range(len(actors)) {
        if actors[i] is actor {
            return entries[i].name;
        }
    }
    return "";
}

def ordinal(place: int) -> str {
    if place == 1 {
        return "1st";
    }
    if place == 2 {
        return "2nd";
    }
    return "3rd" if place == 3 else str(place) + "th";
}

"""cg_event.c CG_Obituary's line for one competitor killing another."""
def obituary(victim: str, killer: str, means: str) -> str {
    lines: dict[str, tuple[str, str]] = {
        "gauntlet": ("was pummeled by ", ""),
        "machinegun": ("was machinegunned by ", ""),
        "shotgun": ("was gunned down by ", ""),
        "grenadelauncher": ("ate ", "'s grenade"),
        "rocketlauncher": ("ate ", "'s rocket"),
        "splash": ("almost dodged ", "'s rocket"),
        "plasmagun": ("was melted by ", "'s plasmagun"),
        "railgun": ("was railed by ", ""),
        "lightning": ("was electrocuted by ", ""),
        "bfg": ("was blasted by ", "'s BFG"),
        "telefrag": ("tried to invade ", "'s personal space")
    };
    words = lines.get(means, ("was killed by ", ""));
    return victim + " " + words[0] + killer + words[1];
}

"""Advance the match: frag credit on each fresh death, then Q3's local sounds."""
walker MatchTick {
    has dt: float,
        cues: list[str] = [],
        messages: list[str] = [],
        obituaries: list[str] = [],
        ended: bool = False;

    can tally with ArenaMatch entry {
        if here.finished or self.dt <= 0.0 {
            return;
        }
        if here.warmup > 0.0 {
            if not here.prepared {
                here.prepared = True;
                self.cues.append("sound/feedback/prepare.wav");
            }
            before = here.warmup;
            here.warmup = max(0.0, here.warmup - self.dt);
            names = ["one", "two", "three"];
            for count in [3, 2, 1] {
                mark = float(count);
                if before > mark and here.warmup <= mark {
                    self.cues.append("sound/feedback/" + names[count - 1] + ".wav");
                }
            }
            if here.warmup <= 0.0 {
                self.cues.append("sound/feedback/fight.wav");
                self.messages.append("FIGHT!");
            }
            return;
        }
        here.elapsed += self.dt;
        entries = [edge here->:Competes:->];
        actors = [here->:Competes:->];
        changed = False;
        for i in range(len(actors)) {
            actor = actors[i];
            score = entries[i];
            if actor.health > 0 {
                score.down = False;
                continue;
            }
            if score.down {
                continue;
            }
            score.down = True;
            score.deaths += 1;
            changed = True;
            killer = actor.killer;
            credited = -1;
            for j in range(len(actors)) {
                if killer is not None and actors[j] is killer and j != i {
                    credited = j;
                }
            }
            if credited < 0 {
                # Suicides and world deaths cost the victim a frag.
                score.frags -= 1;
                if score.human {
                    self.messages.append("You killed yourself");
                }
                continue;
            }
            entries[credited].frags += 1;
            # g_combat.c rewards: two frags within CARNAGE_REWARD_TIME is
            # Excellent; a gauntlet frag is Humiliation.
            winner = entries[credited];
            if here.elapsed - winner.last_frag < 3.0 {
                winner.excellent += 1;
                if winner.human {
                    self.cues.append("sound/feedback/excellent.wav");
                    self.messages.append("Excellent!");
                }
            }
            winner.last_frag = here.elapsed;
            if actor.death_means == "gauntlet" {
                winner.humiliation += 1;
                if winner.human or score.human {
                    self.cues.append("sound/feedback/humiliation.wav");
                }
            }
            if entries[credited].human {
                # cg_event.c CG_Obituary: the frag and the new standing.
                mine = entries[credited].frags;
                ahead = len([other for other in entries if not other.human and other.frags > mine]);
                tied = any([not other.human and other.frags == mine for other in entries]);
                self.messages.append(
                    "You fragged "
                        + score.name
                        + "\n"
                        + ("Tied for " if tied else "")
                        + ordinal(ahead + 1)
                        + " place with "
                        + str(mine)
                );
            } elif score.human {
                self.messages.append("You were fragged by " + entries[credited].name);
            } else {
                self.obituaries.append(obituary(score.name, entries[credited].name, actor.death_means));
            }
        }
        if not changed {
            return;
        }
        self.announce(here, entries);
        best = max([score.frags for score in entries]) if entries else 0;
        if best >= here.fraglimit {
            here.finished = True;
            self.ended = True;
            for score in entries {
                if score.frags == best {
                    here.winner = score.name;
                    if score.human {
                        break;
                    }
                }
            }
            human_won = any([score.human and score.frags == best for score in entries]);
            self.cues.append(
                "sound/player/announce/youwin.wav"
                    if human_won
                    else "sound/player/announce/" + here.winner.lower() + "_wins.wav"
            );
            # A win without a single death is Perfect.
            if any([score.human and score.frags == best and score.deaths == 0 for score in entries]) {
                self.cues.append("sound/feedback/perfect.wav");
                self.messages.append("Perfect!");
            }
            self.messages.append(
                "You win!" if human_won else here.winner + " wins the match"
            );
        }
    }

    # cg_event.c CG_CheckLocalSounds: lead changes and the last three frags.
    def announce(contest: ArenaMatch, entries: list[Competes]) {
        humans = [score for score in entries if score.human];
        if humans {
            mine = humans[0].frags;
            others = [score.frags for score in entries if not score.human];
            top = max(others) if others else -100000;
            lead = 1 if mine > top else (0 if mine == top else -1);
            if lead != contest.lead and contest.elapsed > 0.0 {
                if lead == 1 {
                    self.cues.append("sound/feedback/takenlead.wav");
                } elif lead == 0 {
                    self.cues.append("sound/feedback/tiedlead.wav");
                } elif contest.lead >= 0 {
                    self.cues.append("sound/feedback/lostlead.wav");
                }
            }
            contest.lead = lead;
        }
        best = max([score.frags for score in entries]) if entries else 0;
        left = contest.fraglimit - best;
        if left in [1, 2, 3] and contest.frags_called != left {
            contest.frags_called = left;
            self.cues.append(
                "sound/feedback/1_frag.wav"
                    if left == 1
                    else "sound/feedback/" + str(left) + "_frags.wav"
            );
        }
    }
}

"""g_client.c SelectRandomFurthestSpawnPoint: rank spawns by distance to the
nearest other competitor and pick randomly among the furthest half."""
walker ChooseSpawn {
    has avoid: list[Vec3] = [],
        occupied: list[Vec3] = [],
        seed: int = 1,
        chosen: SpawnPoint | None = None,
        spots: list[SpawnPoint] = [],
        ranks: list[float] = [];

    can begin with World entry {
        visit [here->:HasSpawn:->];
    }

    can rank with SpawnPoint entry {
        # SpotWouldTelefrag: skip spots whose box another body overlaps.
        for body in self.occupied {
            if abs(body.x - here.pos.x) < 32.0
                and abs(body.y - here.pos.y) < 32.0
                and abs(body.z - here.pos.z) < 56.0 {
                return;
            }
        }
        nearest = 100000.0;
        for other in self.avoid {
            nearest = min(nearest, other.sub(here.pos).length());
        }
        index = 0;
        while index < len(self.ranks) and self.ranks[index] >= nearest {
            index += 1;
        }
        self.ranks.insert(index, nearest);
        self.spots.insert(index, here);
    }

    def pick() -> SpawnPoint | None {
        if not self.spots {
            return None;
        }
        pool = max(1, (len(self.spots) + 1) // 2);
        # Never land on another competitor when a clear spot exists.
        clear = [i for i in range(pool) if self.ranks[i] > 64.0];
        options = clear if clear else list(range(pool));
        self.chosen = self.spots[options[abs(self.seed) % len(options)]];
        return self.chosen;
    }
}

"""Enter the human player into the world's match with Q3's 125 spawn health."""
def join_match(world: World, player: Actor, name: str = "You") -> ArenaMatch | None {
    contest = match_of(world);
    if contest is None {
        return None;
    }
    for competitor in [contest->:Competes:->] {
        if competitor is player {
            return contest;
        }
    }
    contest +>:Competes:name=name, human=True:+> player;
    player.health = player.max_health + 25;
    return contest;
}
