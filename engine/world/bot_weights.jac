"""What a Q3 bot's fuzzy weights read: its inventory as botlib numbers it
(botfiles/inv.h), filled by ai_dmq3.c BotUpdateInventory and, in a fight,
BotUpdateBattleInventory; and be_ai_weap.c BotChooseBestFightWeapon over
the character's weapon weights."""
import from .world { Actor }
import from .inventory { quantity }
import from .powerups { empowered }
import from ..formats.botconfig { WeightConfig }

# botfiles/inv.h inventory indices.
glob INVENTORY_ARMOR: int = 1,
    INVENTORY_GAUNTLET: int = 4,
    INVENTORY_SHOTGUN: int = 5,
    INVENTORY_MACHINEGUN: int = 6,
    INVENTORY_GRENADELAUNCHER: int = 7,
    INVENTORY_ROCKETLAUNCHER: int = 8,
    INVENTORY_LIGHTNING: int = 9,
    INVENTORY_RAILGUN: int = 10,
    INVENTORY_PLASMAGUN: int = 11,
    INVENTORY_BFG10K: int = 13,
    INVENTORY_SHELLS: int = 18,
    INVENTORY_BULLETS: int = 19,
    INVENTORY_GRENADES: int = 20,
    INVENTORY_CELLS: int = 21,
    INVENTORY_LIGHTNINGAMMO: int = 22,
    INVENTORY_ROCKETS: int = 23,
    INVENTORY_SLUGS: int = 24,
    INVENTORY_BFGAMMO: int = 25,
    INVENTORY_HEALTH: int = 29,
    INVENTORY_TELEPORTER: int = 30,
    INVENTORY_MEDKIT: int = 31,
    INVENTORY_QUAD: int = 35,
    INVENTORY_ENVIRONMENTSUIT: int = 36,
    INVENTORY_HASTE: int = 37,
    INVENTORY_INVISIBILITY: int = 38,
    INVENTORY_REGEN: int = 39,
    INVENTORY_FLIGHT: int = 40,
    ENEMY_HORIZONTAL_DIST: int = 200,
    ENEMY_HEIGHT: int = 201;

# be_ai_goal.c MAX_ITEMS: the size of a bot's inventory.
glob BOT_INVENTORY_SIZE: int = 256;

# Each Q3 weapon's inventory index and its ammo's, by the game's weapon key.
glob INVENTORY_WEAPONS: dict[str, tuple[int, str, int]] = {
    "gauntlet": (INVENTORY_GAUNTLET, "", 0),
    "shotgun": (INVENTORY_SHOTGUN, "shells", INVENTORY_SHELLS),
    "machinegun": (INVENTORY_MACHINEGUN, "bullets", INVENTORY_BULLETS),
    "grenadelauncher": (INVENTORY_GRENADELAUNCHER, "grenades", INVENTORY_GRENADES),
    "rocketlauncher": (INVENTORY_ROCKETLAUNCHER, "rockets", INVENTORY_ROCKETS),
    "lightning": (INVENTORY_LIGHTNING, "lightning", INVENTORY_LIGHTNINGAMMO),
    "railgun": (INVENTORY_RAILGUN, "slugs", INVENTORY_SLUGS),
    "plasmagun": (INVENTORY_PLASMAGUN, "cells", INVENTORY_CELLS),
    "bfg": (INVENTORY_BFG10K, "bfg", INVENTORY_BFGAMMO)
};

# The powerups by the game's kinds.
glob INVENTORY_POWERUPS: dict[str, int] = {
    "quad": INVENTORY_QUAD,
    "battlesuit": INVENTORY_ENVIRONMENTSUIT,
    "haste": INVENTORY_HASTE,
    "invisibility": INVENTORY_INVISIBILITY,
    "regen": INVENTORY_REGEN,
    "flight": INVENTORY_FLIGHT
};

"""ai_dmq3.c BotUpdateInventory: armor, weapons owned, ammo, health, the
holdable item and the powerups running."""
def bot_inventory(bot: Actor) -> list[int] {
    inventory = [0 for i in range(BOT_INVENTORY_SIZE)];
    held = bot.inventory;
    inventory[INVENTORY_ARMOR] = bot.armor;
    for (key, slots) in INVENTORY_WEAPONS.items() {
        inventory[slots[0]] = 1 if quantity(held, "weapon_" + key) > 0 else 0;
        if slots[1] {
            inventory[slots[2]] = quantity(held, slots[1]);
        }
    }
    inventory[INVENTORY_HEALTH] = bot.health;
    inventory[INVENTORY_TELEPORTER] = 1 if quantity(held, "holdable_teleporter") > 0 else 0;
    inventory[INVENTORY_MEDKIT] = 1 if quantity(held, "holdable_medkit") > 0 else 0;
    for (kind, index) in INVENTORY_POWERUPS.items() {
        inventory[index] = 1 if empowered(bot, kind) else 0;
    }
    return inventory;
}

"""ai_dmq3.c BotUpdateBattleInventory: the enemy's height over the bot and
its horizontal distance (from origin to origin)."""
def battle_inventory(inventory: list[int], bot: Actor, bot_height: float, enemy: Actor, enemy_height: float) {
    gap = enemy.pos.sub(bot.pos);
    inventory[ENEMY_HEIGHT] = int(gap.z - enemy_height + bot_height);
    inventory[ENEMY_HORIZONTAL_DIST] = int((gap.x * gap.x + gap.y * gap.y) ** 0.5);
}

"""be_ai_weap.c BotChooseBestFightWeapon: the weapon number whose fuzzy
weight is highest (the lowest number among equals), 0 when none weighs
anything. `numbers` gives each weapon number's weight in `weights` (the
character's WeaponWeightIndex)."""
def best_fight_weapon(weights: WeightConfig, numbers: dict[int, int], inventory: list[int]) -> int {
    best = 0;
    best_weight = 0.0;
    for number in sorted(numbers.keys()) {
        index = numbers[number];
        if index < 0 {
            continue;
        }
        weight = weights.weight(inventory, index);
        if weight > best_weight {
            best_weight = weight;
            best = number;
        }
    }
    return best;
}
