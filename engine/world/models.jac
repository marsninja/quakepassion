"""Visual components and shared model resources attached to world entities."""
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
        visible: bool = True;
}

obj ModelDraw {
    has resource: ModelResource,
        origin: Vec3,
        yaw: float,
        first: int,
        second: int,
        blend: float;
}

walker GatherModels {
    has draws: list[ModelDraw] = [];

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
            for resource in [visual->:UsesModel:->][?:ModelResource] {
                self.draws.append(
                    ModelDraw(
                        resource=resource,
                        origin=here.pos.add(visual.offset),
                        yaw=here.yaw,
                        first=visual.first,
                        second=visual.second,
                        blend=visual.blend
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
