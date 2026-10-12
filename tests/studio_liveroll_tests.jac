import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }
import from engine.world.world { World }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.world.doors { Door, HasDoor }
import from engine.world.pickups { Pickup, PickupRule, HasPickup }
import from editor.document.liveroll { LiveRoll, opponent_words, door_words, pickup_words }

test "a world's opponents, doors and pickups are called over in the order it keeps them" {
    world = World();
    ogre = Opponent(pos=Vec3(x=64.0, y=-32.0, z=24.0), health=200);
    ogre.rule.model = "progs/ogre.mdl";
    grunt = Opponent(health=30, dormant=True);
    world +>:HasOpponent:+> ogre;
    world +>:HasOpponent:+> grunt;
    gate = Door(
        model=3, trigger=AABB(mins=Vec3(), maxs=Vec3(x=1.0, y=1.0, z=1.0)), travel=Vec3(z=64.0), speed=100.0, hold_time=3.0,
        names=["gate", "all"]
    );
    world +>:HasDoor:+> gate;
    box = Pickup(rule=PickupRule(kind="health", amount=25, capacity=100, model="maps/b_bh25.bsp", classname="item_health"), pos=Vec3(x=8.0));
    world +>:HasPickup:+> box;
    roll = world spawn LiveRoll();
    assert len(roll.opponents) == 2 and roll.opponents[0] is ogre and roll.opponents[1] is grunt;
    assert len(roll.doors) == 1 and roll.doors[0] is gate and len(roll.pickups) == 1 and roll.pickups[0] is box;
    assert opponent_words(0, ogre) == "opponent 0 model=ogre.mdl at=64,-32,24 health=200 dormant=0";
    assert opponent_words(1, grunt) == "opponent 1 model=- at=0,0,0 health=30 dormant=1";
    assert door_words(0, gate) == "door 0 model=*3 kind=door state=closed enabled=1 names=gate,all";
    assert pickup_words(0, box) == "pickup 0 class=item_health at=8,0,0";
    # A world that holds none of them has nothing to call.
    bare = World() spawn LiveRoll();
    assert bare.opponents == [] and bare.doors == [] and bare.pickups == [];
}
