"""Each game's controls as data: the actions its Customize Controls menu lists
(Q1 and Q2 menu.c bindnames, Q3 ui_controls2.c g_bindings) and the bindings
QuakePassion adds after the game's own default.cfg.

The layer keeps the originals' keys and adds what later ports settled on: the
WASD keys, the mouse wheel changing weapons, quick save and load where the
game had none, and the engine's own tools (F3 overlay, F4 walk / fly). A game
without a default.cfg (Passion, or missing archives) starts from a complete
layout in the same spirit."""

"""(command, label) rows of the controls menu for each game."""
glob GAME_CONTROL_ACTIONS: dict[str, list[tuple[str, str]]] = {
    "q1": [
        ("+attack", "attack"),
        ("impulse 10", "change weapon"),
        ("+jump", "jump / swim up"),
        ("+forward", "walk forward"),
        ("+back", "backpedal"),
        ("+left", "turn left"),
        ("+right", "turn right"),
        ("+speed", "run"),
        ("+moveleft", "step left"),
        ("+moveright", "step right"),
        ("+strafe", "sidestep"),
        ("+lookup", "look up"),
        ("+lookdown", "look down"),
        ("centerview", "center view"),
        ("+mlook", "mouse look"),
        ("+klook", "keyboard look"),
        ("+moveup", "swim up"),
        ("+movedown", "swim down")
    ],
    "q2": [
        ("+attack", "attack"),
        ("weapnext", "next weapon"),
        ("+forward", "walk forward"),
        ("+back", "backpedal"),
        ("+left", "turn left"),
        ("+right", "turn right"),
        ("+speed", "run"),
        ("+moveleft", "step left"),
        ("+moveright", "step right"),
        ("+strafe", "sidestep"),
        ("+lookup", "look up"),
        ("+lookdown", "look down"),
        ("centerview", "center view"),
        ("+mlook", "mouse look"),
        ("+klook", "keyboard look"),
        ("+moveup", "up / jump"),
        ("+movedown", "down / crouch"),
        ("inven", "inventory"),
        ("invuse", "use item"),
        ("invprev", "prev item"),
        ("invnext", "next item"),
        ("cmd help", "help computer")
    ],
    "q3": [
        ("+scores", "show scores"),
        ("+button2", "use item"),
        ("+speed", "run / walk"),
        ("+forward", "walk forward"),
        ("+back", "backpedal"),
        ("+moveleft", "step left"),
        ("+moveright", "step right"),
        ("+moveup", "up / jump"),
        ("+movedown", "down / crouch"),
        ("+left", "turn left"),
        ("+right", "turn right"),
        ("+strafe", "sidestep / turn"),
        ("+lookup", "look up"),
        ("+lookdown", "look down"),
        ("+mlook", "mouse look"),
        ("centerview", "center view"),
        ("weapon 1", "gauntlet"),
        ("weapon 2", "machinegun"),
        ("weapon 3", "shotgun"),
        ("weapon 4", "grenade launcher"),
        ("weapon 5", "rocket launcher"),
        ("weapon 6", "lightning"),
        ("weapon 7", "railgun"),
        ("weapon 8", "plasma gun"),
        ("weapon 9", "BFG"),
        ("+attack", "attack"),
        ("weapprev", "prev weapon"),
        ("weapnext", "next weapon")
    ]
};

"""The engine's own actions, listed after the game's."""
glob ENGINE_CONTROL_ACTIONS: list[tuple[str, str]] = [
    ("toggleconsole", "console"),
    ("noclip", "walk / fly"),
    ("toggle qp_overlay", "diagnostic overlay"),
    ("save quick", "quick save"),
    ("load quick", "quick load"),
    ("screenshot", "screenshot")
];

"""The bindings QuakePassion adds after each game's default.cfg."""
glob GAME_BINDING_LAYERS: dict[str, str] = {
    "q1": "bind w +forward\nbind s +back\nbind a +moveleft\nbind d +moveright\nbind MWHEELUP \"impulse 12\"\nbind MWHEELDOWN \"impulse 10\"\nbind F3 \"toggle qp_overlay\"\nbind F4 noclip\n",
    "q2": "bind w +forward\nbind s +back\nbind a +moveleft\nbind d +moveright\nbind MWHEELUP weapprev\nbind MWHEELDOWN weapnext\nbind F3 \"toggle qp_overlay\"\nbind F4 noclip\n",
    "q3": "bind F3 \"toggle qp_overlay\"\nbind F4 noclip\nbind F6 \"echo Quick Saving...; wait; save quick\"\nbind F9 \"echo Quick Loading...; wait; load quick\"\nbind F12 screenshot\n"
};

"""A complete layout for a game that ships no default.cfg."""
glob FALLBACK_BINDINGS: str = "unbindall\nbind w +forward\nbind s +back\nbind a +moveleft\nbind d +moveright\nbind UPARROW +forward\nbind DOWNARROW +back\nbind LEFTARROW +left\nbind RIGHTARROW +right\nbind PGDN +lookup\nbind DEL +lookdown\nbind END centerview\nbind SPACE +jump\nbind c +movedown\nbind SHIFT +speed\nbind CTRL +attack\nbind ALT +strafe\nbind MOUSE1 +attack\nbind TAB +showscores\nbind ENTER invuse\nbind 1 \"impulse 1\"\nbind 2 \"impulse 2\"\nbind 3 \"impulse 3\"\nbind 4 \"impulse 4\"\nbind 5 \"impulse 5\"\nbind 6 \"impulse 6\"\nbind 7 \"impulse 7\"\nbind 8 \"impulse 8\"\nbind / \"impulse 10\"\nbind MWHEELUP \"impulse 12\"\nbind MWHEELDOWN \"impulse 10\"\nbind ` toggleconsole\nbind ~ toggleconsole\nbind F3 \"toggle qp_overlay\"\nbind F4 noclip\nbind F6 \"save quick\"\nbind F9 \"load quick\"\nbind F12 screenshot\n";

"""The controls menu's rows for `game`: its own actions, then the engine's."""
def control_actions(game: str) -> list[tuple[str, str]] {
    return GAME_CONTROL_ACTIONS.get(game, GAME_CONTROL_ACTIONS["q1"]) + ENGINE_CONTROL_ACTIONS;
}

"""What runs after `game`'s default.cfg (or, when it has none, instead)."""
def binding_layer(game: str, has_default: bool) -> str {
    if not has_default {
        return FALLBACK_BINDINGS;
    }
    return GAME_BINDING_LAYERS.get(game, "");
}
