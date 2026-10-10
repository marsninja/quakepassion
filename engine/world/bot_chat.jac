"""What Q3 bots say, after be_ai_chat.c and ai_chat.c. A bot's character has
its initial chats by type (game_enter, kill_rail, death_insult, ...), each a
list of messages built from text, the chat's variables (the victim's name,
the weapon...) and rnd.c's random strings, which may hold more. A bot chats
at most every 25 seconds (TIME_BETWEENCHATTING), as likely as its character's
CHARACTERISTIC_CHAT_* tendencies, and stands still while it types
(AINode_Stand) before the line goes out as `say`: "Name: text".

Bots also answer what is said (BotReplyChat). Every chat line reaches each
bot as a console message; rchat.c's reply chats are tried against it, each a
set of keys (words, match templates with variables, the bot's name or
gender) with a priority and answers, and syn.c's synonyms reword what is
matched and what is said."""
import from ..formats.botconfig {
    ChatMessage,
    ChatPart,
    WeightDice,
    SynonymList,
    MatchPiece,
    MatchTemplate,
    ReplyKey,
    ReplyChat,
    RCKFL_AND,
    RCKFL_NOT,
    RCKFL_NAME,
    RCKFL_STRING,
    RCKFL_VARIABLES,
    RCKFL_BOTNAMES,
    RCKFL_GENDERFEMALE,
    RCKFL_GENDERMALE,
    RCKFL_GENDERLESS
}

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
    # The console messages waiting to be read (bot_consolemessage_t) and the
    # last chat line of the match queued.
    has console: list[ConsoleMessage] = [],
        heard: int = 0;
}

# syn.h synonym contexts and match.h match contexts and types.
glob CONTEXT_NORMAL: int = 1,
    CONTEXT_NEARBYITEM: int = 2,
    CONTEXT_REPLY: int = 16,
    CONTEXT_NAMES: int = 1024,
    MTCONTEXT_MISC: int = 2,
    MTCONTEXT_INITIALTEAMCHAT: int = 4,
    MTCONTEXT_REPLYCHAT: int = 128,
    MTCONTEXT_CTF: int = 256,
    MATCH_NETNAME: int = 0,
    MATCH_MESSAGE: int = 2,
    ST_TEAM: int = 32768,
    MAX_MATCHVARIABLES: int = 8;

# g_cmds.c G_Say's escape character between a name and what it says.
glob CHAT_EC: str = chr(25);

"""be_ai_chat.c bot_consolemessage_t for a chat line (CMS_CHAT): who said
it, the line as every client gets it and when it came."""
obj ConsoleMessage {
    has speaker: str,
        line: str,
        time: float,
        mine: bool = False;
}

"""be_ai_chat.c bot_match_t: a string and where its match variables lie in
it."""
obj ChatMatch {
    has text: str = "",
        kind: int = 0,
        subtype: int = 0,
        offsets: list[int] = [0, 0, 0, 0, 0, 0, 0, 0],
        lengths: list[int] = [0, 0, 0, 0, 0, 0, 0, 0];

    """BotMatchVariable."""
    def variable(number: int) -> str {
        if number < 0 or number >= MAX_MATCHVARIABLES or self.offsets[number] < 0 {
            return "";
        }
        return self.text[self.offsets[number]:self.offsets[number] + self.lengths[number]];
    }
}

"""be_ai_chat.c UnifyWhiteSpaces: runs of anything but letters, digits and
( ) ? : ' / , . [ ] - _ + = become one space, and those at either end go."""
def unify_white_spaces(text: str) -> str {
    result = "";
    gap = False;
    for c in text {
        lower = c.lower();
        if (lower >= "a" and lower <= "z") or (c >= "0" and c <= "9") or "()?:'/,.[]-_+=".find(c) >= 0 {
            if gap and result {
                result += " ";
            }
            gap = False;
            result += c;
        } else {
            gap = True;
        }
    }
    return result;
}

"""be_ai_chat.c StringContains without regard to case: where `part` first
is in `text`, or -1."""
def string_contains(text: str, part: str) -> int {
    return text.lower().find(part.lower());
}

"""be_ai_chat.c StringContainsWord without regard to case: where `word`
first stands in `text` as whole words (ended by a space, full stop, comma,
exclamation mark or the end; begun at the start or after one of those), or
-1."""
def string_contains_word(text: str, word: str) -> int {
    limit = len(text) - len(word);
    at = 0;
    i = 0;
    while i <= limit {
        if i > 0 {
            while at < len(text) and " .,!".find(text[at]) < 0 {
                at += 1;
            }
            if at >= len(text) {
                break;
            }
            at += 1;
        }
        if text[at:at + len(word)].lower() == word.lower() {
            after = at + len(word);
            if after >= len(text) or " .,!".find(text[after]) >= 0 {
                return at;
            }
        }
        i += 1;
        at += 1;
    }
    return -1;
}

"""be_ai_chat.c StringReplaceWords: every `synonym` in `text` becomes
`replacement`, except where it is part of a `replacement` already there."""
def string_replace_words(text: str, synonym: str, replacement: str) -> str {
    at = string_contains_word(text, synonym);
    while at >= 0 {
        inside = string_contains_word(text, replacement);
        while inside >= 0 {
            if inside <= at and at < inside + len(replacement) {
                break;
            }
            following = string_contains_word(text[inside + 1:], replacement);
            inside = inside + 1 + following if following >= 0 else -1;
        }
        if inside < 0 {
            text = text[:at] + replacement + text[at + len(synonym):];
        }
        following = string_contains_word(text[at + len(replacement):], synonym);
        at = at + len(replacement) + following if following >= 0 else -1;
    }
    return text;
}

"""be_ai_chat.c BotReplaceSynonyms: in the lists of the `context`, every
synonym becomes the list's first word."""
def replace_synonyms(text: str, synonyms: list[SynonymList], context: int) -> str {
    for group in synonyms {
        if group.context & context == 0 {
            continue;
        }
        for word in group.words[1:] {
            text = string_replace_words(text, word, group.words[0]);
        }
    }
    return text;
}

"""be_ai_chat.c BotReplaceWeightedSynonyms: in each list of the `context`
one word is drawn by weight and the others become it."""
def replace_weighted_synonyms(text: str, synonyms: list[SynonymList], context: int, dice: WeightDice) -> str {
    for group in synonyms {
        if group.context & context == 0 {
            continue;
        }
        weight = dice.random() * group.total;
        if weight == 0.0 {
            continue;
        }
        chosen = -1;
        running = 0.0;
        for i in range(len(group.words)) {
            running += group.weights[i];
            if weight < running {
                chosen = i;
                break;
            }
        }
        if chosen < 0 {
            continue;
        }
        for i in range(len(group.words)) {
            if i != chosen {
                text = string_replace_words(text, group.words[i], group.words[chosen]);
            }
        }
    }
    return text;
}

"""be_ai_chat.c BotReplaceReplySynonyms: word by word, a word that begins a
synonym of the `context` (and not the list's first word) is replaced by the
first word, once."""
def replace_reply_synonyms(text: str, synonyms: list[SynonymList], context: int) -> str {
    at = 0;
    while at < len(text) {
        while at < len(text) and text[at] <= " " {
            at += 1;
        }
        if at >= len(text) {
            break;
        }
        replaced = False;
        for group in synonyms {
            if group.context & context == 0 {
                continue;
            }
            for word in group.words[1:] {
                if string_contains_word(text[at:], word) != 0 or string_contains_word(text[at:], group.words[0]) == 0 {
                    continue;
                }
                text = text[:at] + group.words[0] + text[at + len(word):];
                replaced = True;
                break;
            }
            if replaced {
                break;
            }
        }
        while at < len(text) and text[at] > " " {
            at += 1;
        }
    }
    return text;
}

"""be_ai_chat.c StringsMatch: whether `found.text` is the match `pieces`
one after another, filling in where the variables lie. A string piece is
any of its alternatives (an empty one always fits) found right where the
last piece ended, or anywhere further on when a variable comes before it."""
def strings_match(pieces: list[MatchPiece], found: ChatMatch) -> bool {
    last = -1;
    at = 0;
    for piece in pieces {
        if piece.variable >= 0 {
            found.offsets[piece.variable] = at;
            last = piece.variable;
            continue;
        }
        landed = -1;
        width = 0;
        for choice in piece.strings {
            if not choice {
                landed = at;
                width = 0;
                break;
            }
            index = string_contains(found.text[at:], choice);
            if index < 0 {
                continue;
            }
            if last >= 0 {
                landed = at + index;
                width = len(choice);
                found.lengths[last] = landed - found.offsets[last];
                last = -1;
                break;
            }
            if index == 0 {
                landed = at;
                width = len(choice);
                break;
            }
        }
        if landed < 0 {
            return False;
        }
        at = landed + width;
    }
    if last >= 0 {
        found.lengths[last] = len(found.text) - found.offsets[last];
        return True;
    }
    return at == len(found.text);
}

"""be_ai_chat.c BotFindMatch: the first match template of the `context`
that `text` fits, with its variables; None when none does."""
def find_match(templates: list[MatchTemplate], text: str, context: int) -> ChatMatch | None {
    line = text.rstrip("\n");
    for template in templates {
        if template.context & context == 0 {
            continue;
        }
        found = ChatMatch(text=line, offsets=[-1, -1, -1, -1, -1, -1, -1, -1]);
        if strings_match(template.pieces, found) {
            found.kind = template.kind;
            found.subtype = template.subtype;
            return found;
        }
    }
    return None;
}

"""be_ai_chat.c BotReplyChat: type an answer to `message`. Of the reply
chats whose keys fit (in botlib's order, each key in turn: one that must
hold and does not, or must not and does, rules the chat out; any other that
holds rules it in), the one with the highest priority that has a message
gives it: a random one of those not said in the last 20 seconds. The
answer's variables are the match variables of the chat's keys, with the
bot's own `name` as variable 6 and the speaker's as 7, reworded by the
synonyms of the `vcontext`; the whole by the weighted synonyms of the
`mcontext`. False when no reply chat fits."""
def reply_chat(
    replies: list[ReplyChat],
    randoms: dict[str, list[ChatMessage]],
    synonyms: list[SynonymList],
    state: BotChatState,
    message: str,
    name: str,
    gender: str,
    speaker: str,
    mcontext: int,
    vcontext: int,
    now: float,
    dice: WeightDice
) -> bool {
    found = ChatMatch(text=message);
    best: ChatMessage | None = None;
    best_match = found;
    best_priority = -1;
    for reply in replies {
        fits = False;
        for key in reply.keys {
            holds = False;
            if key.flags & RCKFL_NAME {
                holds = string_contains(message, name) >= 0;
            } elif key.flags & RCKFL_BOTNAMES {
                holds = string_contains(key.text, name) >= 0;
            } elif key.flags & RCKFL_GENDERFEMALE {
                holds = gender == "female";
            } elif key.flags & RCKFL_GENDERMALE {
                holds = gender == "male";
            } elif key.flags & RCKFL_GENDERLESS {
                holds = gender not in ["female", "male"];
            } elif key.flags & RCKFL_VARIABLES {
                holds = strings_match(key.pieces, found);
            } elif key.flags & RCKFL_STRING {
                holds = string_contains_word(message, key.text) >= 0;
            }
            if key.flags & RCKFL_AND {
                if not holds {
                    fits = False;
                    break;
                }
            } elif key.flags & RCKFL_NOT {
                if holds {
                    fits = False;
                    break;
                }
            } elif holds {
                fits = True;
            }
        }
        if not fits or reply.priority <= float(best_priority) or not reply.messages {
            continue;
        }
        # A random one among as many as are not recently said (botlib counts
        # those, then takes that many steps down the whole list).
        fresh = len([line for line in reply.messages if line.used <= now]);
        pick = min(len(reply.messages) - 1, int(dice.random() * float(fresh)));
        best = reply.messages[pick];
        best_match = ChatMatch(text=found.text, offsets=list(found.offsets), lengths=list(found.lengths));
        best_priority = int(reply.priority);
    }
    if best is None {
        return False;
    }
    variables = [best_match.variable(i) for i in range(MAX_MATCHVARIABLES)];
    variables[6] = name;
    variables[7] = speaker;
    best.used = now + CHATMESSAGE_RECENTTIME;
    state.message = construct_chat(best, variables, randoms, dice, 0, synonyms, mcontext, vcontext, True);
    return True;
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
and random strings chosen, those in turn expanded, up to ten deep, and its
words drawn among the `synonyms` of the message context `mcontext`. The
variables of a `reply` are reworded by the reply synonyms of `vcontext`."""
def construct_chat(
    message: ChatMessage,
    variables: list[str],
    randoms: dict[str, list[ChatMessage]],
    dice: WeightDice,
    depth: int = 0,
    synonyms: list[SynonymList] = [],
    mcontext: int = 0,
    vcontext: int = 0,
    reply: bool = False
) -> str {
    text = "";
    for part in message.parts {
        if part.kind == "variable" {
            if part.number < len(variables) {
                # A variable is reworded on its way in: a reply's by the
                # reply synonyms, any other by those of its context.
                worded = variables[part.number];
                if reply {
                    worded = replace_reply_synonyms(worded, synonyms, vcontext);
                } elif vcontext != 0 {
                    worded = replace_synonyms(worded, synonyms, vcontext);
                }
                text += worded;
            }
        } elif part.kind == "random" {
            chosen = random_string(randoms, part.text, dice) if depth < 10 else None;
            if chosen is not None {
                text += construct_chat(chosen, variables, randoms, dice, depth + 1, synonyms, mcontext, vcontext, reply);
            }
        } else {
            text += part.text;
        }
    }
    # BotExpandChatMessage ends by wording the message with the weighted
    # synonyms of its context.
    if depth == 0 and mcontext != 0 {
        text = replace_weighted_synonyms(text, synonyms, mcontext, dice);
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
    dice: WeightDice,
    synonyms: list[SynonymList] = []
) -> bool {
    chosen = choose_chat(chats, kind, now, dice);
    if chosen is None {
        return False;
    }
    # BotAI_BotInitialChat words it in BotSynonymContext's context.
    state.message = construct_chat(
        chosen, variables, randoms, dice, 0, synonyms, CONTEXT_NORMAL | CONTEXT_NEARBYITEM | CONTEXT_NAMES
    );
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
