import math;
import from engine.math.vec3 { Vec3 }
import from engine.formats.animated { AnimatedModel }
import from editor.assets.entitylook { EntityLook, PreviewLook, is_sprite, class_sprite, sprite_corners, stood_at, frame_shown }

def close(a: Vec3, b: Vec3) -> bool {
    return a.sub(b).length() < 0.0001;
}

test "an entity's look is a file, a skin and a frame, kept by the first two" {
    flame = EntityLook(game="q1", path="progs/flame.mdl", skin=0, frame=3);
    assert flame.key() == "q1:progs/flame.mdl#0" and not flame.sprite();
    assert EntityLook(game="q1", path="progs/flame.mdl", skin=0, frame=0).key() == flame.key();
    assert EntityLook(game="q2", path="models/items/armor/body/tris.md2", skin=1).key() != flame.key();
    bubble = EntityLook(game="q1", path=class_sprite("q1", "air_bubbles"));
    assert bubble.sprite() and bubble.path == "progs/s_bubble.spr";
    assert class_sprite("q2", "air_bubbles") == "" and class_sprite("q1", "light") == "";
    assert is_sprite("sprites/s_bfg1.SP2") and not is_sprite("progs/player.mdl");
}

test "a look that read has a picture of its own or a skinned surface" {
    assert not PreviewLook().skinned();
    assert PreviewLook(picture="pv:x", wide=32.0, tall=32.0).skinned();
    assert not PreviewLook(model=AnimatedModel(), pictures=["", ""]).skinned();
    assert PreviewLook(model=AnimatedModel(), pictures=["", "pv:y:1"]).skinned();
    # Pictures with no model to lay them on are nothing to draw.
    assert not PreviewLook(pictures=["pv:y:1"]).skinned();
}

test "a sprite's corners face the eye about where it is" {
    corners = sprite_corners(Vec3(x=10.0, y=20.0, z=30.0), Vec3(y=-1.0), Vec3(z=1.0), 8.0, 4.0);
    assert close(corners[0], Vec3(x=10.0, y=24.0, z=32.0)) and close(corners[1], Vec3(x=10.0, y=16.0, z=32.0));
    assert close(corners[2], Vec3(x=10.0, y=16.0, z=28.0)) and close(corners[3], Vec3(x=10.0, y=24.0, z=28.0));
}

test "a model's point stands turned about the upright and moved to the entity" {
    quarter = math.radians(90.0);
    assert close(stood_at(Vec3(x=4.0, z=2.0), Vec3(x=100.0, y=50.0, z=8.0), math.cos(quarter), math.sin(quarter)), Vec3(x=100.0, y=54.0, z=10.0));
    assert close(stood_at(Vec3(x=4.0, y=1.0), Vec3(), 1.0, 0.0), Vec3(x=4.0, y=1.0));
}

test "the frame shown is the one asked for, or the nearest there is" {
    assert frame_shown(3, 10) == 3 and frame_shown(30, 10) == 9 and frame_shown(-2, 10) == 0 and frame_shown(5, 0) == 0;
}
