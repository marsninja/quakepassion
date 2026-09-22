"""Weapon descriptions shared by game rules, pickups and combat simulation."""
obj WeaponRule {
    has slot: int,
        key: str,
        name: str,
        ammo: str = "",
        capacity: int = 0,
        pickup_ammo: int = 0,
        cost: int = 1,
        damage: int = 10,
        interval: float = 0.1,
        pellets: int = 1,
        spread: float = 0.0,
        vertical_spread: float = 0.0,
        reach: float = 8192.0,
        speed: float = 0.0,
        splash: int = 0,
        radius: float = 0.0,
        gravity: bool = False,
        fuse: float = 5.0,
        piercing: bool = False,
        model: str = "";
}
