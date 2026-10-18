"""Families: how a name finds its recipe. A recipe family is a `Family` node
under a `Families` node, listing the words in a name that call for it. A
`ChooseFamily` walker visits every family and scores each by the words it
finds in the name (a longer word says more than a short one), and the name
is made by the best."""

node Families {}

node Family {
    has key: str,
        words: list[str] = [],
        weight: float = 1.0;
}

edge Kin: Families --> Family {}

"""The family whose words best fit a name."""
walker ChooseFamily {
    has name: str,
        best: str = "",
        score: float = 0.0;

    can start with Families entry {
        visit [here->:Kin:->];
    }

    can weigh with Family entry {
        total = 0.0;
        for word in here.words {
            if word in self.name {
                total += float(len(word)) * here.weight;
            }
        }
        if total > self.score {
            self.score = total;
            self.best = here.key;
        }
    }
}

"""Families from a table of (key, words)."""
def families_of(table: list[tuple[str, list[str]]]) -> Families {
    made = Families();
    for (key, words) in table {
        made +>:Kin:+> Family(key=key, words=words);
    }
    return made;
}

"""The best family for a (lowercase) name; "" when no word fits."""
def choose_family(families: Families, name: str) -> str {
    chosen = families spawn ChooseFamily(name=name);
    return chosen.best;
}
