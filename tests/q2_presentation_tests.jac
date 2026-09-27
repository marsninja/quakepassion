"""Quake II's 2D screens: the layout programs of the help computer and unit
summary, the inventory list, the help computer's reminders and the status
bar's damage flashes."""
import from engine.render.hud { layout_tokens }
import from engine.render.view_feedback { ViewFeedback }
import from engine.world.world { World, Player }
import from engine.world.inventory { AdjustInventory }
import from engine.world.targets { TargetEvent, HasTarget, TargetTick, help_for }
import from engine.world.combat { CombatState }
import from engine.physics.collision { CollisionMap }
import from engine.formats.bsp { parse_entities }
import from games.weapons { weapon_rules }
import from games.q2_layouts {
    help_computer_layout,
    unit_summary_layout,
    help_tallies,
    q2_inventory_rows
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
    summary = layout_tokens(unit_summary_layout(1, "Outer Base", 312, 12, 17, 1, 1, 0, 3, True));
    assert "medium" in summary and "Unit complete\n\nTime 5:12" in summary;
    assert "Press fire to continue" in summary;
    waiting = layout_tokens(unit_summary_layout(1, "Outer Base", 312, 12, 17, 1, 1, 0, 3, False));
    assert "Press fire to continue" not in waiting;
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
    rows = q2_inventory_rows(player, weapon_rules("q2"), "powerup_quad");
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
    assert rows[5].bind == "9" and rows[6].count == 24;
    assert [row.name for row in rows if row.selected] == ["Quad Damage"];
}

test "the help computer beeps three times until it is read" {
    world = World();
    player = Player(health=100);
    state = CombatState(game="q2");
    help = TargetEvent(kind="help", message="Find the data CD", primary=True);
    world +>:HasTarget:+> help;
    help.activation.pending = 1;
    first = world spawn TargetTick(player=player, collision=CollisionMap(), state=state, dt=0.05);
    assert first.cues == ["sound/misc/pc_up.wav"];
    computer = help_for(world);
    assert computer.unread > 0;
    beeps = 0;
    for i in range(40) {
        tick = world spawn TargetTick(player=player, collision=CollisionMap(), state=state, dt=1.0);
        beeps += len(tick.cues);
    }
    # Two reminders 6.4 s apart, then silence; the icon keeps blinking.
    assert beeps == 2 and computer.unread > 0;
    computer.unread = 0;
    quiet = world spawn TargetTick(player=player, collision=CollisionMap(), state=state, dt=7.0);
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
