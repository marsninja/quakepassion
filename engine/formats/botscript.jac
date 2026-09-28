"""botlib's script reader and precompiler (l_script.c, l_precomp.c), which
every bot file goes through: item and weapon weights, item and weapon
configs, chats and random strings. Scripts are C-like: `//` and `/* */`
comments, strings (adjacent ones joined), numbers, names and punctuation,
with `#include`, `#define` (with parameters), `#undef`, `#ifdef`, `#ifndef`,
`#if`, `#elif`, `#else` and `#endif`, and botlib's `$evalint(...)` and
`$evalfloat(...)`, which evaluate an expression to a number."""

# l_script.h token types.
glob TT_STRING: int = 1,
    TT_LITERAL: int = 2,
    TT_NUMBER: int = 3,
    TT_NAME: int = 4,
    TT_PUNCTUATION: int = 5;

# l_script.c default_punctuations, longest first.
glob SCRIPT_PUNCTUATIONS: list[str] = [
    ">>=", "<<=", "...", "##", "&&", "||", ">=", "<=", "==", "!=", "*=", "/=",
    "%=", "+=", "-=", "++", "--", "&=", "|=", "^=", ">>", "<<", "->", "::",
    ".*", "*", "/", "%", "+", "-", "=", "&", "|", "^", "~", "!", ">", "<", ".",
    ",", ";", ":", "?", "(", ")", "{", "}", "[", "]", "\\", "#", "$"
];

"""One token. A number keeps both of l_script.c's values: `number` and the
truncated `whole` (a float's intvalue is `(unsigned long) floatvalue`), and
whether it was written as an integer. `line` is its source line and
`first` whether it starts that line (where a `#` begins a directive);
`spaced` whether white space comes before it (a `#define` name followed
directly by `(` takes parameters); `fresh` is false for tokens a macro
produced, which are never directives."""
obj ScriptToken {
    has kind: int,
        text: str,
        number: float = 0.0,
        whole: int = 0,
        integer: bool = False,
        line: int = 0,
        first: bool = False,
        spaced: bool = False,
        fresh: bool = True;
}

def script_digit(c: str) -> bool {
    return c >= "0" and c <= "9";
}

def script_name_char(c: str) -> bool {
    return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_" or script_digit(c);
}

"""PS_ReadEscapeCharacter's escapes."""
def script_escape(c: str) -> str {
    escapes: dict[str, str] = {"n": "\n", "r": "\r", "t": "\t", "v": "\v", "b": "\b", "f": "\f", "a": "\a", "0": "\0"};
    return escapes.get(c, c);
}

"""The tokens of one script (PS_ReadToken)."""
def lex_script(text: str) -> list[ScriptToken] {
    tokens: list[ScriptToken] = [];
    i = 0;
    count = len(text);
    line = 1;
    line_open = True;
    spaced = True;
    while i < count {
        c = text[i];
        if c == "\n" {
            line += 1;
            line_open = True;
            spaced = True;
            i += 1;
            continue;
        }
        if c in [" ", "\t", "\r", "\f", "\v"] {
            spaced = True;
            i += 1;
            continue;
        }
        if c == "/" and i + 1 < count and text[i + 1] == "/" {
            while i < count and text[i] != "\n" {
                i += 1;
            }
            continue;
        }
        if c == "/" and i + 1 < count and text[i + 1] == "*" {
            i += 2;
            while i < count and not (text[i] == "*" and i + 1 < count and text[i + 1] == "/") {
                if text[i] == "\n" {
                    line += 1;
                }
                i += 1;
            }
            i += 2;
            spaced = True;
            continue;
        }
        start_line = line;
        first = line_open;
        line_open = False;
        gap = spaced;
        spaced = False;
        if c == "\"" or c == "'" {
            quote = c;
            value = "";
            i += 1;
            while True {
                if i >= count or text[i] == "\n" {
                    raise ValueError("Unterminated string in bot script on line " + str(line));
                }
                if text[i] == "\\" and i + 1 < count {
                    value += script_escape(text[i + 1]);
                    i += 2;
                    continue;
                }
                if text[i] == quote {
                    i += 1;
                    if quote != "\"" {
                        break;
                    }
                    # Adjacent strings are one (across white space and lines).
                    j = i;
                    skipped = 0;
                    while j < count and text[j] in [" ", "\t", "\r", "\n"] {
                        if text[j] == "\n" {
                            skipped += 1;
                        }
                        j += 1;
                    }
                    if j < count and text[j] == "\"" {
                        line += skipped;
                        i = j + 1;
                        continue;
                    }
                    break;
                }
                value += text[i];
                i += 1;
            }
            tokens.append(ScriptToken(kind=TT_STRING if quote == "\"" else TT_LITERAL, text=value, line=start_line, first=first, spaced=gap));
            continue;
        }
        if script_digit(c) or (c == "." and i + 1 < count and script_digit(text[i + 1])) {
            j = i;
            if c == "0" and i + 1 < count and text[i + 1] in ["x", "X"] {
                j = i + 2;
                while j < count and (script_digit(text[j]) or text[j].lower() in ["a", "b", "c", "d", "e", "f"]) {
                    j += 1;
                }
                hex_value = int(text[i + 2:j], 16);
                tokens.append(ScriptToken(kind=TT_NUMBER, text=text[i:j], number=float(hex_value), whole=hex_value, integer=True, line=start_line, first=first, spaced=gap));
            } else {
                dotted = False;
                while j < count and (script_digit(text[j]) or (text[j] == "." and not dotted)) {
                    if text[j] == "." {
                        dotted = True;
                    }
                    j += 1;
                }
                literal = text[i:j];
                float_value = float(literal);
                tokens.append(ScriptToken(kind=TT_NUMBER, text=literal, number=float_value, whole=int(float_value), integer=not dotted, line=start_line, first=first, spaced=gap));
            }
            # Type suffixes (1.0f, 10L, 3u).
            while j < count and text[j] in ["f", "F", "l", "L", "u", "U"] {
                j += 1;
            }
            i = j;
            continue;
        }
        if script_name_char(c) {
            j = i;
            while j < count and script_name_char(text[j]) {
                j += 1;
            }
            tokens.append(ScriptToken(kind=TT_NAME, text=text[i:j], line=start_line, first=first, spaced=gap));
            i = j;
            continue;
        }
        matched = "";
        for mark in SCRIPT_PUNCTUATIONS {
            if text[i:i + len(mark)] == mark {
                matched = mark;
                break;
            }
        }
        if not matched {
            raise ValueError("Unknown character in bot script on line " + str(line) + ": " + c);
        }
        tokens.append(ScriptToken(kind=TT_PUNCTUATION, text=matched, line=start_line, first=first, spaced=gap));
        i += len(matched);
    }
    return tokens;
}

"""The files a script includes, so a loader can fetch them before the
precompiler runs (every `#include "name"`; botlib resolves them from the
botfiles folder)."""
def script_includes(text: str) -> list[str] {
    names: list[str] = [];
    tokens = lex_script(text);
    for i in range(len(tokens) - 2) {
        if tokens[i].text == "#"
            and tokens[i].kind == TT_PUNCTUATION
            and tokens[i].first
            and tokens[i + 1].text == "include"
            and tokens[i + 2].kind == TT_STRING {
            names.append(tokens[i + 2].text);
        }
    }
    return names;
}

"""A `#define`: its body and, for a function-like one, its parameters."""
obj ScriptDefine {
    has name: str,
        params: list[str] = [],
        function: bool = False,
        body: list[ScriptToken] = [];
}

"""One value of PC_EvaluateTokens: both the integer and the float, and the
parentheses depth it sits at."""
obj EvalValue {
    has whole: int = 0,
        number: float = 0.0,
        depth: int = 0;
}

obj EvalOperator {
    has mark: str,
        priority: int,
        depth: int;
}

"""l_precomp.c PC_OperatorPriority."""
def operator_priority(mark: str) -> int {
    priorities: dict[str, int] = {
        "*": 15, "/": 15, "%": 15, "+": 14, "-": 14, "&&": 7, "||": 6,
        ">=": 12, "<=": 12, "==": 11, "!=": 11, "!": 16, ">": 12, "<": 12,
        ">>": 13, "<<": 13, "&": 10, "|": 8, "^": 9, "~": 16, ":": 5, "?": 5
    };
    return priorities.get(mark, 0);
}

def truth(value: bool) -> int {
    return 1 if value else 0;
}

"""C integer division and remainder (truncating toward zero)."""
def c_divide(a: int, b: int) -> int {
    quotient = abs(a) // abs(b);
    return quotient if (a >= 0) == (b >= 0) else -quotient;
}

"""l_precomp.c PC_EvaluateTokens, ported as it is: values and operators in
order, each operator reduced once no deeper-nested or higher-priority one
follows, integers and floats computed side by side. `defines` answers
`defined(NAME)`."""
def evaluate_tokens(tokens: list[ScriptToken], integer: bool, defines: dict[str, ScriptDefine]) -> EvalValue {
    values: list[EvalValue] = [];
    operators: list[EvalOperator] = [];
    depth = 0;
    last_was_value = False;
    negative = False;
    i = 0;
    while i < len(tokens) {
        token = tokens[i];
        if token.kind == TT_NAME {
            if token.text != "defined" or last_was_value {
                raise ValueError("Cannot evaluate " + token.text + " in a bot script");
            }
            i += 1;
            braced = i < len(tokens) and tokens[i].text == "(";
            if braced {
                i += 1;
            }
            known = i < len(tokens) and tokens[i].text in defines;
            values.append(EvalValue(whole=truth(known), number=float(truth(known)), depth=depth));
            if braced {
                i += 1;
            }
            last_was_value = True;
        } elif token.kind == TT_NUMBER {
            sign = -1 if negative else 1;
            values.append(EvalValue(whole=sign * token.whole, number=float(sign) * token.number, depth=depth));
            last_was_value = True;
            negative = False;
        } elif token.kind == TT_PUNCTUATION {
            mark = token.text;
            if mark == "(" {
                depth += 1;
            } elif mark == ")" {
                depth -= 1;
            } elif mark == "-" and not last_was_value {
                negative = True;
            } else {
                if not integer and mark in ["~", "%", ">>", "<<", "&", "|", "^"] {
                    raise ValueError("Integer operator " + mark + " in a float expression");
                }
                if operator_priority(mark) == 0 {
                    raise ValueError("Invalid operator " + mark + " in a bot script expression");
                }
                operators.append(EvalOperator(mark=mark, priority=operator_priority(mark), depth=depth));
                last_was_value = False;
            }
        } else {
            raise ValueError("Cannot evaluate " + token.text + " in a bot script");
        }
        i += 1;
    }
    marked = False;
    marked_whole = 0;
    marked_number = 0.0;
    while operators {
        at = 0;
        slot = 0;
        while at + 1 < len(operators) {
            here = operators[at];
            after = operators[at + 1];
            if here.depth > after.depth {
                break;
            }
            if here.depth == after.depth and here.priority >= after.priority {
                break;
            }
            if here.mark not in ["!", "~"] {
                slot += 1;
            }
            at += 1;
        }
        op = operators[at];
        first = values[slot];
        second = values[slot + 1] if slot + 1 < len(values) else EvalValue();
        mark = op.mark;
        if mark == "!" {
            first.whole = truth(first.whole == 0);
            first.number = float(truth(first.number == 0.0));
        } elif mark == "~" {
            first.whole = ~first.whole;
        } elif mark == "*" {
            first.whole *= second.whole;
            first.number *= second.number;
        } elif mark == "/" {
            if second.whole == 0 or second.number == 0.0 {
                raise ValueError("Divide by zero in a bot script expression");
            }
            first.whole = c_divide(first.whole, second.whole);
            first.number /= second.number;
        } elif mark == "%" {
            first.whole = first.whole - c_divide(first.whole, second.whole) * second.whole;
        } elif mark == "+" {
            first.whole += second.whole;
            first.number += second.number;
        } elif mark == "-" {
            first.whole -= second.whole;
            first.number -= second.number;
        } elif mark == "&&" {
            first.whole = truth(first.whole != 0 and second.whole != 0);
            first.number = float(truth(first.number != 0.0 and second.number != 0.0));
        } elif mark == "||" {
            first.whole = truth(first.whole != 0 or second.whole != 0);
            first.number = float(truth(first.number != 0.0 or second.number != 0.0));
        } elif mark == ">=" {
            first.whole = truth(first.whole >= second.whole);
            first.number = float(truth(first.number >= second.number));
        } elif mark == "<=" {
            first.whole = truth(first.whole <= second.whole);
            first.number = float(truth(first.number <= second.number));
        } elif mark == "==" {
            first.whole = truth(first.whole == second.whole);
            first.number = float(truth(first.number == second.number));
        } elif mark == "!=" {
            first.whole = truth(first.whole != second.whole);
            first.number = float(truth(first.number != second.number));
        } elif mark == ">" {
            first.whole = truth(first.whole > second.whole);
            first.number = float(truth(first.number > second.number));
        } elif mark == "<" {
            first.whole = truth(first.whole < second.whole);
            first.number = float(truth(first.number < second.number));
        } elif mark == ">>" {
            first.whole = first.whole >> second.whole;
        } elif mark == "<<" {
            first.whole = first.whole << second.whole;
        } elif mark == "&" {
            first.whole = first.whole & second.whole;
        } elif mark == "|" {
            first.whole = first.whole | second.whole;
        } elif mark == "^" {
            first.whole = first.whole ^ second.whole;
        } elif mark == ":" {
            if not marked {
                raise ValueError(": without ? in a bot script expression");
            }
            if integer {
                if marked_whole == 0 {
                    first.whole = second.whole;
                }
            } elif marked_number == 0.0 {
                first.number = second.number;
            }
            marked = False;
        } elif mark == "?" {
            if marked {
                raise ValueError("? after ? in a bot script expression");
            }
            marked_whole = first.whole;
            marked_number = first.number;
            marked = True;
        }
        if mark not in ["!", "~"] {
            # The question mark drops its condition, every other operator
            # its second value.
            dropped = slot if mark == "?" else slot + 1;
            if dropped < len(values) {
                values.pop(dropped);
            }
        }
        operators.pop(at);
    }
    return values[0] if values else EvalValue();
}

"""The precompiler over a set of script files (source_t): `files` maps
each botfiles path (botlib prefixes the botfiles folder) to its text."""
obj BotScript {
    has files: dict[str, str] = {},
        defines: dict[str, ScriptDefine] = {},
        scripts: list[list[ScriptToken]] = [],
        places: list[int] = [],
        pending: list[ScriptToken] = [],
        skipping: list[bool] = [],
        decided: list[bool] = [],
        expansions: int = 0;

    """All tokens of `path` with directives run and macros expanded."""
    def tokens(path: str) -> list[ScriptToken] {
        self.push_file(path);
        result: list[ScriptToken] = [];
        while True {
            token = self.read();
            if token is None {
                break;
            }
            result.append(token);
        }
        return result;
    }

    def push_file(path: str) {
        name = path;
        if name not in self.files and "botfiles/" + name in self.files {
            name = "botfiles/" + name;
        }
        if name not in self.files {
            raise ValueError("Missing bot script " + path);
        }
        self.scripts.append(lex_script(self.files[name]));
        self.places.append(0);
    }

    """The next token as written (PC_ReadSourceToken): pushed-back tokens
    first, then the innermost open script."""
    def next_raw() -> ScriptToken | None {
        if self.pending {
            return self.pending.pop();
        }
        while self.scripts {
            top = len(self.scripts) - 1;
            if self.places[top] < len(self.scripts[top]) {
                token = self.scripts[top][self.places[top]];
                self.places[top] += 1;
                return token;
            }
            self.scripts.pop();
            self.places.pop();
        }
        return None;
    }

    def unread(tokens: list[ScriptToken]) {
        for i in range(len(tokens) - 1, -1, -1) {
            self.pending.append(tokens[i]);
        }
    }

    """The rest of a directive's line from the current script (a trailing
    backslash continues it on the next line)."""
    def directive_line(line: int) -> list[ScriptToken] {
        rest: list[ScriptToken] = [];
        if not self.scripts {
            return rest;
        }
        top = len(self.scripts) - 1;
        tokens = self.scripts[top];
        current = line;
        while self.places[top] < len(tokens) and tokens[self.places[top]].line == current {
            token = tokens[self.places[top]];
            self.places[top] += 1;
            if token.text == "\\"
                and token.kind == TT_PUNCTUATION
                and (self.places[top] >= len(tokens) or tokens[self.places[top]].line != current) {
                current += 1;
                continue;
            }
            rest.append(token);
        }
        return rest;
    }

    def active() -> bool {
        return not any(self.skipping);
    }

    """A `#` directive (PC_ReadDirective)."""
    def directive(hash_mark: ScriptToken) {
        words = self.directive_line(hash_mark.line);
        if not words {
            return;
        }
        name = words[0].text;
        args = words[1:];
        if name == "ifdef" or name == "ifndef" {
            known = bool(args) and args[0].text in self.defines;
            wanted = known if name == "ifdef" else not known;
            self.skipping.append(not wanted);
            self.decided.append(wanted);
        } elif name == "if" {
            wanted = self.active() and evaluate_tokens(self.expand_all(args), True, self.defines).whole != 0;
            self.skipping.append(not wanted);
            self.decided.append(wanted);
        } elif name == "elif" {
            if not self.skipping {
                raise ValueError("#elif without #if in a bot script");
            }
            done = self.decided[len(self.decided) - 1];
            self.skipping.pop();
            wanted = not done and self.active() and evaluate_tokens(self.expand_all(args), True, self.defines).whole != 0;
            self.skipping.append(not wanted);
            self.decided[len(self.decided) - 1] = done or wanted;
        } elif name == "else" {
            if not self.skipping {
                raise ValueError("#else without #if in a bot script");
            }
            done = self.decided[len(self.decided) - 1];
            self.skipping[len(self.skipping) - 1] = done;
            self.decided[len(self.decided) - 1] = True;
        } elif name == "endif" {
            if not self.skipping {
                raise ValueError("#endif without #if in a bot script");
            }
            self.skipping.pop();
            self.decided.pop();
        } elif not self.active() {
            return;
        } elif name == "include" {
            if args and args[0].kind == TT_STRING {
                self.push_file(args[0].text);
            }
        } elif name == "define" {
            self.define(args);
        } elif name == "undef" {
            if args and args[0].text in self.defines {
                self.defines.pop(args[0].text);
            }
        }
    }

    """`#define NAME body` or `#define NAME(a, b) body`; a parameter list
    only when the parenthesis touches the name (on the same line)."""
    def define(words: list[ScriptToken]) {
        if not words {
            return;
        }
        made = ScriptDefine(name=words[0].text);
        rest = words[1:];
        if rest and rest[0].text == "(" and rest[0].kind == TT_PUNCTUATION and not rest[0].spaced {
            made.function = True;
            i = 1;
            while i < len(rest) and rest[i].text != ")" {
                if rest[i].kind == TT_NAME {
                    made.params.append(rest[i].text);
                }
                i += 1;
            }
            rest = rest[i + 1:];
        }
        made.body = rest;
        self.defines[made.name] = made;
    }

    """Tokens with every macro in them expanded (for #if)."""
    def expand_all(tokens: list[ScriptToken]) -> list[ScriptToken] {
        saved_pending = self.pending;
        saved_scripts = self.scripts;
        saved_places = self.places;
        self.pending = [];
        self.scripts = [tokens];
        self.places = [0];
        result: list[ScriptToken] = [];
        while True {
            token = self.read(False);
            if token is None {
                break;
            }
            result.append(token);
        }
        self.pending = saved_pending;
        self.scripts = saved_scripts;
        self.places = saved_places;
        return result;
    }

    """A macro's arguments, split at top-level commas (PC_ReadDefineParms)."""
    def read_arguments() -> list[list[ScriptToken]] {
        arguments: list[list[ScriptToken]] = [[]];
        depth = 1;
        while True {
            token = self.next_raw();
            if token is None {
                raise ValueError("Unterminated macro arguments in a bot script");
            }
            if token.text == "(" and token.kind == TT_PUNCTUATION {
                depth += 1;
            } elif token.text == ")" and token.kind == TT_PUNCTUATION {
                depth -= 1;
                if depth == 0 {
                    break;
                }
            } elif token.text == "," and token.kind == TT_PUNCTUATION and depth == 1 {
                arguments.append([]);
                continue;
            }
            arguments[len(arguments) - 1].append(token);
        }
        return arguments;
    }

    """A macro use: its body with the arguments in, pushed back to be read
    (and expanded) again (PC_ExpandDefineIntoSource)."""
    def expand(name: ScriptToken, made: ScriptDefine) -> bool {
        arguments: list[list[ScriptToken]] = [];
        if made.function {
            opening = self.next_raw();
            if opening is None or opening.text != "(" {
                if opening is not None {
                    self.pending.append(opening);
                }
                return False;
            }
            arguments = self.read_arguments();
        }
        self.expansions += 1;
        if self.expansions > 100000 {
            raise ValueError("Runaway macro expansion in a bot script: " + made.name);
        }
        result: list[ScriptToken] = [];
        for token in made.body {
            if token.kind == TT_NAME and token.text in made.params {
                index = made.params.index(token.text);
                if index < len(arguments) {
                    for part in arguments[index] {
                        result.append(ScriptToken(kind=part.kind, text=part.text, number=part.number, whole=part.whole, integer=part.integer, line=name.line, fresh=False));
                    }
                }
                continue;
            }
            result.append(ScriptToken(kind=token.kind, text=token.text, number=token.number, whole=token.whole, integer=token.integer, line=name.line, fresh=False));
        }
        self.unread(result);
        return True;
    }

    """`$evalint(...)` or `$evalfloat(...)`: the expanded tokens up to the
    closing parenthesis, evaluated to a number token (with a minus sign in
    front when negative; PC_DollarDirective_evalint/_evalfloat)."""
    def dollar(word: ScriptToken) {
        opening = self.read(False);
        if opening is None or opening.text != "(" {
            raise ValueError("No ( after $" + word.text + " in a bot script");
        }
        collected: list[ScriptToken] = [];
        depth = 1;
        while True {
            token = self.read(False);
            if token is None {
                raise ValueError("Unterminated $" + word.text + " in a bot script");
            }
            if token.text == "(" and token.kind == TT_PUNCTUATION {
                depth += 1;
            } elif token.text == ")" and token.kind == TT_PUNCTUATION {
                depth -= 1;
                if depth == 0 {
                    break;
                }
            }
            collected.append(token);
        }
        integer = word.text == "evalint";
        value = evaluate_tokens(collected, integer, self.defines);
        result: list[ScriptToken] = [];
        if integer {
            if value.whole < 0 {
                result.append(ScriptToken(kind=TT_PUNCTUATION, text="-", line=word.line, fresh=False));
            }
            result.append(ScriptToken(kind=TT_NUMBER, text=str(abs(value.whole)), number=float(abs(value.whole)), whole=abs(value.whole), integer=True, line=word.line, fresh=False));
        } else {
            if value.number < 0.0 {
                result.append(ScriptToken(kind=TT_PUNCTUATION, text="-", line=word.line, fresh=False));
            }
            size = abs(value.number);
            result.append(ScriptToken(kind=TT_NUMBER, text=str(size), number=size, whole=int(size), integer=False, line=word.line, fresh=False));
        }
        self.unread(result);
    }

    """The next token for the parser (PC_ReadToken): directives run, skipped
    blocks passed over, `$eval` directives evaluated and macros expanded.
    `directives` is off while reading tokens that are not a file's own."""
    def read(directives: bool = True) -> ScriptToken | None {
        while True {
            token = self.next_raw();
            if token is None {
                return None;
            }
            if directives and token.fresh and token.first and token.text == "#" and token.kind == TT_PUNCTUATION {
                self.directive(token);
                continue;
            }
            if not self.active() {
                continue;
            }
            if token.text == "$" and token.kind == TT_PUNCTUATION {
                word = self.next_raw();
                if word is not None and word.text in ["evalint", "evalfloat"] {
                    self.dollar(word);
                    continue;
                }
                if word is not None {
                    self.pending.append(word);
                }
                return token;
            }
            if token.kind == TT_NAME and token.text in self.defines {
                if self.expand(token, self.defines[token.text]) {
                    continue;
                }
            }
            return token;
        }
        return None;
    }
}

"""The fully precompiled tokens of `path` among `files`."""
def precompile(path: str, files: dict[str, str]) -> list[ScriptToken] {
    return BotScript(files=files).tokens(path);
}
