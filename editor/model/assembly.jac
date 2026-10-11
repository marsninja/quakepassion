"""Models put together as the game puts them together, to be looked at as
one: a Quake III body, whose legs, torso and head are models of their own
joined each frame through the tags `tag_torso` and `tag_head`, with what it
holds on `tag_weapon`; and a weapon as the player sees it in hand, which in
Quake III rides a hand model's `tag_weapon`. The joining is the engine's own
(`lerp_tag`, `Placement.on_tag`); what is made here is one model whose
frames are the figure's, so that whatever shows a model shows the figure."""

import from engine.math.vec3 { Vec3 }
import from engine.math.orientation { Basis }
import from engine.formats.animated { AnimatedModel, AnimatedSurface, AnimationFrame }
import from engine.world.models { lerp_tag, Placement, AnimationClip }
import from engine.world.weapons { ViewWeaponRule }

"""Where a figure stands before anything is hung on anything: at the origin,
facing along x."""
def standing -> Placement {
    return Placement(origin=Vec3(), basis=Basis(forward=Vec3(x=1.0), left=Vec3(y=1.0), up=Vec3(z=1.0)));
}

"""A model's points at one of its frames, carried to where a placement puts
them: one list for each of its surfaces."""
def placed_points(model: AnimatedModel, frame: int, place: Placement) -> list[list[Vec3]] {
    found: list[list[Vec3]] = [];
    for surface in model.surfaces {
        if len(surface.frames) == 0 {
            found.append([]);
            continue;
        }
        stood = surface.frames[max(0, min(frame, len(surface.frames) - 1))].vertices;
        found.append([place.origin.add(place.basis.apply(point)) for point in stood]);
    }
    return found;
}

"""The frames a sequence of a body plays, in the order it plays them."""
def clip_frames(clip: AnimationClip) -> list[int] {
    frames = [clip.first + index for index in range(max(1, clip.count))];
    if clip.reversed {
        frames.reverse();
    }
    return frames;
}

"""The frames a weapon in hand shows: at rest, and then through a shot. A
last frame below zero is the model's last."""
def rule_frames(rule: ViewWeaponRule, count: int) -> list[int] {
    frames: list[int] = [];
    for (first, last) in [(rule.idle_first, rule.idle_last), (rule.fire_first, rule.fire_last)] {
        end = count - 1 if last < 0 else min(last, count - 1);
        for frame in range(max(0, first), end + 1) {
            if frame not in frames {
                frames.append(frame);
            }
        }
    }
    return frames if len(frames) > 0 else [0];
}

"""Start a figure's model: a surface for each surface of each part, named by
the part, with no frames yet."""
def:priv begun(parts: list[tuple[str, AnimatedModel]]) -> AnimatedModel {
    made = AnimatedModel();
    for (name, model) in parts {
        for surface in model.surfaces {
            made.surfaces.append(
                AnimatedSurface(
                    name=name + ":" + surface.name,
                    indices=list(surface.indices),
                    uv=list(surface.uv),
                    skins=list(surface.skins),
                    embedded_skins=list(surface.embedded_skins)
                )
            );
        }
    }
    return made;
}

"""A body as one model. Frame i of it has the legs at `legs[i]` and the
torso at `torso[i]` (the shorter list going round again), the torso on the
legs' `tag_torso`, the head on the torso's `tag_head`, and a weapon, when
there is one, on the torso's `tag_weapon`. A part whose tag is missing is
left where the part it should hang from stands."""
def body_model(
    lower: AnimatedModel,
    upper: AnimatedModel,
    head: AnimatedModel | None,
    weapon: AnimatedModel | None,
    legs: list[int],
    torso: list[int]
) -> AnimatedModel {
    parts: list[tuple[str, AnimatedModel]] = [("legs", lower), ("torso", upper)];
    if head is not None {
        parts.append(("head", head));
    }
    if weapon is not None {
        parts.append(("weapon", weapon));
    }
    made = begun(parts);
    count = max(len(legs), len(torso));
    if len(legs) == 0 or len(torso) == 0 {
        return made;
    }
    for index in range(count) {
        legs_at = legs[index % len(legs)];
        torso_at = torso[index % len(torso)];
        ground = standing();
        chest = ground;
        mount = lerp_tag(lower, legs_at, legs_at, 0.0, "tag_torso");
        if mount is not None {
            chest = ground.on_tag(mount);
        }
        placed = placed_points(lower, legs_at, ground) + placed_points(upper, torso_at, chest);
        if head is not None {
            neck = lerp_tag(upper, torso_at, torso_at, 0.0, "tag_head");
            placed += placed_points(head, 0, chest.on_tag(neck) if neck is not None else chest);
        }
        if weapon is not None {
            hand = lerp_tag(upper, torso_at, torso_at, 0.0, "tag_weapon");
            placed += placed_points(weapon, 0, chest.on_tag(hand) if hand is not None else chest);
        }
        for (number, surface) in enumerate(made.surfaces) {
            surface.frames.append(
                AnimationFrame(name="legs " + str(legs_at) + " torso " + str(torso_at), vertices=placed[number])
            );
        }
    }
    return made;
}

"""A weapon as it is held in view, as one model: at each of `frames`, the
gun's own frame; or, when it rides a hand, the gun (and its barrel, on the
gun's `tag_barrel`) placed on the hand's `tag_weapon` at that frame of the
hand. The eye is at the origin, looking along x."""
def held_model(
    gun: AnimatedModel, hand: AnimatedModel | None, frames: list[int], barrel: AnimatedModel | None = None
) -> AnimatedModel {
    parts: list[tuple[str, AnimatedModel]] = [("gun", gun)];
    if barrel is not None {
        parts.append(("barrel", barrel));
    }
    made = begun(parts);
    for frame in frames {
        grip = standing();
        gun_at = frame;
        if hand is not None and len(hand.tags) > 0 {
            held = lerp_tag(hand, frame, frame, 0.0, "tag_weapon");
            if held is not None {
                grip = grip.on_tag(held);
            }
            gun_at = 0;
        }
        placed = placed_points(gun, gun_at, grip);
        if barrel is not None {
            turning = lerp_tag(gun, 0, 0, 0.0, "tag_barrel");
            placed += placed_points(barrel, 0, grip.on_tag(turning) if turning is not None else grip);
        }
        for (number, surface) in enumerate(made.surfaces) {
            surface.frames.append(AnimationFrame(name="frame " + str(frame), vertices=placed[number]));
        }
    }
    return made;
}
