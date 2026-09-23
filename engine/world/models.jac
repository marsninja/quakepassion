"""Visual components and shared model resources attached to world entities."""
import math;
import from .world { World, Area, Entity, In }
import from ..formats.animated { AnimatedModel }
import from ..formats.bsp { Texture }
import from ..math.vec3 { Vec3 }

edge HasVisual: Entity --> Visual {}
edge UsesModel: Visual --> ModelResource {}
edge HasModelResource: World --> ModelResource {}

node ModelResource {
    has name: str,
        model: AnimatedModel,
        skins: list[Texture];
}

node Visual {
    has offset: Vec3 = Vec3(),
        first: int = 0,
        second: int = 0,
        blend: float = 0.0,
        visible: bool = True,
        spin: float = 0.0,
        bob: float = 0.0,
        bob_rate: float = 5.0,
        pitch: float = 0.0,
        roll: float = 0.0;
}

obj ModelDraw {
    has resource: ModelResource,
        origin: Vec3,
        yaw: float,
        first: int,
        second: int,
        blend: float,
        pitch: float = 0.0,
        roll: float = 0.0;
}

"""Collect visible models. Items spin on the shared world clock and may bob,
as every client did (Q1/Q2 autorotate, Q3 cg.autoAngles and item bobbing)."""
walker GatherModels {
    has draws: list[ModelDraw] = [],
        seconds: float = 0.0;

    can begin with World entry {
        visit [here-->[?:Area]];
    }

    can area with Area entry {
        visit [here<-:In:<-];
    }

    can entity with Entity entry {
        for visual in [here->:HasVisual:->][?:Visual] {
            if not visual.visible {
                continue;
            }
            origin = here.pos.add(visual.offset);
            yaw = here.yaw;
            if visual.spin != 0.0 {
                yaw = math.radians((visual.spin * self.seconds) % 360.0);
            }
            if visual.bob != 0.0 {
                origin = origin.add(
                    Vec3(
                        z=visual.bob
                            + math.cos((self.seconds + 1.0) * visual.bob_rate) * visual.bob
                    )
                );
            }
            for resource in [visual->:UsesModel:->][?:ModelResource] {
                self.draws.append(
                    ModelDraw(
                        resource=resource,
                        origin=origin,
                        yaw=yaw,
                        first=visual.first,
                        second=visual.second,
                        blend=visual.blend,
                        pitch=visual.pitch,
                        roll=visual.roll
                    )
                );
            }
        }
    }
}


def attach_model(entity: Entity, resource: ModelResource) -> Visual {
    visual = Visual();
    entity +>:HasVisual:+> visual;
    visual +>:UsesModel:+> resource;
    return visual;
}
