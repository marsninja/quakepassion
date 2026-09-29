"""Archive-independent sprite frames and named projectile effects."""
obj SpriteFrame {
    has width: int,
        height: int,
        origin_x: int,
        origin_y: int,
        image: str;
}

"""A named effect: what a missile looks like in `flight` and as it bursts, or
an `explosion` (a model or sprite; Q2's change `skins` and start on one of
`frames`, a tenth of a second a frame at `fps`). A Q3 explosion draws a
`shader`: over its model when `flight` names one, else as a sprite
`sprite_size` across growing by `grow` over its life
(CG_AddSpriteExplosion)."""
obj EffectRule {
    has key: str,
        flight: str,
        burst: str = "",
        spin: float = 0.0,
        sprite_size: int = 32,
        additive: bool = False,
        rotate: float = 0.0,
        fps: float = 10.0,
        grow: float = 0.0,
        skins: int = 1,
        frames: list[int] = [],
        explosion: bool = False,
        shader: str = "",
        # The looping sound it makes in flight (Q2 s.sound, Q3 missileSound).
        sound: str = "";
}
