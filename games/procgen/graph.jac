"""Recipes as graphs: every generated picture is made by a graph of
operators, each an `Op` node, joined by `Feeds` edges from the ops whose
results it takes (an edge's `slot` says which of its inputs it is). An
`Evaluate` walker starts at the op whose result is wanted, walks back over
the edges into what it needs (depth first, so an op's inputs are made before
it), and on its way out makes each op's result and keeps it on the node, so
an op two others take from is made once.

A recipe is written through a `Recipe`, which makes the nodes and edges:

    r = Recipe(seed=hash_label(0, "metal1_2"));
    plate = r.op("panels", {"nx": 2.0, "ny": 2.0, "seam": 2.0, "bevel": 3.0});
    lit = r.op("shade", {"depth": 3.0}, [plate]);
    out = r.op("ramp", {}, [lit], "3b3b4b,8b8b9b");
    picture = r.picture(out);

Everything an op makes is a pure function of its kind, its numbers, its
text and its inputs, so a recipe's `signature` (all of those, in order)
names what it makes: the bake keeps what it made under that name and makes
it again only when the signature changes."""
import from games.passion.random { mix32, hash_label }
import from .field {
    Field, flat, value_noise, fbm, worley, bricks, panels, rivets, stripes, warp, blur, shade, creases, normalized,
    levels, combine, streaks, lattice
}
import from .image { Picture, Rgb, ramped, masked, lit, stained, hex_rgb, filled }

"""What an op makes: a field or a picture."""
obj Made {
    has field: Field | None = None,
        picture: Picture | None = None;
}

node Op {
    has kind: str,
        numbers: dict[str, float] = {},
        text: str = "",
        arity: int = 0,
        w: int = 64,
        h: int = 64,
        seed: int = 0,
        made: Made | None = None;

    def number(name: str, fallback: float) -> float {
        return self.numbers.get(name, fallback);
    }

    """The op's own words in a recipe's signature."""
    def words -> str {
        parts = [self.kind, str(self.w) + "x" + str(self.h), str(self.seed), self.text];
        for name in sorted(self.numbers.keys()) {
            parts.append(name + "=" + str(round(self.numbers[name], 5)));
        }
        return "|".join(parts);
    }
}

edge Feeds: Op --> Op {
    has slot: int = 0;
}

"""Makes the result of every op the start needs, inputs first."""
walker Evaluate {
    has made_count: int = 0;

    can enter with Op entry {
        if here.made is None {
            visit :0: [here<-:Feeds:<-];
        }
    }

    can leave with Op exit {
        if here.made is None {
            inputs: list[Made] = [];
            for wanted in range(here.arity) {
                for source in [here<-:Feeds:slot == wanted:<-] {
                    if source.made is not None {
                        inputs.append(source.made);
                    }
                }
            }
            here.made = make(here, inputs);
            self.made_count += 1;
        }
    }
}

"""Writes the signature of what an op makes, its inputs before it."""
walker Sign {
    has parts: list[str] = [],
        seen: list[Op] = [];

    can enter with Op entry {
        if here in self.seen {
            return;
        }
        self.seen.append(here);
        visit :0: [here<-:Feeds:<-];
    }

    can leave with Op exit {
        self.parts.append(here.words());
    }
}

obj Recipe {
    has seed: int = 0,
        w: int = 64,
        h: int = 64,
        count: int = 0,
        ops: list[Op] = [];

    """Let go of everything the recipe made and of its graph: each op's
    result, and the edges between the ops, so a bake that makes thousands of
    pictures does not keep every step of every one."""
    def release() {
        for made_op in self.ops {
            for source in [made_op<-:Feeds:<-] {
                source del --> made_op;
            }
            made_op.made = None;
        }
        self.ops = [];
    }

    """A new op of `kind` taking `inputs` in order. Each op draws its own seed
    from the recipe's, by its place in the recipe, unless `numbers` gives
    one ("seed")."""
    def op(kind: str, numbers: dict[str, float] = {}, inputs: list[Op] = [], text: str = "") -> Op {
        self.count += 1;
        seed = mix32(self.seed ^ mix32(self.count * 40503));
        if "seed" in numbers {
            seed = mix32(self.seed ^ int(numbers["seed"]));
        }
        made = Op(kind=kind, numbers=dict(numbers), text=text, arity=len(inputs), w=self.w, h=self.h, seed=seed);
        self.ops.append(made);
        for slot in range(len(inputs)) {
            inputs[slot] +>:Feeds:slot=slot:+> made;
        }
        return made;
    }

    def evaluate(out: Op) -> Made {
        out spawn Evaluate();
        if out.made is None {
            raise ValueError("A recipe made nothing for " + out.kind);
        }
        return out.made;
    }

    def field(out: Op) -> Field {
        made = self.evaluate(out);
        if made.field is not None {
            return made.field;
        }
        raise ValueError("A recipe's " + out.kind + " is not a field");
    }

    def picture(out: Op) -> Picture {
        made = self.evaluate(out);
        if made.picture is not None {
            return made.picture;
        }
        if made.field is not None {
            return ramped(made.field, [Rgb(), Rgb(r=1.0, g=1.0, b=1.0)]);
        }
        raise ValueError("A recipe's " + out.kind + " is not a picture");
    }
}

"""What a recipe makes, named: every op it takes, in the order they are
made."""
def signature(out: Op) -> str {
    signed = out spawn Sign();
    return "\n".join(signed.parts);
}

def:priv field_in(inputs: list[Made], slot: int, w: int, h: int) -> Field {
    if slot < len(inputs) {
        found = inputs[slot].field;
        if found is not None {
            return found;
        }
    }
    return flat(w, h, 0.5);
}

def:priv picture_in(inputs: list[Made], slot: int, w: int, h: int) -> Picture {
    if slot < len(inputs) {
        found = inputs[slot].picture;
        if found is not None {
            return found;
        }
        shades = inputs[slot].field;
        if shades is not None {
            return ramped(shades, [Rgb(), Rgb(r=1.0, g=1.0, b=1.0)]);
        }
    }
    return filled(w, h, Rgb(r=0.5, g=0.5, b=0.5));
}

"""A ramp's colours from text: hex colours joined by commas."""
def ramp_of(text: str) -> list[Rgb] {
    made: list[Rgb] = [];
    for word in text.split(",") {
        word = word.strip();
        if len(word) == 6 {
            made.append(hex_rgb(word));
        }
    }
    if not made {
        made = [Rgb(), Rgb(r=1.0, g=1.0, b=1.0)];
    }
    return made;
}

"""Make one op's result from its inputs."""
def make(op: Op, inputs: list[Made]) -> Made {
    w = op.w;
    h = op.h;
    kind = op.kind;
    if kind == "flat" {
        return Made(field=flat(w, h, op.number("value", 0.5)));
    } elif kind == "noise" {
        return Made(
            field=fbm(
                w, h, int(op.number("cells", 4.0)), int(op.number("octaves", 4.0)), op.number("keep", 0.5), op.seed
            )
        );
    } elif kind == "smooth_noise" {
        cells = int(op.number("cells", 4.0));
        return Made(field=value_noise(w, h, cells, max(1, cells * h // max(1, w)), op.seed));
    } elif kind == "streaks" {
        return Made(field=streaks(w, h, int(op.number("cells", 16.0)), int(op.number("stretch", 8.0)), op.seed));
    } elif kind == "cells" or kind == "cell_rims" or kind == "cell_tones" {
        found = worley(w, h, int(op.number("count", 16.0)), op.seed);
        if kind == "cells" {
            return Made(field=normalized(found.near));
        }
        if kind == "cell_tones" {
            tones = Field(w=w, h=h);
            for i in range(w * h) {
                tones.v[i] = lattice(op.seed, found.cell[i], 7);
            }
            return Made(field=tones);
        }
        rims = Field(w=w, h=h);
        width = op.number("width", 2.0);
        for i in range(w * h) {
            rims.v[i] = min(1.0, (found.next.v[i] - found.near.v[i]) / max(0.25, width));
        }
        return Made(field=rims);
    } elif kind == "bricks" or kind == "brick_tones" or kind == "panels" or kind == "panel_tones" {
        laid = bricks(
            w, h, int(op.number("rows", 4.0)), int(op.number("cols", 2.0)), op.number("mortar", 2.0),
            op.number("bevel", 2.0), op.number("shift", 0.0 if kind.startswith("panel") else 0.5)
        );
        if kind == "bricks" or kind == "panels" {
            return Made(field=laid.height);
        }
        tones = Field(w=w, h=h);
        for i in range(w * h) {
            tones.v[i] = 0.5 if laid.brick[i] < 0 else lattice(op.seed, laid.brick[i], 3);
        }
        return Made(field=tones);
    } elif kind == "rivets" {
        return Made(
            field=rivets(
                w, h, int(op.number("nx", 4.0)), int(op.number("ny", 4.0)), op.number("radius", 2.0),
                op.number("inset", 0.5)
            )
        );
    } elif kind == "stripes" {
        return Made(field=stripes(w, h, int(op.number("count", 4.0)), op.number("across", 1.0) > 0.5));
    } elif kind == "warp" {
        return Made(
            field=warp(
                field_in(inputs, 0, w, h), field_in(inputs, 1, w, h), field_in(inputs, 2, w, h),
                op.number("amount", 4.0)
            )
        );
    } elif kind == "blur" {
        return Made(field=blur(field_in(inputs, 0, w, h), int(op.number("radius", 1.0))));
    } elif kind == "shade" {
        return Made(field=shade(field_in(inputs, 0, w, h), op.number("depth", 2.0)));
    } elif kind == "creases" {
        return Made(field=creases(field_in(inputs, 0, w, h), int(op.number("radius", 2.0))));
    } elif kind == "normalize" {
        return Made(field=normalized(field_in(inputs, 0, w, h)));
    } elif kind == "levels" {
        return Made(field=levels(field_in(inputs, 0, w, h), op.number("low", 0.0), op.number("high", 1.0)));
    } elif kind == "invert" {
        source = field_in(inputs, 0, w, h);
        return Made(field=Field(w=w, h=h, v=[1.0 - value for value in source.v]));
    } elif kind == "combine" {
        return Made(
            field=combine(field_in(inputs, 0, w, h), field_in(inputs, 1, w, h), op.text, op.number("amount", 0.5))
        );
    } elif kind == "ramp" {
        return Made(picture=ramped(field_in(inputs, 0, w, h), ramp_of(op.text)));
    } elif kind == "over" {
        return Made(picture=masked(picture_in(inputs, 0, w, h), picture_in(inputs, 1, w, h), field_in(inputs, 2, w, h)));
    } elif kind == "lit" {
        return Made(picture=lit(picture_in(inputs, 0, w, h), field_in(inputs, 1, w, h), op.number("strength", 1.0)));
    } elif kind == "stain" {
        tint = ramp_of(op.text)[0];
        return Made(
            picture=stained(picture_in(inputs, 0, w, h), field_in(inputs, 1, w, h), tint, op.number("strength", 1.0))
        );
    }
    raise ValueError("No op called " + kind);
}
