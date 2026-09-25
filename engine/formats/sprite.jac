"""Archive-independent sprite frames and named projectile effects."""
obj SpriteFrame {
    has width: int,
        height: int,
        origin_x: int,
        origin_y: int,
        image: str;
}

obj EffectRule {
    has key: str,
        flight: str,
        burst: str = "",
        spin: float = 0.0,
        sprite_size: int = 32,
        additive: bool = False,
        rotate: float = 0.0,
        images: list[str] = [],
        fps: float = 10.0,
        grow: float = 0.0,
        skins: int = 1,
        frames: list[int] = [],
        explosion: bool = False;
}
