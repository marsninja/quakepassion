"""A Q3 bot's personality: the botlib characteristics (botfiles/bots/*_c.c)
and weapon weights (*_w.c) that drive its aim, reactions and tactics, already
resolved for the match's skill level."""
import from ..math.vec3 { Vec3 }

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

# ui_spskill.c's names for g_spSkill 1-5.
glob Q3_SKILL_NAMES: list[str] = ["I Can Win", "Bring It On", "Hurt Me Plenty", "Hardcore", "Nightmare!"];

"""Q3's five skill levels from the game's settings (0-4): Easy is I Can Win,
Normal is Bring It On (g_spSkill's default of 2), Hard is Hurt Me Plenty,
Nightmare is Hardcore, and the fifth setting, which Q1 and Q2 play as
Nightmare, is Nightmare!. Bots take the botlib character of that skill."""
def bot_skill(skill: int) -> float {
    return float(max(1, min(5, skill + 1)));
}

"""g_bot.c G_AddBot's handicap by skill: 50, 70 and 90 for skills 1-3 and
none above. It becomes the bot's maximum health (ClientSpawn) and scales the
damage it deals (G_Damage)."""
def bot_handicap(skill: float) -> int {
    if skill < 2.0 {
        return 50;
    }
    if skill < 3.0 {
        return 70;
    }
    if skill < 4.0 {
        return 90;
    }
    return 100;
}

"""What a Q3 bot is doing moment to moment beyond its character: its view as
BotChangeViewAngles turns it (Quake degrees, stepped every 50 ms server frame
and drawn between frames), its battle node (ai_dmnet.c: "fight", "retreat",
"nbg", "chase", or "" while seeking goals) and BotAttackMove's strafe, jump
and crouch timers."""
obj BotState {
    has clock: float = 0.0,
        view_ready: bool = False,
        view_wait: float = 0.0,
        ideal_yaw: float = 0.0,
        ideal_pitch: float = 0.0,
        from_yaw: float = 0.0,
        from_pitch: float = 0.0,
        yaw: float = 0.0,
        pitch: float = 0.0,
        yaw_speed: float = 0.0,
        pitch_speed: float = 0.0,
        battle: str = "",
        battle_time: float = 0.0,
        check_time: float = 0.0,
        seen_time: float = 0.0,
        chase_target: Vec3 = Vec3(),
        nearby_goal: Vec3 | None = None,
        strafe_right: bool = False,
        strafe_time: float = 0.0,
        jump_time: float = -10.0,
        crouch_time: float = -10.0;
}
