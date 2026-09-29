"""A Q3 bot's personality: the botlib characteristics (botfiles/bots/*_c.c)
that drive its aim, reactions and tactics, resolved for the match's skill
level, with the fuzzy item and weapon weights (*_i.c, *_w.c) it chooses
goals and weapons by and the chats (*_t.c) it says."""
import from .world { Actor, Player }
import from .bot_routes { BotRoute }
import from .bot_travel { TravelResult }
import from ..formats.aas { TFL_DEFAULT, TFL_LAVA, TFL_SLIME, TFL_ROCKETJUMP }
import from ..formats.botconfig { WeightConfig, ChatMessage, WeightDice }
import from .bot_goals { GoalState, BotGoal }
import from .bot_chat { BotChatState }
import from .bot_weights {
    INVENTORY_QUAD,
    INVENTORY_HEALTH,
    INVENTORY_ARMOR,
    INVENTORY_BFG10K,
    INVENTORY_BFGAMMO,
    INVENTORY_RAILGUN,
    INVENTORY_SLUGS,
    INVENTORY_LIGHTNING,
    INVENTORY_LIGHTNINGAMMO,
    INVENTORY_ROCKETLAUNCHER,
    INVENTORY_ROCKETS,
    INVENTORY_PLASMAGUN,
    INVENTORY_CELLS,
    INVENTORY_GRENADELAUNCHER,
    INVENTORY_GRENADES,
    INVENTORY_SHOTGUN,
    INVENTORY_SHELLS,
    ENEMY_HEIGHT,
    ENEMY_HORIZONTAL_DIST
}
import from .inventory { quantity }
import from .powerups { empowered }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }

obj BotCharacter {
    has name: str = "",
        gender: str = "male",
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
        weapon_jumping: float = 0.0,
        alertness: float = 0.5;
    # The fuzzy weights and, for each item classname and weapon number, the
    # weight that rates it (be_ai_goal.c ItemWeightIndex, be_ai_weap.c
    # WeaponWeightIndex; -1 when the character has none).
    has item_weights: WeightConfig = WeightConfig(),
        item_numbers: dict[str, int] = {},
        weapon_weights: WeightConfig = WeightConfig(),
        weapon_numbers: dict[int, int] = {};
    # Chatting (ai_chat.c): the character's initial chats by type, rnd.c's
    # random strings and its tendencies to chat (CHARACTERISTIC_CHAT_*).
    has chats: dict[str, list[ChatMessage]] = {},
        random_strings: dict[str, list[ChatMessage]] = {},
        chat_insult: float = 0.0,
        chat_misc: float = 0.0,
        chat_start_end_level: float = 0.0,
        chat_enter_exit_game: float = 0.0,
        chat_kill: float = 0.0,
        chat_death: float = 0.0,
        chat_enemy_suicide: float = 0.0,
        chat_hit_talking: float = 0.0,
        chat_hit_no_death: float = 0.0,
        chat_hit_no_kill: float = 0.0,
        chat_random: float = 0.0,
        chat_state: BotChatState = BotChatState();

    """Per-weapon accuracy, falling back to the general characteristic."""
    def accuracy_for(weapon: str) -> float {
        return self.accuracy[weapon] if weapon in self.accuracy else self.aim_accuracy;
    }

    """Per-weapon aim skill (projectile leading), falling back to the general one."""
    def skill_for(weapon: str) -> float {
        return self.leading[weapon] if weapon in self.leading else self.aim_skill;
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

"""What a Q3 bot is doing moment to moment beyond its character (the
bot_state_t of ai_main.h). Its view as BotChangeViewAngles turns it (Quake
degrees, stepped every 50 ms server frame and drawn between frames);
BotAttackMove's strafe, jump and crouch timers; and its AI: the ai_dmnet.c
node it is in (`ainode`), that node's timers on the level clock, its enemy
(`enemy`, bs->enemy) and what it remembers of it, its goals, what it last
killed and what killed it, and the route and travel it moves by. A bot gets a
fresh state each time it respawns, as botlib resets its move and goal
states."""
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
        strafe_right: bool = False,
        strafe_time: float = 0.0,
        jump_time: float = -10.0,
        crouch_time: float = -10.0,
        last_health: int = 0,
        view_target: Vec3 = Vec3(),
        sight_target: Actor | None = None,
        sight: bool = False,
        thought: bool = False,
        gesture: bool = False;
    # ai_dmnet.c: the node, and the battle node's name ("fight", "chase",
    # "retreat", "nbg", or "" in the other nodes) for what reads it.
    has ainode: str = "seek_ltg",
        battle: str = "",
        suicidal: bool = False,
        inventory: list[int] = [],
        goals: GoalState = GoalState(),
        dice: WeightDice = WeightDice(),
        ltg_time: float = 0.0,
        nbg_time: float = 0.0,
        check_time: float = 0.0,
        chase_time: float = 0.0,
        stand_time: float = 0.0,
        stand_find_enemy_time: float = 0.0,
        respawn_time: float = 0.0,
        respawn_chat_time: float = 0.0,
        respawn_waiting: bool = False,
        respawn_minimum: float = 0.0,
        last_frame_health: int = -1,
        last_hit_count: int = 0,
        # The last think the bot had air (lastair_time, BotCheckAir).
        last_air_time: float = 0.0;
    # The enemy (bs->enemy) and what the bot keeps of it.
    has enemy: Player | None = None,
        enemy_visible_time: float = 0.0,
        enemy_death_time: float = 0.0,
        enemy_suicide: bool = False,
        last_enemy_origin: Vec3 = Vec3(),
        last_enemy_area: int = 0;
    # BotCheckSnapshot's obituaries: the last seen, and what they said.
    has obituary_serial: int = 0,
        last_killed_player: Player | None = None,
        last_killed_by: Player | None = None,
        bot_death_means: str = "",
        bot_suicide: bool = False,
        enemy_death_means: str = "",
        killed_enemy_time: float = -100.0;
    # What the AI asks of the body this think: a goal to move to (and its
    # AAS area), whether to fight in place (BotAttackMove), and where to
    # look ("movement", "enemy" or "chase").
    has move_goal: BotGoal | None = None,
        goal_area: int = 0,
        move_failed: bool = False,
        view_mode: str = "movement",
        talking: bool = False;
    has travel_flags: int = TFL_DEFAULT,
        route: BotRoute = BotRoute(),
        travel: TravelResult = TravelResult();
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

"""ai_dmq3.c BotAggression: how keen the bot is to fight, from its inventory
(with the enemy's height and distance, BotUpdateBattleInventory) and the
weapon it holds (`weapon`, a weapon number)."""
def bot_aggression(inventory: list[int], weapon: int) -> float {
    if inventory[INVENTORY_QUAD] > 0 and (weapon != 1 or inventory[ENEMY_HORIZONTAL_DIST] < 80) {
        return 70.0;
    }
    if inventory[ENEMY_HEIGHT] > 200 {
        return 0.0;
    }
    if inventory[INVENTORY_HEALTH] < 60 {
        return 0.0;
    }
    if inventory[INVENTORY_HEALTH] < 80 and inventory[INVENTORY_ARMOR] < 40 {
        return 0.0;
    }
    for choice in [
        (INVENTORY_BFG10K, INVENTORY_BFGAMMO, 7, 100.0),
        (INVENTORY_RAILGUN, INVENTORY_SLUGS, 5, 95.0),
        (INVENTORY_LIGHTNING, INVENTORY_LIGHTNINGAMMO, 50, 90.0),
        (INVENTORY_ROCKETLAUNCHER, INVENTORY_ROCKETS, 5, 90.0),
        (INVENTORY_PLASMAGUN, INVENTORY_CELLS, 40, 85.0),
        (INVENTORY_GRENADELAUNCHER, INVENTORY_GRENADES, 10, 80.0),
        (INVENTORY_SHOTGUN, INVENTORY_SHELLS, 10, 50.0)
    ] {
        if inventory[choice[0]] > 0 and inventory[choice[1]] > choice[2] {
            return choice[3];
        }
    }
    return 0.0;
}

"""ai_dmq3.c BotWantsToRetreat (free for all): when not keen to fight."""
def wants_to_retreat(inventory: list[int], weapon: int) -> bool {
    return bot_aggression(inventory, weapon) < 50.0;
}

"""ai_dmq3.c BotWantsToChase (free for all): when keen to fight."""
def wants_to_chase(inventory: list[int], weapon: int) -> bool {
    return bot_aggression(inventory, weapon) > 50.0;
}

"""ai_dmq3.c BotCanAndWantsToRocketJump: a rocket launcher with three
rockets, no quad, 60 health (90, or 40 armor with less) and a character that
likes weapon jumping (at least 0.5)."""
def can_rocket_jump(bot: Actor, mind: BotCharacter) -> bool {
    inventory = bot.inventory;
    if quantity(inventory, "weapon_rocketlauncher") <= 0 or quantity(inventory, "rockets") < 3 {
        return False;
    }
    if empowered(bot, "quad") or bot.health < 60 {
        return False;
    }
    if bot.health < 90 and bot.armor < 40 {
        return False;
    }
    return mind.weapon_jumping >= 0.5;
}

"""The travel flags a bot routes with this think (ai_dmnet.c's bs->tfl):
TFL_DEFAULT, lava and slime while in them (BotInLavaOrSlime) and rocket
jumps when it can and wants to."""
def bot_travel_flags(bot: Actor, mind: BotCharacter, liquid: int, rocket_jumps: bool = True) -> int {
    flags = TFL_DEFAULT;
    if liquid in [2, 3] {
        flags |= TFL_LAVA | TFL_SLIME;
    }
    if rocket_jumps and can_rocket_jump(bot, mind) {
        flags |= TFL_ROCKETJUMP;
    }
    return flags;
}
