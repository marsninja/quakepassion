"""Prefabs drawn from Quake III's q3dm12, The Dredwerkz: works over channels of lava. Quake III's
arenas hold no foes of their own; q3dm12's are enforcer, ogre, demon1.
Raised in q3dm12's own palette.

- `DredwerkzLava`: a channel of lava, its far bank raised, a jump pad over it and a stair round its end.
- The arena's entry, pad tower, atrium (a hub), key vault and portal (the
  end, or a gate): the shared stretches of `q3arena`, made for q3dm12."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .common { stair, pillars, key_ambush, gate_into, lift, spiral, ring_landing }
import from .q3arena { ArenaEntry, PadTower, ArenaAtrium, ArenaVault, ArenaPortal, arena_foe, Q3_HEALTH, Q3_ARMOR }

glob Q3DM12: str = "q3:q3dm12",
     Q3DM12_LIGHT: list[str] = ["monster_enforcer", "monster_ogre"],
     Q3DM12_HEAVY: list[str] = ["monster_demon1"];

"""A channel of lava across a works, its far bank raised, a jump pad on the
near bank throwing a body over and a stair down at the far end's side
back to a walk round the channel's end."""
node DredwerkzLava(Prefab) {
    has bank: int = 3,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dredwerkz lava";
        self.source = Q3DM12;
        self.district = level_district(Q3DM12);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.bank = dice.between(2, 4);
        self.tall = dice.between(15, 17);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.bank), Port(face=1, along=float(self.long - 4), floor=self.bank)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        works = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(works, self.bank);
        lx0 = 10;
        lx1 = 15;
        build.pool(lx0, 1, -3, lx1, self.wide - 4, 0, 4, False, False);
        build.solid(lx1, 1, 0, self.long - 1, self.wide - 1, self.bank);
        build.jump_pad(float(lx0) - 3.0, float(middle) + 0.5, 0, float(lx1) + 1.0, float(middle) + 0.5, self.bank);
        stair(build, lx1 - self.bank, self.wide - 4, 0, 0, self.bank, 3);
        for y in range(self.wide - 4, self.wide - 1) {
            build.keep(works, lx1, y, self.bank);
        }
        build.doorway(works, self.enter);
        for port in self.taken {
            build.doorway(works, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(lx1 + 4 + index * 3) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), self.bank, arena_foe(dice, self.danger, Q3DM12_LIGHT, Q3DM12_HEAVY, index == 0), 180.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, self.bank, Q3_HEALTH, "q3");
    }
}

"""q3dm12's stretches: [name, role]."""
glob Q3DM12_STRETCHES: list[list[str]] = [
         ["entry", "start"],
         ["channel", "flow"],
         ["tower", "flow"],
         ["atrium", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm12's stretches by its name."""
def make_q3dm12(name: str, key: str) -> Prefab {
    if name == "entry" {
        return ArenaEntry(source=Q3DM12, label="Dredwerkz hall", light=Q3DM12_LIGHT, heavy=Q3DM12_HEAVY, sky=False);
    }
    if name == "channel" {
        return DredwerkzLava();
    }
    if name == "tower" {
        return PadTower(source=Q3DM12, label="Dredwerkz tower", light=Q3DM12_LIGHT, heavy=Q3DM12_HEAVY, sky=False);
    }
    if name == "atrium" {
        return ArenaAtrium(source=Q3DM12, label="Dredwerkz atrium", light=Q3DM12_LIGHT, heavy=Q3DM12_HEAVY, sky=False, liquid=4);
    }
    if name == "vault" {
        return ArenaVault(source=Q3DM12, label="Dredwerkz vault", key=key if key else "key_silver", light=Q3DM12_LIGHT, heavy=Q3DM12_HEAVY);
    }
    return ArenaPortal(source=Q3DM12, label="Dredwerkz portal", key=key, light=Q3DM12_LIGHT, heavy=Q3DM12_HEAVY, sky=False);
}
