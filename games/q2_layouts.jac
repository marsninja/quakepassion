"""Quake II's 2D screens as the game wrote them: the help computer as a
layout program (p_hud.c HelpComputer, drawn by the client's
SCR_ExecuteLayoutString), the inventory list (cl_inv.c CL_DrawInventory) and
the item it has selected (g_cmds.c SelectNextItem, ValidateSelectedItem)."""
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

# g_items.c: the itemlist entries with a `use` function, which
# SelectNextItem stops at and invuse uses, and their status bar icons
# (STAT_SELECTED_ICON). Armor, the other ammo and keys have none.
glob Q2_USABLE_ITEMS: dict[str, str] = {
    "power_screen": "i_powerscreen",
    "power_shield": "i_powershield",
    "blaster": "w_blaster",
    "shotgun": "w_shotgun",
    "supershotgun": "w_sshotgun",
    "machinegun": "w_machinegun",
    "chaingun": "w_chaingun",
    "grenades": "a_grenades",
    "grenadelauncher": "w_glauncher",
    "rocketlauncher": "w_rlauncher",
    "hyperblaster": "w_hyperblaster",
    "railgun": "w_railgun",
    "bfg": "w_bfg",
    "powerup_quad": "p_quad",
    "powerup_invulnerability": "p_invulnerability",
    "powerup_silencer": "p_silencer",
    "powerup_breather": "p_rebreather",
    "powerup_suit": "p_envirosuit"
};

# client/keys.h: Quake II's key numbers for the keys named rather than
# typed (a character's number is its code). CL_DrawInventory shows the
# lowest-numbered key bound to an item.
glob Q2_KEY_NUMBERS: dict[str, int] = {
    "TAB": 9, "ENTER": 13, "ESCAPE": 27, "SPACE": 32, "BACKSPACE": 127,
    "UPARROW": 128, "DOWNARROW": 129, "LEFTARROW": 130, "RIGHTARROW": 131,
    "ALT": 132, "CTRL": 133, "SHIFT": 134,
    "F1": 135, "F2": 136, "F3": 137, "F4": 138, "F5": 139, "F6": 140,
    "F7": 141, "F8": 142, "F9": 143, "F10": 144, "F11": 145, "F12": 146,
    "INS": 147, "DEL": 148, "PGDN": 149, "PGUP": 150, "HOME": 151, "END": 152,
    "KP_HOME": 160, "KP_UPARROW": 161, "KP_PGUP": 162, "KP_LEFTARROW": 163,
    "KP_5": 164, "KP_RIGHTARROW": 165, "KP_END": 166, "KP_DOWNARROW": 167,
    "KP_PGDN": 168, "KP_ENTER": 169, "KP_INS": 170, "KP_DEL": 171,
    "KP_SLASH": 172, "KP_MINUS": 173, "KP_PLUS": 174,
    "MOUSE1": 200, "MOUSE2": 201, "MOUSE3": 202,
    "MWHEELDOWN": 239, "MWHEELUP": 240, "PAUSE": 255
};

"""A key's Quake II number: its character's code, or its name's in keys.h
(a key Quake II never had sorts after them all)."""
def q2_key_number(name: str) -> int {
    if len(name) == 1 {
        return ord(name);
    }
    return Q2_KEY_NUMBERS.get(name.upper(), 256);
}

"""CL_DrawInventory's search of the bindings: for each "use <item>" binding
(compared without case), the lowest-numbered key that holds it. `names` and
`bindings` are the bound keys and what each is bound to."""
def q2_item_hotkeys(names: list[str], bindings: list[str]) -> dict[str, str] {
    hotkeys: dict[str, str] = {};
    for index in range(min(len(names), len(bindings))) {
        command = bindings[index].lower();
        if not command.startswith("use ") {
            continue;
        }
        if command not in hotkeys or q2_key_number(names[index]) < q2_key_number(hotkeys[command]) {
            hotkeys[command] = names[index];
        }
    }
    return hotkeys;
}

"""pers.inventory[] for the itemlist entries the inventory lists: worn armor
as its points, each owned weapon as one, everything else by its count."""
def q2_item_counts(player: Player, rules: list[WeaponRule]) -> dict[str, int] {
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
    return counts;
}

"""g_cmds.c SelectNextItem and SelectPrevItem with every item flag
(invnext, invprev): from `selected`, the next carried item with a use in
itemlist order (`step` 1) or the one before (-1), wrapping round; "" when
nothing carried can be used (selected_item -1)."""
def q2_step_item(counts: dict[str, int], selected: str, step: int) -> str {
    order = [item[0] for item in Q2_INVENTORY_ORDER];
    total = len(order);
    # From no selection the scan starts off the end it walks away from.
    start = order.index(selected) if selected in order else (-1 if step > 0 else total);
    for offset in range(1, total + 1) {
        kind = order[(start + step * offset) % total];
        if counts.get(kind, 0) > 0 and kind in Q2_USABLE_ITEMS {
            return kind;
        }
    }
    return "";
}

"""g_cmds.c ValidateSelectedItem: the selection stands while the player
carries it; otherwise the next usable item takes its place."""
def q2_validate_item(counts: dict[str, int], selected: str) -> str {
    if counts.get(selected, 0) > 0 {
        return selected;
    }
    return q2_step_item(counts, selected, 1);
}

"""What CL_DrawInventory lists for `player`: every carried item with its
count in itemlist order, the key bound to "use <item>" (`hotkeys`, from
q2_item_hotkeys) and the selected item marked."""
def q2_inventory_rows(
    player: Player, rules: list[WeaponRule], selected: str, hotkeys: dict[str, str] = {}
) -> list[InventoryRow] {
    counts = q2_item_counts(player, rules);
    rows: list[InventoryRow] = [];
    for item in Q2_INVENTORY_ORDER {
        if item[0] in counts {
            rows.append(
                InventoryRow(
                    bind=hotkeys.get("use " + item[1].lower(), ""),
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
                    InventoryRow(
                        bind=hotkeys.get("use " + shown[0].lower(), ""),
                        count=amount,
                        name=shown[0],
                        selected=kind == selected
                    )
                );
            }
        }
    }
    return rows;
}
