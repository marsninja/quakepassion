"""Campaign gates derive their collision and visibility from persistent inventory."""
import from .world { World }
import from .inventory { Inventory, quantity }
import from ..formats.bsp { Bsp }
import from ..physics.collision { CollisionMap }

edge HasGate: World --> CampaignGate {}
node CampaignGate {
    has mask: int,
        boss: bool = False,
        faces: list[int] = [],
        hidden: list[bool] = [],
        hulls: list[int] = [];
}

walker ApplyGates {
    has inventory: Inventory,
        bsp: Bsp,
        collision: CollisionMap;

    can begin with World entry {
        visit [here->:HasGate:->];
    }
    can apply with CampaignGate entry {
        runes = quantity(self.inventory, "runes") & 15;
        solid = runes != 15 if here.boss else runes & here.mask != 0;
        for i in range(len(here.faces)) {
            self.bsp.faces[here.faces[i]].hidden = not solid or here.hidden[i];
        }
        for index in here.hulls {
            if solid {
                self.collision.disabled.discard(index);
            } else {
                self.collision.disabled.add(index);
            }
        }
    }
}

def load_gates(world: World, bsp: Bsp, collision: CollisionMap) {
    if bsp.game != "q1" {
        return;
    }
    for entity in bsp.entities {
        kind = entity.fields.get("classname", "");
        if kind not in ["func_episodegate", "func_bossgate"] {
            continue;
        }
        reference = entity.fields.get("model", "");
        if not reference.startswith("*") {
            continue;
        }
        index = int(reference[1:]);
        if index <= 0 or index >= len(bsp.models) {
            raise ValueError("Invalid campaign gate model");
        }
        model = bsp.models[index];
        faces = list(range(model.first_face, model.first_face + model.face_count));
        gate = CampaignGate(
            mask=int(entity.fields.get("spawnflags", "0")) & 15,
            boss=kind == "func_bossgate",
            faces=faces,
            hidden=[bsp.faces[face].hidden for face in faces],
            hulls=[
                i
                for i in range(len(collision.models))
                if collision.models[i] == index
            ]
        );
        world +>:HasGate:+> gate;
    }
    world spawn ApplyGates(inventory=Inventory(), bsp=bsp, collision=collision);
}

def rune_summary(inventory: Inventory) -> str {
    flags = quantity(inventory, "runes") & 15;
    found = [
        str(i + 1)
        for i in range(4)
        if flags & (1 << i)
    ];
    return "Runes: " + ", ".join(found) if found else "";
}
