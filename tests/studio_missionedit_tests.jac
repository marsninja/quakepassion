import from games.passion.random { stream_for }
import from games.passion.mission { Expedition, build_mission, beats_of, links_of }
import from editor.document.missionedit {
    mission_copy, mission_fault, add_link, drop_link, set_link, set_grant, add_beat, lay_pattern
}

"""A small mission of the generator's own making."""
def small -> Expedition {
    return build_mission(7, stream_for(7, "mission"), "keys", 1, 1, 12, 0.5);
}

test "a mission as built is sound, and a copy of it shares nothing with it" {
    plan = small();
    assert mission_fault(plan) == "";
    twin = mission_copy(plan);
    assert len(beats_of(twin)) == len(beats_of(plan)) and len(links_of(twin)) == len(links_of(plan));
    assert [link.id for link in links_of(twin)] == [link.id for link in links_of(plan)];
    assert beats_of(twin)[0] is not beats_of(plan)[0] and mission_fault(twin) == "";
    # A change to the copy is none to the first.
    count = len(links_of(plan));
    assert add_link(twin, stream_for(1, "edit"), 0, len(beats_of(twin)) - 1, "shortcut");
    assert len(links_of(twin)) == count + 1 and len(links_of(plan)) == count;
}

test "a link is added, changed and taken away by its number" {
    plan = small();
    count = len(links_of(plan));
    most = max([link.id for link in links_of(plan)]);
    assert add_link(plan, stream_for(1, "edit"), 1, 2, "open") and len(links_of(plan)) == count + 1;
    assert max([link.id for link in links_of(plan)]) == most + 1 and mission_fault(plan) == "";
    assert set_link(plan, most + 1, "valve", []) and [link for link in links_of(plan) if link.id == most + 1][0].mode == "valve";
    assert not set_link(plan, most + 1, "sideways", []) and not set_link(plan, 9999, "open", []);
    assert drop_link(plan, most + 1) and len(links_of(plan)) == count and not drop_link(plan, most + 1);
    # No link from a beat to itself, to a beat that is not there, or of no kind.
    assert not add_link(plan, stream_for(1, "edit"), 1, 1) and not add_link(plan, stream_for(1, "edit"), 1, 999);
    assert not add_link(plan, stream_for(1, "edit"), 1, 2, "sideways");
}

test "the proof says what a change broke" {
    plan = small();
    # A lock whose key nothing grants.
    most = max([link.id for link in links_of(plan)]);
    assert add_link(plan, stream_for(1, "edit"), 0, 1, "locked", ["key_of_nothing"]);
    assert mission_fault(plan) == "Mission needs an ungranted token: key_of_nothing";
    assert set_grant(plan, 0, "key_of_nothing", True) and mission_fault(plan) == "";
    assert not set_grant(plan, 0, "key_of_nothing", True) and set_grant(plan, 0, "key_of_nothing", False);
    assert drop_link(plan, most + 1) and mission_fault(plan) == "";
    # The goal cut off from everything.
    cut = small();
    goal = [beat.id for beat in beats_of(cut) if beat.kind == "goal"][0];
    for link in links_of(cut) {
        if link.head == goal or link.tail == goal {
            assert drop_link(cut, link.id);
        }
    }
    assert mission_fault(cut) != "";
}

test "a beat is added from another, and a cycle pattern laid between two" {
    plan = small();
    count = len(beats_of(plan));
    made = add_beat(plan, stream_for(1, "edit"), 1, "vista");
    assert made == count and len(beats_of(plan)) == count + 1 and beats_of(plan)[made].optional;
    assert beats_of(plan)[made].section == beats_of(plan)[1].section and mission_fault(plan) == "";
    assert add_beat(plan, stream_for(1, "edit"), 1, "throne") == -1 and add_beat(plan, stream_for(1, "edit"), 999) == -1;
    added = lay_pattern(plan, stream_for(2, "edit"), "alternatives", 1, 2);
    assert added >= 1 and len(beats_of(plan)) == count + 1 + added and mission_fault(plan) == "";
    # Every arc was opened out into rooms: none is left to be.
    assert len([link for link in links_of(plan) if link.chain > 0]) == 0;
    assert lay_pattern(plan, stream_for(2, "edit"), "nonesuch", 1, 2) == -1 and lay_pattern(plan, stream_for(2, "edit"), "shortcut", 1, 1) == -1;
}
