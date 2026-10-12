"""An entity as its game shows it when it is spawned: which model or sprite,
with which skin, at which frame; and where the corners of a sprite stand
when it faces the eye."""

import from engine.math.vec3 { Vec3 }
import from engine.formats.animated { AnimatedModel }

"""Whether a file is a sprite: a flat picture that always faces the eye."""
def is_sprite(path: str) -> bool {
    low = path.lower();
    return low.endswith(".spr") or low.endswith(".sp2");
}

"""The sprite a game shows for a class whose rules name no model (""
when it shows none): Quake's bubbles rising through water."""
def class_sprite(game: str, classname: str) -> str {
    if game == "q1" and classname == "air_bubbles" {
        return "progs/s_bubble.spr";
    }
    return "";
}

"""What an entity is shown as: the game whose files it is read from, the
model's or sprite's file there, and the skin and frame it is spawned with."""
obj EntityLook {
    has game: str = "",
        path: str = "",
        skin: int = 0,
        frame: int = 0;

    """What it is kept under once read: the frame is not part of it, since
    every frame of a model is read with it."""
    def key -> str {
        return self.game + ":" + self.path + "#" + str(self.skin);
    }

    def sprite -> bool {
        return is_sprite(self.path);
    }
}

"""A look once read: a model with a kept picture's name for each of its
surfaces ("" for a surface whose skin did not read), or a sprite's one
picture and how large it stands in the world."""
obj PreviewLook {
    has model: AnimatedModel | None = None,
        pictures: list[str] = [],
        picture: str = "",
        wide: float = 0.0,
        tall: float = 0.0;

    """Whether there is anything of it to draw with its own colours."""
    def skinned -> bool {
        return self.picture != "" or (self.model is not None and len([name for name in self.pictures if name != ""]) > 0);
    }
}

"""The four corners of a sprite that faces the eye, about a point: top
left, top right, bottom right, bottom left, as the eye sees them. `right`
and `up` are the view's own."""
def sprite_corners(at: Vec3, right: Vec3, up: Vec3, wide: float, tall: float) -> list[Vec3] {
    across = right.scale(wide * 0.5);
    above = up.scale(tall * 0.5);
    return [at.sub(across).add(above), at.add(across).add(above), at.add(across).sub(above), at.sub(across).sub(above)];
}

"""A point of a model where it stands in the level: turned about the
upright axis (by the turn's cosine and sine) and moved to where the entity is."""
def stood_at(point: Vec3, at: Vec3, cosine: float, sine: float) -> Vec3 {
    return Vec3(x=at.x + point.x * cosine - point.y * sine, y=at.y + point.x * sine + point.y * cosine, z=at.z + point.z);
}

"""The frame of a model that is shown when frame `wanted` is asked for and
it has `count`: the last when there are not so many, the first when there
are none to choose from."""
def frame_shown(wanted: int, count: int) -> int {
    return max(0, min(wanted, count - 1));
}
