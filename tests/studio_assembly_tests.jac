import from engine.math.vec3 { Vec3 }
import from engine.formats.animated { AnimatedModel, AnimatedSurface, AnimationFrame, ModelTag, TagFrame }
import from engine.world.models { AnimationClip }
import from engine.world.weapons { ViewWeaponRule }
import from editor.model.assembly { standing, placed_points, clip_frames, rule_frames, body_model, held_model }

def near(a: Vec3, b: Vec3, slack: float = 0.001) -> bool {
    return a.sub(b).length() < slack;
}

"""A model of one triangle that stands in one place at every frame but
rises by a unit each frame, with tags of its own at each frame."""
def piece(name: str, at: Vec3, frames: int, tags: list[list[ModelTag]] = []) -> AnimatedModel {
    surface = AnimatedSurface(name=name, indices=[0, 1, 2], uv=[0.0, 0.0, 1.0, 0.0, 0.0, 1.0]);
    for frame in range(frames) {
        lift = Vec3(z=float(frame));
        surface.frames.append(
            AnimationFrame(vertices=[at.add(lift), at.add(lift).add(Vec3(x=1.0)), at.add(lift).add(Vec3(y=1.0))])
        );
    }
    return AnimatedModel(surfaces=[surface], tags=[TagFrame(tags=each) for each in tags]);
}

"""A tag at a place, turned a quarter about the upright when asked: what
hangs from it then faces along y."""
def tag(name: str, at: Vec3, turned: bool = False) -> ModelTag {
    axes = [Vec3(y=1.0), Vec3(x=-1.0), Vec3(z=1.0)] if turned else [Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)];
    return ModelTag(name=name, origin=at, axes=axes);
}

test "a model's points are carried to where it is placed" {
    model = piece("leg", Vec3(x=2.0), 3);
    still = placed_points(model, 1, standing());
    assert len(still) == 1 and near(still[0][0], Vec3(x=2.0, z=1.0)) and near(still[0][1], Vec3(x=3.0, z=1.0));
    # On a tag ten up and turned a quarter: along x becomes along y.
    hung = placed_points(model, 0, standing().on_tag(tag("t", Vec3(z=10.0), True)));
    assert near(hung[0][0], Vec3(y=2.0, z=10.0)) and near(hung[0][2], Vec3(x=-1.0, y=2.0, z=10.0));
    # A frame past the last is the last; a surface with no frames has no points.
    assert near(placed_points(model, 99, standing())[0][0], Vec3(x=2.0, z=2.0));
    assert placed_points(AnimatedModel(surfaces=[AnimatedSurface(name="bare")]), 0, standing()) == [[]];
}

test "a body is its legs, torso and head joined by their tags at each frame" {
    # The legs carry the torso higher at their second frame; the torso holds its head and its weapon.
    lower = piece("legs", Vec3(), 2, [[tag("tag_torso", Vec3(z=10.0))], [tag("tag_torso", Vec3(z=12.0), True)]]);
    upper = piece(
        "chest",
        Vec3(),
        3,
        [
            [tag("tag_head", Vec3(z=5.0)), tag("tag_weapon", Vec3(x=4.0))],
            [tag("tag_head", Vec3(z=5.0)), tag("tag_weapon", Vec3(x=4.0))],
            [tag("tag_head", Vec3(z=6.0)), tag("tag_weapon", Vec3(x=4.0, z=1.0))]
        ]
    );
    head = piece("skull", Vec3(), 1);
    gun = piece("barrel", Vec3(x=1.0), 1);
    body = body_model(lower, upper, head, gun, [0, 1], [0, 1, 2]);
    assert [surface.name for surface in body.surfaces] == ["legs:legs", "torso:chest", "head:skull", "weapon:barrel"];
    assert len(body.surfaces[0].frames) == 3 and body.surfaces[1].indices == [0, 1, 2] and len(body.surfaces[3].uv) == 6;
    assert body.surfaces[0].frames[1].name == "legs 1 torso 1" and body.surfaces[0].frames[2].name == "legs 0 torso 2";
    # At rest: the torso ten up, the head five above that, the gun four ahead of the chest.
    first = [surface.frames[0].vertices[0] for surface in body.surfaces];
    assert near(first[0], Vec3()) and near(first[1], Vec3(z=10.0)) and near(first[2], Vec3(z=15.0)) and near(first[3], Vec3(x=5.0, z=10.0));
    # The second frame: the legs have turned the torso a quarter, and all that hangs from it goes round.
    second = [surface.frames[1].vertices[0] for surface in body.surfaces];
    assert near(second[0], Vec3(z=1.0)) and near(second[1], Vec3(z=13.0)) and near(second[2], Vec3(z=17.0));
    assert near(second[3], Vec3(y=5.0, z=12.0)) and near(body.surfaces[1].frames[1].vertices[1], Vec3(y=1.0, z=13.0));
    # The third: the legs' frames have gone round again, the torso's third lifts the head and the gun.
    third = [surface.frames[2].vertices[0] for surface in body.surfaces];
    assert near(third[1], Vec3(z=12.0)) and near(third[2], Vec3(z=16.0)) and near(third[3], Vec3(x=5.0, z=11.0));
    # Without a head or a weapon there are two parts; with no frames asked, no frames.
    bare = body_model(lower, upper, None, None, [0], [0]);
    assert len(bare.surfaces) == 2 and len(bare.surfaces[0].frames) == 1;
    assert len(body_model(lower, upper, None, None, [], [0]).surfaces[0].frames) == 0;
    # Legs with no tag for the torso leave it where they stand.
    loose = body_model(piece("legs", Vec3(), 1), upper, None, None, [0], [0]);
    assert near(loose.surfaces[1].frames[0].vertices[0], Vec3());
}

test "a sequence's frames, and a weapon's at rest and through a shot" {
    assert clip_frames(AnimationClip(first=4, count=3)) == [4, 5, 6] and clip_frames(AnimationClip(first=4, count=3, reversed=True)) == [6, 5, 4];
    assert clip_frames(AnimationClip(first=9, count=0)) == [9];
    rule = ViewWeaponRule(slot=2, model="progs/v_shot.mdl", fire_first=1, fire_last=6);
    assert rule_frames(rule, 7) == [0, 1, 2, 3, 4, 5, 6] and rule_frames(rule, 4) == [0, 1, 2, 3];
    # A shot that runs to the model's end, and a rest of several frames.
    assert rule_frames(ViewWeaponRule(slot=1, model="m", idle_first=0, idle_last=1, fire_first=4, fire_last=-1), 6) == [0, 1, 4, 5];
    assert rule_frames(ViewWeaponRule(slot=1, model="m", idle_first=3, idle_last=3, fire_first=9, fire_last=9), 2) == [0];
}

test "a weapon in view shows its own frames, or rides a hand's tag" {
    gun = piece("gun", Vec3(x=8.0), 3);
    alone = held_model(gun, None, [0, 2]);
    assert [surface.name for surface in alone.surfaces] == ["gun:gun"] and len(alone.surfaces[0].frames) == 2;
    assert near(alone.surfaces[0].frames[1].vertices[0], Vec3(x=8.0, z=2.0)) and alone.surfaces[0].frames[1].name == "frame 2";
    # A hand with a tag that drops and turns at its second frame: the gun, at its own first frame, goes with it.
    hand = AnimatedModel(
        tags=[TagFrame(tags=[tag("tag_weapon", Vec3(z=-4.0))]), TagFrame(tags=[tag("tag_weapon", Vec3(z=-6.0), True)])]
    );
    cannon = piece("gun", Vec3(x=8.0), 3, [[tag("tag_barrel", Vec3(x=2.0))]]);
    spinner = piece("spin", Vec3(), 1);
    held = held_model(cannon, hand, [0, 1], spinner);
    assert [surface.name for surface in held.surfaces] == ["gun:gun", "barrel:spin"];
    assert near(held.surfaces[0].frames[0].vertices[0], Vec3(x=8.0, z=-4.0)) and near(held.surfaces[1].frames[0].vertices[0], Vec3(x=2.0, z=-4.0));
    assert near(held.surfaces[0].frames[1].vertices[0], Vec3(y=8.0, z=-6.0)) and near(held.surfaces[1].frames[1].vertices[0], Vec3(y=2.0, z=-6.0));
}
