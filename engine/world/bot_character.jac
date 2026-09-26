"""A Q3 bot's personality: the botlib characteristics (botfiles/bots/*_c.c)
and weapon weights (*_w.c) that drive its aim, reactions and tactics, already
resolved for the match's skill level."""
import from .world { Actor }
import from .inventory { quantity }
import from .powerups { empowered }
import from ..physics.collision { CollisionMap }
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
        crouch_time: float = -10.0,
        enemy: Actor | None = None,
        last_health: int = 0,
        view_target: Vec3 = Vec3();
}

"""ai_dmq3.c BotEntityVisible for a player's box: the bot's eye sees the
middle of the box (4 units over the origin), or else its bottom or top."""
def entity_visible(collision: CollisionMap, eye: Vec3, origin: Vec3) -> bool {
    for rise in [4.0, -20.0, 36.0] {
        sight = collision.trace_point(eye, origin.add(Vec3(z=rise)));
        if not sight.start_solid and sight.fraction >= 1.0 {
            return True;
        }
    }
    return False;
}

"""The field of view BotFindEnemy looks for a new enemy in, in degrees: all
round when the bot was just hurt or the enemy is shooting, otherwise from 90
degrees up close widening to 180 at 810 units."""
def enemy_view(distance: float, alarmed: bool) -> float {
    if alarmed {
        return 360.0;
    }
    near = min(distance * distance, 810.0 * 810.0);
    return 90.0 + near / (810.0 * 9.0);
}

"""ai_dmq3.c BotAggression: how keen the bot is to fight, from its weapons,
ammo, health and armor and where the enemy stands."""
def bot_aggression(bot: Actor, foe: Actor, weapon: str) -> float {
    inventory = bot.inventory;
    horizontal = Vec3(x=foe.pos.x - bot.pos.x, y=foe.pos.y - bot.pos.y).length();
    if empowered(bot, "quad") and (weapon != "gauntlet" or horizontal < 80.0) {
        return 70.0;
    }
    if foe.pos.z - bot.pos.z > 200.0 {
        return 0.0;
    }
    if bot.health < 60 or (bot.health < 80 and bot.armor < 40) {
        return 0.0;
    }
    for choice in [
        ("bfg", "bfg", 7, 100.0),
        ("railgun", "slugs", 5, 95.0),
        ("lightning", "lightning", 50, 90.0),
        ("rocketlauncher", "rockets", 5, 90.0),
        ("plasmagun", "cells", 40, 85.0),
        ("grenadelauncher", "grenades", 10, 80.0),
        ("shotgun", "shells", 10, 50.0)
    ] {
        if quantity(inventory, "weapon_" + choice[0]) > 0 and quantity(inventory, choice[1]) > choice[2] {
            return choice[3];
        }
    }
    return 0.0;
}
