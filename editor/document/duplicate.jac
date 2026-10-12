"""Duplicators as part of the scene's graph: each duplicator's images are
kept on a node of their own, joined to it, and a walker makes them again
only when what they are made from has changed. A duplicator held within
another (its `_group_in` naming the other) is worked out first, and the
one that holds it copies it whole, images and all: duplicators nest."""

import from ..formats.map { MapItem, write_map }
import from ..geometry.brush { Side }
import from .scene { Scene, Item, Within, Holds }
import from .generate { duplicates, image_sets, with_images }

"""A duplicator's images as last made, and a mark of what they were made
from: its fields and the brushes it copies."""
node Images {
    has mark: str = "",
        sets: list[list[list[Side]]] = [];
}

edge Copies: Item --> Images {}

"""What one regeneration found: the scene, every entity of it as the map
has them (for `_at` and `_path`), each entity's whole yield by serial (its
brushes, those of what it holds, and its images), and how many
duplicators' images were made afresh or kept."""
obj Regeneration {
    has scene: Scene,
        others: list[MapItem] = [],
        whole: dict[int, list[list[Side]]] = {},
        sets: dict[int, list[list[list[Side]]]] = {},
        made: int = 0,
        kept: int = 0;
}

"""Visits every entity, and before an entity the groups it holds."""
walker Regenerate {
    has state: Regeneration;

    can start with Scene entry {
        visit [here->:Holds:->];
    }

    can regenerate with Item entry {
        state = self.state;
        if here.serial in state.whole or not here.held {
            return;
        }
        # Marked first, so that a ring of groups holding each other ends.
        state.whole[here.serial] = [];
        source = [solid.sides for solid in state.scene.solids_of(here)];
        for inner in [here<-:Within:<-] {
            inner spawn Regenerate(state=state);
            for sides in state.whole.get(inner.serial, []) {
                source.append(sides);
            }
        }
        yielded = list(source);
        if duplicates(here.fields) and len(source) > 0 {
            mark = write_map([MapItem(fields=dict(here.fields), brushes=source)]);
            kept_images: Images | None = None;
            for held in [here->:Copies:->] {
                kept_images = held;
            }
            if kept_images is None {
                kept_images = Images();
                here +>:Copies:+> kept_images;
            }
            if kept_images.mark == mark {
                state.kept += 1;
            } else {
                kept_images.sets = image_sets(here.fields, source, state.others);
                kept_images.mark = mark;
                state.made += 1;
            }
            state.sets[here.serial] = kept_images.sets;
            for image_set in kept_images.sets {
                for sides in image_set {
                    yielded.append(sides);
                }
            }
        }
        state.whole[here.serial] = yielded;
    }
}

"""Make every duplicator's images that need making, and answer what was
found: each duplicator's images by its serial."""
def regenerate(scene: Scene, others: list[MapItem]) -> Regeneration {
    state = Regeneration(scene=scene, others=others);
    # The edges between groups drawn afresh from their fields, when the document has changed.
    scene.links();
    scene spawn Regenerate(state=state);
    return state;
}

"""A map with every duplicator's images put in, as the walker made them:
`items` are the scene's entities as the map has them, in the scene's order."""
def with_regenerated(scene: Scene, items: list[MapItem]) -> list[MapItem] {
    state = regenerate(scene, items);
    found: dict[int, list[list[list[Side]]]] = {};
    for (index, item) in enumerate(scene.items()) {
        if index < len(items) and item.serial in state.sets {
            found[index] = state.sets[item.serial];
        }
    }
    return with_images(items, found);
}
