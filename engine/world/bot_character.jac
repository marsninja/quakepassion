"""A Q3 bot's personality: the botlib characteristics (botfiles/bots/*_c.c)
and weapon weights (*_w.c) that drive its aim, reactions and tactics, already
resolved for the match's skill level."""

obj BotCharacter {
    has name: str = "",
        skill: float = 3.0,
        aim_skill: float = 0.5,
        aim_accuracy: float = 0.5,
        accuracy: dict[str, float] = {},
        leading: dict[str, float] = {},
        reaction: float = 0.5,
        fire_throttle: float = 1.0,
        view_factor: float = 0.8,
        view_maxchange: float = 240.0,
        attack_skill: float = 0.5,
        aggression: float = 0.5,
        self_preservation: float = 0.5,
        jumper: float = 0.0,
        croucher: float = 0.0,
        alertness: float = 0.5,
        weights: dict[str, int] = {};

    """Per-weapon accuracy, falling back to the general characteristic."""
    def accuracy_for(weapon: str) -> float {
        return self.accuracy[weapon] if weapon in self.accuracy else self.aim_accuracy;
    }

    """Per-weapon aim skill (projectile leading), falling back to the general one."""
    def skill_for(weapon: str) -> float {
        return self.leading[weapon] if weapon in self.leading else self.aim_skill;
    }

    def weight_for(weapon: str) -> int {
        return self.weights[weapon] if weapon in self.weights else 0;
    }
}

"""Q3's five skill levels from the game's four: Easy is Bring It On, Normal is
Hurt Me Plenty (the single-player default), Hard is Hardcore, Nightmare is
Nightmare!"""
def bot_skill(skill: int) -> float {
    return float(max(1, min(5, skill + 2)));
}
