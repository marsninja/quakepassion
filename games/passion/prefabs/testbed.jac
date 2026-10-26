"""Plain rooms to try one stretch of the library alone in (QP_PREFAB_SOLO):
a start with ways on every side, a room holding a key, a room with the way
out, and one with the way out behind a key door. Built in e1m1's kit, with
nothing in them to fight."""
import from ..prefab { Prefab, Port, Lay, Raise, Raising }

glob TESTBED: str = "testbed";

"""A plain room with the start and a way on each side but the near one."""
node TestStart(Prefab) {
    can choose with Lay entry {
        self.title = "Test start";
        self.source = TESTBED;
        self.long = 12;
        self.wide = 12;
        self.low = -1;
        self.high = 11;
        self.enter = Port(face=2, along=6.0, floor=0);
        self.leaves = [Port(face=0, along=6.0, floor=0), Port(face=1, along=6.0, floor=0), Port(face=3, along=6.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        build.begin(self);
        room = build.room(1, 1, 0, 11, 11, 10);
        for port in self.taken {
            build.doorway(room, port);
        }
        build.start(3.5, 6.5, 0, 0.0);
    }
}

"""A plain room with a key in it (silver or gold)."""
node TestKey(Prefab) {
    has key: str = "key_silver";

    can choose with Lay entry {
        self.title = "Test key";
        self.source = TESTBED;
        self.long = 10;
        self.wide = 10;
        self.low = -1;
        self.high = 11;
        self.enter = Port(face=2, along=5.0, floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        build.begin(self);
        room = build.room(1, 1, 0, 9, 9, 10);
        build.doorway(room, self.enter);
        build.put_at({"classname": "item_key2" if self.key == "key_gold" else "item_key1", "asset_game": "q1"}, 6.5, 5.5, 0);
    }
}

"""A plain room with the way out; behind a key door when `key` is given."""
node TestEnd(Prefab) {
    has key: str = "";

    can choose with Lay entry {
        self.title = "Test end";
        self.source = TESTBED;
        self.long = 14;
        self.wide = 10;
        self.low = -1;
        self.high = 11;
        self.enter = Port(face=2, along=5.0, floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        build.begin(self);
        room = build.room(1, 1, 0, 13, 9, 10);
        build.doorway(room, self.enter);
        if self.key {
            build.solid(7, 1, 0, 8, 3, 10);
            build.solid(7, 7, 0, 8, 9, 10);
            build.solid(7, 3, 8, 8, 7, 10);
            build.rising_door(7.0, 3.0, 0.0, 8.0, 7.0, 8.0, {"key": self.key, "wait": "-1"});
        }
        build.way_out(10.5, 5.0, 0);
    }
}
