"""Game-owned enemy tuning consumed by shared graph combat behavior."""
obj OpponentRule {
    has model: str = "",
        skin: int = 0,
        health: int = 60,
        speed: float = 100.0,
        damage: int = 4,
        interval: float = 0.8,
        attack_range: float = 1500.0,
        stop_range: float = 180.0,
        melee: int = 0,
        melee_range: float = 64.0,
        missile_speed: float = 0.0,
        missile_effect: str = "",
        gravity: bool = False,
        splash: int = 0,
        radius: float = 0.0;
}
