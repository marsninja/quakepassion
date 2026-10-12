"""A Passion mission changed by hand: links added, taken away and changed,
tokens granted, beats added, a cycle pattern laid between two beats. Each
change is made on the mission's own graph (beats, and the links between
them) and then proved with the generator's own search: a mission that
cannot be finished, or that can be played into a corner, says so."""

import from games.passion.random { Stream }
import from games.passion.mission {
    Expedition, Beat, Link, Holds, Grammar, PATTERNS, KEY_TYPES, beats_of, links_of, annotate, validate_mission,
    apply_pattern, pending_arcs, endpoints, expand_arc
}

"""The ways a link can be passed, and the kinds a beat added by hand may be."""
glob LINK_MODES: list[str] = ["open", "valve", "locked", "shortcut", "secret", "window", "gate"],
     BEAT_KINDS: list[str] = ["room", "junction", "hub", "arena", "recovery", "cache", "vista"];

"""A mission like another, beat for beat and link for link, sharing nothing
with it: what a change is tried on, or what is gone back to."""
def mission_copy(plan: Expedition) -> Expedition {
    made = Expedition(
        seed=plan.seed, version=plan.version, archetype=plan.archetype, briefing=plan.briefing, niche=list(plan.niche),
        descriptors=list(plan.descriptors), quality=plan.quality, candidate=plan.candidate, objectives=list(plan.objectives),
        route=list(plan.route), sections=plan.sections, verticality=plan.verticality, density=plan.density,
        loopiness=plan.loopiness, districts=list(plan.districts)
    );
    twins: list[Beat] = [];
    for beat in beats_of(plan) {
        twin = Beat(
            id=beat.id, kind=beat.kind, size=beat.size, section=beat.section, district=beat.district, grants=list(beat.grants),
            optional=beat.optional, order=beat.order, depth=beat.depth, tension=beat.tension, encounter=beat.encounter,
            pattern=beat.pattern
        );
        made +>:Holds:+> twin;
        twins.append(twin);
    }
    for link in links_of(plan) {
        twins[link.tail] +>:Link(
            id=link.id, mode=link.mode, needs=list(link.needs), chain=link.chain, danger=link.danger, tail=link.tail,
            head=link.head
        ):+> twins[link.head];
    }
    return made;
}

"""A grammar over a mission as it stands, to add to it by: its beats, how
many links it has had, and the keys no lock uses yet."""
def grammar_over(plan: Expedition, stream: Stream) -> Grammar {
    most = 0;
    used: list[str] = [];
    for link in links_of(plan) {
        most = max(most, link.id);
        for token in link.needs {
            if token not in used {
                used.append(token);
            }
        }
    }
    return Grammar(
        plan=plan, stream=stream, beats=beats_of(plan), links=most, keys=[key for key in KEY_TYPES if key not in used],
        nesting=1
    );
}

"""What an assertion said, without where in the source it was said: the
compiler puts ` at <file>:<line>` after it."""
def:priv said_alone(words: str) -> str {
    cut = words.rfind(" at ");
    colon = words.rfind(":");
    if cut > 0 and colon > cut and words[colon + 1:].isdigit() {
        return words[:cut];
    }
    return words;
}

"""What is wrong with a mission, as the generator's own proof says it: a
token nothing grants, a goal that cannot be reached, a corner it can be
played into, a beat that cannot be reached. "" when it is sound. Its
beats' order, depth and tension are worked out again first."""
def mission_fault(plan: Expedition) -> str {
    try {
        annotate(plan);
        validate_mission(plan);
    } except AssertionError as error {
        return said_alone(str(error)) if str(error) else "the mission is not sound";
    } except ValueError as error {
        return str(error) if str(error) else "the mission is not sound";
    }
    return "";
}

"""Add a link from one beat to another. False when there are no such beats,
the mode is none, or a beat would lead to itself."""
def add_link(plan: Expedition, stream: Stream, tail: int, head: int, mode: str = "open", needs: list[str] = []) -> bool {
    beats = beats_of(plan);
    if tail < 0 or head < 0 or tail >= len(beats) or head >= len(beats) or tail == head or mode not in LINK_MODES {
        return False;
    }
    grammar_over(plan, stream).link(beats[tail], beats[head], mode, list(needs));
    return True;
}

"""Take a link away by its number. False when there is none of that number."""
def drop_link(plan: Expedition, number: int) -> bool {
    for beat in beats_of(plan) {
        links = [edge beat->:Link:->];
        heads = [beat->:Link:->][?:Beat];
        for at in range(min(len(links), len(heads))) {
            if links[at].id == number {
                beat del->:Link:id == number:-> heads[at];
                return True;
            }
        }
    }
    return False;
}

"""Change how a link is passed and what it needs. False when there is no
such link or mode."""
def set_link(plan: Expedition, number: int, mode: str, needs: list[str]) -> bool {
    if mode not in LINK_MODES {
        return False;
    }
    for link in links_of(plan) {
        if link.id == number {
            link.mode = mode;
            link.needs = list(needs);
            return True;
        }
    }
    return False;
}

"""Have a beat grant a token, or no longer grant it. False when nothing changed."""
def set_grant(plan: Expedition, beat: int, token: str, granted: bool) -> bool {
    beats = beats_of(plan);
    if beat < 0 or beat >= len(beats) or not token {
        return False;
    }
    held = beats[beat].grants;
    if granted and token not in held {
        held.append(token);
        return True;
    }
    if not granted and token in held {
        held.remove(token);
        return True;
    }
    return False;
}

"""Add a beat reached from another by an open link, in that one's section
and district. Answers its number, or -1 when it could not be added."""
def add_beat(plan: Expedition, stream: Stream, source: int, kind: str = "room", size: int = 1) -> int {
    beats = beats_of(plan);
    if source < 0 or source >= len(beats) or kind not in BEAT_KINDS {
        return -1;
    }
    grammar = grammar_over(plan, stream);
    made = grammar.beat(kind, max(0, min(3, size)), beats[source].section);
    made.district = beats[source].district;
    made.optional = kind in ["cache", "recovery", "vista"];
    grammar.link(beats[source], made);
    return made.id;
}

"""Lay a cycle pattern between two beats (alternatives, lock_key, far_key,
shortcut, hidden, foreshadow, switch, gambit) and open its arcs out into
rooms, as the generator does. Answers how many beats it added, or -1 when
it could not be laid."""
def lay_pattern(plan: Expedition, stream: Stream, name: str, entry_beat: int, exit_beat: int) -> int {
    beats = beats_of(plan);
    if name not in PATTERNS or entry_beat < 0 or exit_beat < 0 or entry_beat >= len(beats) or exit_beat >= len(beats)
        or entry_beat == exit_beat {
        return -1;
    }
    grammar = grammar_over(plan, stream);
    before = len(grammar.beats);
    apply_pattern(grammar, name, beats[entry_beat], beats[exit_beat], "", "");
    guard = 0;
    arcs = pending_arcs(grammar);
    while len(arcs) > 0 and guard < 200 {
        guard += 1;
        ends = endpoints(grammar, arcs[0]);
        expand_arc(grammar, arcs[0], ends[0], ends[1], plan.loopiness);
        arcs = pending_arcs(grammar);
    }
    # What it added is in the district of where it began.
    for added in grammar.beats[before:] {
        added.district = beats[entry_beat].district;
    }
    return len(grammar.beats) - before;
}
