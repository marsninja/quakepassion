"""Native regression: GatherModels (models.jac, which never imports combat.jac)
must see an Opponent as the Actor it is, so a Q3 bot's powerups put their
shells on its body. `isinstance(here, Actor)` there was false natively for a
subclass from a module the checking module does not import (jaseci-labs/jac
#9562). Build with `jac build repros/native_bot_powerup_shells.jac --native`
and run: it prints "ok"."""
import from engine.world.world { World, Area, move_to_area }
import from engine.world.combat { Opponent }
import from engine.world.models { PlayerRig, ModelResource, Wears, HasVisual, GatherModels }
import from engine.world.powerups { Powerup, Empowered }
import from engine.formats.animated { AnimatedModel }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }

with entry {
    world = World();
    area = Area(name="0", bounds=AABB(mins=Vec3(), maxs=Vec3()));
    world ++> area;
    bot = Opponent(arena=True, pos=Vec3(z=26.0));
    rig = PlayerRig();
    rig +>:Wears(role="lower"):+> ModelResource(name="lower", model=AnimatedModel(), skins=[]);
    rig +>:Wears(role="upper"):+> ModelResource(name="upper", model=AnimatedModel(), skins=[]);
    bot +>:HasVisual:+> rig;
    bot +>:Empowered:+> Powerup(kind="quad", remaining=30.0);
    move_to_area(bot, area);
    gather = world spawn GatherModels();
    shells = [draw for draw in gather.draws if draw.shader == "shader:powerups/quad"];
    assert len(gather.draws) == 2 and len(shells) == 1;
    print("ok");
}
