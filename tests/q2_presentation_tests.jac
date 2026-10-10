"""Quake II's 2D screens: the help computer's layout program, the inventory
list with its hotkeys and selection, the help computer's beeps and the
status bar's damage flashes."""
import from engine.render.hud { layout_tokens }
import from engine.render.view_feedback { ViewFeedback }
import from engine.world.world { World, Player }
import from engine.world.inventory { AdjustInventory }
import from engine.world.targets { TargetEvent, HasTarget, TargetTick, help_for, carry_help }
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.formats.bsp { Bsp }
import from engine.world.combat { CombatState }
import from engine.physics.collision { CollisionMap }
import from engine.formats.bsp { parse_entities }
import from games.weapons { weapon_rules }
import from engine.input.keys { Keyboard, BoundKeys }
import from games.q2_layouts {
    help_computer_layout,
    help_tallies,
    q2_inventory_rows,
    q2_item_hotkeys,
    q2_item_counts,
    q2_step_item,
    q2_validate_item,
    q2_key_number,
    Q2_USABLE_ITEMS
}

test "layout programs keep quoted strings whole" {
    tokens = layout_tokens("xv 32 yv 8 picn help xv 0 yv 24 cstring2 \"Outer Base\" string2 \"a\nb\"");
    assert tokens == ["xv", "32", "yv", "8", "picn", "help", "xv", "0", "yv", "24", "cstring2", "Outer Base", "string2", "a\nb"];
}

test "the help computer layout follows p_hud.c HelpComputer" {
    layout = help_computer_layout(2, "Outer Base", "Find the CD", "Kill \"all\"", 3, 17, 0, 1, 2, 3);
    tokens = layout_tokens(layout);
    assert tokens[:6] == ["xv", "32", "yv", "8", "picn", "help"];
    assert "hard" in tokens and "Outer Base" in tokens and "Find the CD" in tokens;
    # A quote in a message cannot end its string early.
    assert "Kill 'all'" in tokens;
    assert tokens[-1] == "  3/ 17     0/1       2/3";
    assert help_tallies(12, 117, 1, 2, 0, 5) == " 12/117     1/2       0/5";
}

test "entity messages turn escaped newlines into line breaks" {
    entities = parse_entities("{\n\"classname\" \"target_help\"\n\"message\" \"Locate base installation\\nelevator.\"\n}\n");
    assert entities[0].fields["message"] == "Locate base installation\nelevator.";
}

test "the Q2 inventory lists carried items in itemlist order" {
    player = Player(armor=50, armor_ratio=0.6);
    for (kind, amount) in [
        ("weapon_blaster", 1),
        ("weapon_railgun", 1),
        ("weapon_shotgun", 1),
        ("slugs", 10),
        ("shells", 24),
        ("grenades", 5),
        ("power_shield", 1),
        ("powerup_quad", 1),
        ("key_data_cd", 1)
    ] {
        player.inventory spawn AdjustInventory(kind=kind, amount=amount, capacity=200);
    }
    # CL_DrawInventory searches the bindings for "use <item>", whatever the
    # case, and shows the lowest-numbered key.
    keyboard = Keyboard();
    keyboard.boot();
    keyboard.set_binding("g", "use Grenades");
    keyboard.set_binding("9", "use railgun");
    keyboard.set_binding("MOUSE2", "use Railgun");
    keyboard.set_binding("F5", "use Quad Damage");
    keyboard.set_binding("q", "use Quad Damage");
    keyboard.set_binding("k", "use Data CD");
    keyboard.set_binding("x", "+attack");
    bound = keyboard spawn BoundKeys();
    hotkeys = q2_item_hotkeys(bound.names, bound.bindings);
    assert hotkeys == {"use grenades": "g", "use railgun": "9", "use quad damage": "q", "use data cd": "k"};
    assert q2_key_number("q") == 113 and q2_key_number("F5") == 139 and q2_key_number("MOUSE2") == 201;
    rows = q2_inventory_rows(player, weapon_rules("q2"), "powerup_quad", hotkeys);
    names = [row.name for row in rows];
    assert names == [
        "Combat Armor",
        "Power Shield",
        "Blaster",
        "Shotgun",
        "Grenades",
        "Railgun",
        "Shells",
        "Slugs",
        "Quad Damage",
        "Data CD"
    ];
    assert rows[0].count == 50 and rows[4].count == 5 and rows[4].bind == "g";
    assert rows[5].bind == "9" and rows[6].count == 24 and rows[6].bind == "";
    assert rows[8].bind == "q" and rows[9].bind == "k" and rows[2].bind == "";
    assert [row.name for row in rows if row.selected] == ["Quad Damage"];
    # Nothing bound: an empty column, not Quake II's defaults.
    assert [row.bind for row in q2_inventory_rows(player, weapon_rules("q2"), "")] == [""] * 10;
}

test "invnext and invprev step through every usable item, weapons included" {
    player = Player(armor=50, armor_ratio=0.6);
    for (kind, amount) in [
        ("weapon_blaster", 1),
        ("weapon_railgun", 1),
        ("weapon_shotgun", 1),
        ("slugs", 10),
        ("shells", 24),
        ("grenades", 5),
        ("power_shield", 1),
        ("powerup_quad", 1),
        ("key_data_cd", 1)
    ] {
        player.inventory spawn AdjustInventory(kind=kind, amount=amount, capacity=200);
    }
    counts = q2_item_counts(player, weapon_rules("q2"));
    assert counts["armor_combat"] == 50 and counts["grenades"] == 5 and counts["blaster"] == 1;
    # SelectNextItem: itemlist order, skipping armor, ammo and keys (no use).
    order: list[str] = [];
    selected = "blaster";
    for step in range(7) {
        selected = q2_step_item(counts, selected, 1);
        order.append(selected);
    }
    assert order == ["shotgun", "grenades", "railgun", "powerup_quad", "power_shield", "blaster", "shotgun"];
    # SelectPrevItem walks it backwards, wrapping at the top.
    assert q2_step_item(counts, "blaster", -1) == "power_shield";
    assert q2_step_item(counts, "power_shield", -1) == "powerup_quad";
    # From no selection (-1) the scan starts at either end.
    assert q2_step_item(counts, "", 1) == "power_shield" and q2_step_item(counts, "", -1) == "powerup_quad";
    # ValidateSelectedItem keeps what is carried and moves on from what is spent.
    assert q2_validate_item(counts, "railgun") == "railgun";
    counts.pop("powerup_quad");
    assert q2_validate_item(counts, "powerup_quad") == "power_shield";
    assert q2_step_item({"shells": 5, "armor_body": 100}, "blaster", 1) == "";
    assert Q2_USABLE_ITEMS["grenades"] == "a_grenades" and "shells" not in Q2_USABLE_ITEMS;
}

test "the help computer beeps on three frames that are multiples of 64" {
    world = World();
    player = Player(health=100);
    state = CombatState(game="q2");
    help = TargetEvent(kind="help", message="Find the data CD", primary=True);
    world +>:HasTarget:+> help;
    help.activation.pending = 1;
    # Use_Target_Help at 10.0 s (frame 100): no sound of its own.
    clock = 10.0;
    first = world spawn TargetTick(player=player, collision=CollisionMap(), state=state, dt=0.05, clock=clock);
    assert not first.cues;
    computer = help_for(world);
    assert computer.unread == 1 and computer.changed == 1;
    # G_SetClientSound beeps when !(level.framenum & 63): frames 128, 192, 256.
    heard: list[int] = [];
    for tick in range(4000) {
        clock += 0.005;
        ran = world spawn TargetTick(player=player, collision=CollisionMap(), state=state, dt=0.005, clock=clock);
        if ran.cues {
            assert ran.cues == ["sound/misc/pc_up.wav"];
            heard.append(int(clock * 10.0 + 0.0001));
        }
    }
    assert heard == [128, 192, 256];
    # Three in all; the icon keeps blinking until the computer is read.
    assert computer.unread == 4;
    # News that arrives on such a frame beeps with it.
    computer.unread = 0;
    help.activation.pending = 1;
    at_once = world spawn TargetTick(player=player, collision=CollisionMap(), state=state, dt=0.05, clock=32.0);
    assert at_once.cues == ["sound/misc/pc_up.wav"] and computer.unread == 2;
    # Read: no more.
    computer.unread = 0;
    quiet = world spawn TargetTick(player=player, collision=CollisionMap(), state=state, dt=0.05, clock=38.4);
    assert not quiet.cues;
}

test "status bar flashes follow the last hit for a server frame" {
    view = ViewFeedback();
    view.reset("q2");
    player = Player(health=90);
    player.damage_blood = 5;
    player.damage_armor = 3;
    view.take_damage(player);
    assert view.status_flashes() == 3;
    view.advance(0.05);
    assert view.status_flashes() == 3;
    view.advance(0.06);
    assert view.status_flashes() == 0;
    player.damage_armor = 4;
    view.take_damage(player);
    assert view.status_flashes() == 2;
}

test "the help computer's objectives outlast the level and its saves" {
    world = World();
    computer = help_for(world);
    computer.primary = "Locate base installation\nelevator.";
    computer.secondary = "Find the data CD";
    computer.changed = 2;
    computer.unread = 3;
    # game.helpmessage1/2 go on into the next level of the game.
    following = World();
    carry_help(world, following);
    carried = help_for(following);
    assert carried.primary == computer.primary and carried.secondary == "Find the data CD";
    assert carried.changed == 2 and carried.unread == 3;
    # WriteGame keeps them; loading puts them back.
    level = Level(bsp=Bsp(game="q2"), name="base1");
    player = Player();
    state = CombatState(game="q2");
    data = snapshot(world, level, player, state);
    fresh = World();
    restore(fresh, level, Player(), CombatState(game="q2"), data);
    restored = help_for(fresh);
    assert restored.primary == "Locate base installation\nelevator.";
    assert restored.secondary == "Find the data CD" and restored.unread == 3;
    empty = World();
    help_for(empty);
    blank = snapshot(empty, level, player, state);
    restore(fresh, level, Player(), CombatState(game="q2"), blank);
    assert help_for(fresh).primary == "" and help_for(fresh).secondary == "";
}
