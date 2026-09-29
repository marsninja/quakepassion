"""botlib's configurations read from precompiled bot scripts: fuzzy weights
(be_ai_weight.c ReadWeightConfig and FuzzyWeight), item info (be_ai_goal.c
LoadItemConfig over items.c), weapon info (be_ai_weap.c over weapons.c),
initial chats (be_ai_chat.c BotLoadInitialChat over bots/*_t.c) and random
strings (BotLoadRandomStrings over rnd.c)."""
import from .botscript { ScriptToken, TT_STRING, TT_NUMBER, TT_NAME, TT_PUNCTUATION }
import from ..math.vec3 { Vec3 }

# be_ai_weight.c: the value a `default` case stands for.
glob MAX_INVENTORYVALUE: int = 999999;

"""A reader over precompiled tokens."""
obj TokenCursor {
    has tokens: list[ScriptToken],
        at: int = 0;

    def more() -> bool {
        return self.at < len(self.tokens);
    }

    def peek() -> ScriptToken | None {
        return self.tokens[self.at] if self.at < len(self.tokens) else None;
    }

    def next() -> ScriptToken {
        if self.at >= len(self.tokens) {
            raise ValueError("Unexpected end of a bot script");
        }
        token = self.tokens[self.at];
        self.at += 1;
        return token;
    }

    def expect(text: str) -> ScriptToken {
        token = self.next();
        if token.text != text or token.kind == TT_STRING {
            raise ValueError("Expected " + text + " in a bot script on line " + str(token.line) + ", found " + token.text);
        }
        return token;
    }

    """Takes `text` when it comes next (PC_CheckTokenString)."""
    def check(text: str) -> bool {
        token = self.peek();
        if token is not None and token.text == text and token.kind != TT_STRING {
            self.at += 1;
            return True;
        }
        return False;
    }

    def expect_kind(kind: int) -> ScriptToken {
        token = self.next();
        if token.kind != kind {
            raise ValueError("Unexpected " + token.text + " in a bot script on line " + str(token.line));
        }
        return token;
    }

    """A number, with its sign (a minus is a separate token)."""
    def signed_number() -> float {
        negative = self.check("-");
        token = self.expect_kind(TT_NUMBER);
        return -token.number if negative else token.number;
    }
}

"""The dice fuzzy weights draw with (random() in botlib)."""
obj WeightDice {
    has state: int = 1;

    def random() -> float {
        self.state = (self.state * 48271) % 2147483647;
        return float(self.state) / 2147483647.0;
    }
}

"""One case of a fuzzy weight switch (fuzzyseperator_t): the inventory
`index` switched on, the `value` it is below, and either a nested switch
(`child`, its cases in order) or a weight, a `balance(weight, min, max)`
weight ranging from `low` to `high`."""
obj FuzzySeparator {
    has index: int,
        value: int,
        weight: float = 0.0,
        low: float = 0.0,
        high: float = 0.0,
        child: list[FuzzySeparator] = [];

    def ranged(dice: WeightDice) -> float {
        return self.low + dice.random() * (self.high - self.low);
    }
}

"""be_ai_weight.c FuzzyWeight_r over a switch's cases from `k` on. Between
two cases the weights are mixed by a scale botlib figures in integers, so
it is always 0 and the later case's weight is taken whole."""
def fuzzy_weight(inventory: list[int], cases: list[FuzzySeparator], k: int = 0) -> float {
    here = cases[k];
    have = inventory[here.index] if here.index < len(inventory) else 0;
    if have < here.value {
        return fuzzy_weight(inventory, here.child) if here.child else here.weight;
    }
    if k + 1 < len(cases) {
        after = cases[k + 1];
        if have < after.value {
            w1 = fuzzy_weight(inventory, here.child) if here.child else here.weight;
            w2 = fuzzy_weight(inventory, after.child) if after.child else after.weight;
            scale = float((have - here.value) // (after.value - here.value));
            return scale * w1 + (1.0 - scale) * w2;
        }
        return fuzzy_weight(inventory, cases, k + 1);
    }
    return here.weight;
}

"""be_ai_weight.c FuzzyWeightUndecided_r: as fuzzy_weight, but a balanced
weight is drawn at random within its range (a nested switch under the later
of two cases is still decided, as in botlib)."""
def undecided_weight(inventory: list[int], cases: list[FuzzySeparator], dice: WeightDice, k: int = 0) -> float {
    here = cases[k];
    have = inventory[here.index] if here.index < len(inventory) else 0;
    if have < here.value {
        return undecided_weight(inventory, here.child, dice) if here.child else here.ranged(dice);
    }
    if k + 1 < len(cases) {
        after = cases[k + 1];
        if have < after.value {
            w1 = undecided_weight(inventory, here.child, dice) if here.child else here.ranged(dice);
            w2 = fuzzy_weight(inventory, after.child) if after.child else after.ranged(dice);
            scale = float((have - here.value) // (after.value - here.value));
            return scale * w1 + (1.0 - scale) * w2;
        }
        return undecided_weight(inventory, cases, dice, k + 1);
    }
    return here.weight;
}

"""A weight config (weightconfig_t): named fuzzy weights."""
obj WeightConfig {
    has names: list[str] = [],
        switches: list[list[FuzzySeparator]] = [];

    """FindFuzzyWeight: the weight's number, or -1."""
    def find(name: str) -> int {
        return self.names.index(name) if name in self.names else -1;
    }

    """FuzzyWeight."""
    def weight(inventory: list[int], number: int) -> float {
        if number < 0 or number >= len(self.switches) or not self.switches[number] {
            return 0.0;
        }
        return fuzzy_weight(inventory, self.switches[number]);
    }

    """FuzzyWeightUndecided."""
    def undecided(inventory: list[int], number: int, dice: WeightDice) -> float {
        if number < 0 or number >= len(self.switches) or not self.switches[number] {
            return 0.0;
        }
        return undecided_weight(inventory, self.switches[number], dice);
    }
}

"""ReadValue: a number; a leading minus is warned about and dropped."""
def read_weight_value(cursor: TokenCursor) -> float {
    cursor.check("-");
    return cursor.expect_kind(TT_NUMBER).number;
}

"""ReadFuzzyWeight: `balance(weight, min, max);` or `weight;`."""
def read_fuzzy_weight(cursor: TokenCursor, fork: FuzzySeparator) {
    if cursor.check("balance") {
        cursor.expect("(");
        fork.weight = read_weight_value(cursor);
        cursor.expect(",");
        fork.low = read_weight_value(cursor);
        cursor.expect(",");
        fork.high = read_weight_value(cursor);
        cursor.expect(")");
    } else {
        fork.weight = read_weight_value(cursor);
        fork.low = fork.weight;
        fork.high = fork.weight;
    }
    cursor.expect(";");
}

"""ReadFuzzySeperators_r: `(index) { case N: ... default: ... }`, with a
zero default added when the switch has none."""
def read_separators(cursor: TokenCursor) -> list[FuzzySeparator] {
    cursor.expect("(");
    index = cursor.expect_kind(TT_NUMBER).whole;
    cursor.expect(")");
    cursor.expect("{");
    cases: list[FuzzySeparator] = [];
    defaulted = False;
    token = cursor.next();
    while True {
        if token.text != "case" and token.text != "default" {
            raise ValueError("Invalid name " + token.text + " in a weight switch on line " + str(token.line));
        }
        fork = FuzzySeparator(index=index, value=MAX_INVENTORYVALUE);
        if token.text == "default" {
            if defaulted {
                raise ValueError("Switch already has a default on line " + str(token.line));
            }
            defaulted = True;
        } else {
            fork.value = cursor.expect_kind(TT_NUMBER).whole;
        }
        cursor.expect(":");
        token = cursor.next();
        braced = token.text == "{";
        if braced {
            token = cursor.next();
        }
        if token.text == "return" {
            read_fuzzy_weight(cursor, fork);
        } elif token.text == "switch" {
            fork.child = read_separators(cursor);
        } else {
            raise ValueError("Invalid name " + token.text + " in a weight case on line " + str(token.line));
        }
        if braced {
            cursor.expect("}");
        }
        cases.append(fork);
        token = cursor.next();
        if token.text == "}" {
            break;
        }
    }
    if not defaulted {
        cases.append(FuzzySeparator(index=index, value=MAX_INVENTORYVALUE));
    }
    return cases;
}

"""ReadWeightConfig: `weight "name" { switch(...) {...} }` or
`weight "name" { return ...; }`, one after another."""
def read_weight_config(tokens: list[ScriptToken]) -> WeightConfig {
    config = WeightConfig();
    cursor = TokenCursor(tokens=tokens);
    while cursor.more() {
        head = cursor.next();
        if head.text != "weight" {
            raise ValueError("Invalid name " + head.text + " in a weight config on line " + str(head.line));
        }
        name = cursor.expect_kind(TT_STRING).text;
        token = cursor.next();
        braced = token.text == "{";
        if braced {
            token = cursor.next();
        }
        cases: list[FuzzySeparator] = [];
        if token.text == "switch" {
            cases = read_separators(cursor);
        } elif token.text == "return" {
            fork = FuzzySeparator(index=0, value=MAX_INVENTORYVALUE);
            read_fuzzy_weight(cursor, fork);
            cases = [fork];
        } else {
            raise ValueError("Invalid name " + token.text + " in a weight config on line " + str(token.line));
        }
        if braced {
            cursor.expect("}");
        }
        config.names.append(name);
        config.switches.append(cases);
    }
    return config;
}

"""l_struct.c ReadStructure for the plain configs: `{ field value ... }`
where a value is a string, a (signed) number or a `{a, b, c}` array."""
def read_structure(cursor: TokenCursor) -> dict[str, list[ScriptToken]] {
    fields: dict[str, list[ScriptToken]] = {};
    cursor.expect("{");
    while not cursor.check("}") {
        name = cursor.expect_kind(TT_NAME).text;
        values: list[ScriptToken] = [];
        if cursor.check("{") {
            while not cursor.check("}") {
                if cursor.check(",") {
                    continue;
                }
                values.append(structure_value(cursor));
            }
        } else {
            values.append(structure_value(cursor));
        }
        fields[name] = values;
    }
    return fields;
}

def structure_value(cursor: TokenCursor) -> ScriptToken {
    if cursor.check("-") {
        token = cursor.expect_kind(TT_NUMBER);
        return ScriptToken(kind=TT_NUMBER, text="-" + token.text, number=-token.number, whole=-token.whole, integer=token.integer);
    }
    return cursor.next();
}

def field_text(fields: dict[str, list[ScriptToken]], name: str) -> str {
    return fields[name][0].text if name in fields and fields[name] else "";
}

def field_number(fields: dict[str, list[ScriptToken]], name: str) -> float {
    return fields[name][0].number if name in fields and fields[name] else 0.0;
}

def field_vector(fields: dict[str, list[ScriptToken]], name: str) -> Vec3 {
    parts = fields.get(name, []);
    if len(parts) < 3 {
        return Vec3();
    }
    return Vec3(x=parts[0].number, y=parts[1].number, z=parts[2].number);
}

"""iteminfo_t: an item bots know (items.c)."""
obj ItemInfo {
    has classname: str,
        name: str = "",
        model: str = "",
        type: int = 0,
        index: int = 0,
        respawntime: float = 0.0,
        mins: Vec3 = Vec3(),
        maxs: Vec3 = Vec3();
}

"""LoadItemConfig: every `iteminfo "classname" {...}`."""
def read_item_config(tokens: list[ScriptToken]) -> list[ItemInfo] {
    items: list[ItemInfo] = [];
    cursor = TokenCursor(tokens=tokens);
    while cursor.more() {
        head = cursor.next();
        if head.text != "iteminfo" {
            raise ValueError("Unknown definition " + head.text + " in an item config on line " + str(head.line));
        }
        classname = cursor.expect_kind(TT_STRING).text;
        fields = read_structure(cursor);
        items.append(
            ItemInfo(
                classname=classname,
                name=field_text(fields, "name"),
                model=field_text(fields, "model"),
                type=int(field_number(fields, "type")),
                index=int(field_number(fields, "index")),
                respawntime=field_number(fields, "respawntime"),
                mins=field_vector(fields, "mins"),
                maxs=field_vector(fields, "maxs")
            )
        );
    }
    return items;
}

"""be_ai_weap.c LoadWeaponConfig's weapon names by weapon number (the
`weaponinfo` structures; `projectileinfo` ones are passed over)."""
def read_weapon_names(tokens: list[ScriptToken]) -> dict[int, str] {
    names: dict[int, str] = {};
    cursor = TokenCursor(tokens=tokens);
    while cursor.more() {
        head = cursor.next();
        if head.text not in ["weaponinfo", "projectileinfo"] {
            raise ValueError("Unknown definition " + head.text + " in a weapon config on line " + str(head.line));
        }
        fields = read_structure(cursor);
        if head.text == "weaponinfo" {
            names[int(field_number(fields, "number"))] = field_text(fields, "name");
        }
    }
    return names;
}

"""A piece of a chat message: plain text, a variable (`number`) filled by
the chat's caller, or a random string (`text` names it, from rnd.c)."""
obj ChatPart {
    has kind: str = "text",
        text: str = "",
        number: int = 0;
}

"""One chat message (bot_chatmessage_t) and when it was last said."""
obj ChatMessage {
    has parts: list[ChatPart] = [],
        used: float = -40.0;
}

"""BotLoadChatMessage: strings, variable numbers and random string names
separated by commas, ending at a semicolon."""
def read_chat_message(cursor: TokenCursor) -> ChatMessage {
    message = ChatMessage();
    while True {
        token = cursor.next();
        if token.kind == TT_STRING {
            message.parts.append(ChatPart(text=token.text));
        } elif token.kind == TT_NUMBER and token.integer {
            message.parts.append(ChatPart(kind="variable", number=token.whole));
        } elif token.kind == TT_NAME {
            message.parts.append(ChatPart(kind="random", text=token.text));
        } else {
            raise ValueError("Unknown chat message component " + token.text + " on line " + str(token.line));
        }
        if cursor.check(";") {
            break;
        }
        cursor.expect(",");
    }
    return message;
}

"""BotLoadInitialChat: the chat types of the chat `name` (case-insensitive)
in a chat file, each with its messages."""
def read_initial_chat(tokens: list[ScriptToken], name: str) -> dict[str, list[ChatMessage]] {
    types: dict[str, list[ChatMessage]] = {};
    found = False;
    cursor = TokenCursor(tokens=tokens);
    while cursor.more() {
        head = cursor.next();
        if head.text != "chat" {
            raise ValueError("Unknown definition " + head.text + " in a chat file on line " + str(head.line));
        }
        chat_name = cursor.expect_kind(TT_STRING).text;
        cursor.expect("{");
        if chat_name.lower() != name.lower() {
            depth = 1;
            while depth > 0 {
                token = cursor.next();
                if token.kind == TT_PUNCTUATION and token.text == "{" {
                    depth += 1;
                } elif token.kind == TT_PUNCTUATION and token.text == "}" {
                    depth -= 1;
                }
            }
            continue;
        }
        found = True;
        while True {
            token = cursor.next();
            if token.text == "}" {
                break;
            }
            if token.text != "type" {
                raise ValueError("Expected type in a chat file on line " + str(token.line) + ", found " + token.text);
            }
            kind = cursor.expect_kind(TT_STRING).text;
            cursor.expect("{");
            messages = types.get(kind.lower(), []);
            while not cursor.check("}") {
                messages.append(read_chat_message(cursor));
            }
            types[kind.lower()] = messages;
        }
    }
    if not found {
        raise ValueError("No chat " + name + " in the chat file");
    }
    return types;
}

"""BotLoadRandomStrings: `NAME = { message; message; }` lists."""
def read_random_strings(tokens: list[ScriptToken]) -> dict[str, list[ChatMessage]] {
    strings: dict[str, list[ChatMessage]] = {};
    cursor = TokenCursor(tokens=tokens);
    while cursor.more() {
        name = cursor.expect_kind(TT_NAME).text;
        cursor.expect("=");
        cursor.expect("{");
        messages = strings.get(name, []);
        while not cursor.check("}") {
            messages.append(read_chat_message(cursor));
        }
        strings[name] = messages;
    }
    return strings;
}
