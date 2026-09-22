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
        burst: str = "";
}
