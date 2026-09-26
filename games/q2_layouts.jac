"""Quake II's 2D screens as the game wrote them: the help computer and the
unit summary as layout programs (p_hud.c HelpComputer, drawn by the client's
SCR_ExecuteLayoutString), and the inventory list (cl_inv.c CL_DrawInventory)."""
import from engine.render.hud { InventoryRow, pad_number }
import from engine.world.world { Player }
import from engine.world.inventory { quantity }
import from engine.world.weapons { WeaponRule }
import from .items { Q2_PICKUPS }

"""p_hud.c HelpComputer's skill word."""
def help_skill(skill: int) -> str {
    return ["easy", "medium", "hard", "hard+"][max(0, min(3, skill))];
}

"""A layout string argument: quotes would end it early, so they go."""
def layout_text(text: str) -> str {
    return text.replace("\"", "'");
}

"""The tallies line under " kills     goals    secrets"
("%3i/%3i     %i/%i       %i/%i")."""
def help_tallies(
    kills: int, total_kills: int, goals: int, total_goals: int, secrets: int, total_secrets: int
) -> str {
    return pad_number(kills, 3)
        + "/"
        + pad_number(total_kills, 3)
        + "     "
        + str(goals)
        + "/"
        + str(total_goals)
        + "       "
        + str(secrets)
        + "/"
        + str(total_secrets);
}

"""HelpComputer: help.pcx with the skill, the level name, the primary and
secondary objectives (game.helpmessage1/2) and the kill, goal and secret
counts."""
def help_computer_layout(
    skill: int,
    level_name: str,
    primary: str,
    secondary: str,
    kills: int,
    total_kills: int,
    goals: int,
    total_goals: int,
    secrets: int,
    total_secrets: int
) -> str {
    return "xv 32 yv 8 picn help "
        + "xv 202 yv 12 string2 \"" + help_skill(skill) + "\" "
        + "xv 0 yv 24 cstring2 \"" + layout_text(level_name) + "\" "
        + "xv 0 yv 54 cstring2 \"" + layout_text(primary) + "\" "
        + "xv 0 yv 110 cstring2 \"" + layout_text(secondary) + "\" "
        + "xv 50 yv 164 string2 \" kills     goals    secrets\" "
        + "xv 50 yv 172 string2 \""
        + help_tallies(kills, total_kills, goals, total_goals, secrets, total_secrets)
        + "\" ";
}

"""The end-of-unit summary. Single-player Quake II shows only the
intermission view here; this keeps the help computer's frame and tallies for
the unit's last level, with the time in the primary slot and the prompt in
the secondary one."""
def unit_summary_layout(
    skill: int,
    level_name: str,
    seconds: int,
    kills: int,
    total_kills: int,
    goals: int,
    total_goals: int,
    secrets: int,
    total_secrets: int,
    ready: bool
) -> str {
    time = str(seconds // 60) + ":" + str((seconds % 60) // 10) + str(seconds % 10);
    return help_computer_layout(
        skill,
        level_name,
        "Unit complete\n\nTime " + time,
        "Press fire to continue" if ready else "",
        kills,
        total_kills,
        goals,
        total_goals,
        secrets,
        total_secrets
    );
}

# g_items.c itemlist order for what the inventory lists: armor, power armor,
# weapons (the hand grenades are the "Grenades" ammo), ammo, stored
# powerups, keys. Each entry is (inventory kind, pickup name).
glob Q2_INVENTORY_ORDER: list[tuple[str, str]] = [
    ("armor_body", "Body Armor"),
    ("armor_combat", "Combat Armor"),
    ("armor_jacket", "Jacket Armor"),
    ("power_screen", "Power Screen"),
    ("power_shield", "Power Shield"),
    ("blaster", "Blaster"),
    ("shotgun", "Shotgun"),
    ("supershotgun", "Super Shotgun"),
    ("machinegun", "Machinegun"),
    ("chaingun", "Chaingun"),
    ("grenades", "Grenades"),
    ("grenadelauncher", "Grenade Launcher"),
    ("rocketlauncher", "Rocket Launcher"),
    ("hyperblaster", "HyperBlaster"),
    ("railgun", "Railgun"),
    ("bfg", "BFG10K"),
    ("shells", "Shells"),
    ("bullets", "Bullets"),
    ("cells", "Cells"),
    ("rockets", "Rockets"),
    ("slugs", "Slugs"),
    ("powerup_quad", "Quad Damage"),
    ("powerup_invulnerability", "Invulnerability"),
    ("powerup_silencer", "Silencer"),
    ("powerup_breather", "Rebreather"),
    ("powerup_suit", "Environment Suit")
];

"""The Q2 default.cfg binds the engine honours: the weapon number keys and
g for grenades."""
glob Q2_INVENTORY_BINDS: dict[str, str] = {
    "blaster": "1",
    "shotgun": "2",
    "supershotgun": "3",
    "machinegun": "4",
    "chaingun": "5",
    "grenadelauncher": "6",
    "rocketlauncher": "7",
    "hyperblaster": "8",
    "railgun": "9",
    "bfg": "0",
    "grenades": "g"
};

"""What CL_DrawInventory lists for `player`: every carried item with its
count in itemlist order, the selected stored item marked."""
def q2_inventory_rows(player: Player, rules: list[WeaponRule], selected: str) -> list[InventoryRow] {
    counts: dict[str, int] = {};
    # Worn armor is one item whose count is its points (ArmorIndex).
    if player.armor > 0 {
        worn = "armor_body"
            if player.armor_ratio >= 0.8
            else ("armor_combat" if player.armor_ratio >= 0.6 else "armor_jacket");
        counts[worn] = player.armor;
    }
    for rule in rules {
        if not rule.hand_thrown and quantity(player.inventory, "weapon_" + rule.key) > 0 {
            counts[rule.key] = 1;
        }
    }
    for item in Q2_INVENTORY_ORDER {
        if item[0] not in counts {
            amount = quantity(player.inventory, item[0]);
            if amount > 0 {
                counts[item[0]] = amount;
            }
        }
    }
    rows: list[InventoryRow] = [];
    for item in Q2_INVENTORY_ORDER {
        if item[0] in counts {
            rows.append(
                InventoryRow(
                    bind=Q2_INVENTORY_BINDS.get(item[0], ""),
                    count=counts[item[0]],
                    name=item[1],
                    selected=item[0] == selected
                )
            );
        }
    }
    for (kind, shown) in Q2_PICKUPS.items() {
        if kind.startswith("key_") {
            amount = quantity(player.inventory, kind);
            if amount > 0 {
                rows.append(
                    InventoryRow(count=amount, name=shown[0], selected=kind == selected)
                );
            }
        }
    }
    return rows;
}
