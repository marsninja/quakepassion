"""What Q3 bots say, after be_ai_chat.c and ai_chat.c. A bot's character has
its initial chats by type (game_enter, kill_rail, death_insult, ...), each a
list of messages built from text, the chat's variables (the victim's name,
the weapon...) and rnd.c's random strings, which may hold more. A bot chats
at most every 25 seconds (TIME_BETWEENCHATTING), as likely as its character's
CHARACTERISTIC_CHAT_* tendencies, and stands still while it types
(AINode_Stand) before the line goes out as `say`: "Name: text"."""
import from ..formats.botconfig { ChatMessage, ChatPart, WeightDice }

# ai_chat.c and be_ai_chat.c.
glob TIME_BETWEENCHATTING: float = 25.0,
    CHATMESSAGE_RECENTTIME: float = 20.0,
    MAX_MESSAGE_SIZE: int = 256,
    BOT_CHAT_TIME: float = 2.0;

"""A bot's chat state (bot_chatstate_t with ai_chat.c's bookkeeping): the
message it is typing, when it last chatted, and when it entered the game
and whether it has greeted it (entergame_time, entergamechat). It lasts
the whole match, unlike the bot's state, which each respawn renews."""
obj BotChatState {
    has message: str = "",
        last_chat: float = -1000.0,
        entered: float = -1.0,
        entered_chat: bool = False;
}

"""ai_chat.c BotChatTime: how long a bot types (always two seconds)."""
def chat_time() -> float {
    return BOT_CHAT_TIME;
}

"""be_ai_chat.c RandomString: one of the named random strings."""
def random_string(randoms: dict[str, list[ChatMessage]], name: str, dice: WeightDice) -> ChatMessage | None {
    choices = randoms.get(name, []);
    if not choices {
        return None;
    }
    return choices[min(len(choices) - 1, int(dice.random() * float(len(choices))))];
}

"""BotConstructChatMessage: a message's text with its variables filled in
and random strings chosen, those in turn expanded, up to ten deep."""
def construct_chat(
    message: ChatMessage,
    variables: list[str],
    randoms: dict[str, list[ChatMessage]],
    dice: WeightDice,
    depth: int = 0
) -> str {
    text = "";
    for part in message.parts {
        if part.kind == "variable" {
            if part.number < len(variables) {
                text += variables[part.number];
            }
        } elif part.kind == "random" {
            chosen = random_string(randoms, part.text, dice) if depth < 10 else None;
            if chosen is not None {
                text += construct_chat(chosen, variables, randoms, dice, depth + 1);
            }
        } else {
            text += part.text;
        }
    }
    return text[0:MAX_MESSAGE_SIZE];
}

"""BotChooseInitialChatMessage: a random message of the type not said in the
last 20 seconds, or else the one said longest ago."""
def choose_chat(chats: dict[str, list[ChatMessage]], kind: str, now: float, dice: WeightDice) -> ChatMessage | None {
    messages = chats.get(kind.lower(), []);
    if not messages {
        return None;
    }
    fresh = [message for message in messages if message.used <= now];
    if not fresh {
        oldest = messages[0];
        for message in messages {
            if message.used < oldest.used {
                oldest = message;
            }
        }
        return oldest;
    }
    chosen = fresh[min(len(fresh) - 1, int(dice.random() * float(len(fresh))))];
    chosen.used = now + CHATMESSAGE_RECENTTIME;
    return chosen;
}

"""BotInitialChat: type a message of the chat type with its variables from
the character's `chats` and the `randoms` strings; False when the character
has none of that type."""
def initial_chat(
    chats: dict[str, list[ChatMessage]],
    randoms: dict[str, list[ChatMessage]],
    state: BotChatState,
    kind: str,
    variables: list[str],
    now: float,
    dice: WeightDice
) -> bool {
    chosen = choose_chat(chats, kind, now, dice);
    if chosen is None {
        return False;
    }
    state.message = construct_chat(chosen, variables, randoms, dice);
    return True;
}

"""BotEnterChat for `say`: the line everyone sees (G_Say: the name, then the
text in green) with BotRemoveTildes' tildes gone, or "" when there is
nothing typed. The typed message is cleared."""
def enter_chat(state: BotChatState, name: str) -> str {
    typed = state.message.replace("~", "");
    state.message = "";
    if not typed {
        return "";
    }
    return name + "^7: ^2" + typed;
}

"""ai_dmq3.c EasyClientName: a player's name as bots write it: no spaces,
clan brackets or "Mr" prefix, lower case letters, digits and underscores."""
def easy_client_name(name: str) -> str {
    plain = "";
    i = 0;
    while i < len(name) {
        # Q3 color codes (^N) are not part of the name.
        if name[i] == "^" and i + 1 < len(name) and name[i + 1] != "^" {
            i += 2;
            continue;
        }
        plain += name[i];
        i += 1;
    }
    plain = plain.replace(" ", "");
    opening = plain.find("[");
    closing = plain.find("]");
    if opening >= 0 and closing >= 0 {
        if closing > opening {
            plain = plain[:opening] + plain[closing + 1:];
        } else {
            plain = plain[:closing] + plain[opening + 1:];
        }
    }
    if len(plain) >= 2 and plain[0:2].lower() == "mr" {
        plain = plain[2:];
    }
    result = "";
    for c in plain {
        lower = c.lower();
        if (lower >= "a" and lower <= "z") or (c >= "0" and c <= "9") or c == "_" {
            result += lower;
        }
    }
    return result;
}

"""ai_chat.c BotWeaponNameForMeansOfDeath, from how a player died."""
def weapon_name_for_means(means: str) -> str {
    names: dict[str, str] = {
        "shotgun": "Shotgun",
        "gauntlet": "Gauntlet",
        "machinegun": "Machinegun",
        "grenadelauncher": "Grenade Launcher",
        "rocketlauncher": "Rocket Launcher",
        "splash": "Rocket Launcher",
        "plasmagun": "Plasmagun",
        "railgun": "Railgun",
        "lightning": "Lightning Gun",
        "bfg": "BFG10K"
    };
    return names.get(means, "[unknown weapon]");
}

"""ai_chat.c BotRandomWeaponName."""
def random_weapon_name(dice: WeightDice) -> str {
    names = ["Gauntlet", "Shotgun", "Machinegun", "Grenade Launcher", "Rocket Launcher", "Plasmagun", "Railgun", "Lightning Gun"];
    pick = int(dice.random() * 8.9);
    return names[pick] if pick < len(names) else "BFG10K";
}
