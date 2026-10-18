# Generated assets

With the setting on, every asset the three games draw and play is made by
code (`games/procgen/`) instead of read from the games' archives: wall
textures, skies, palettes, the HUD and menus, fonts, sprites, items,
weapons, monsters, player models, sound effects, voices, music and films.
Only the level geometry, the light baked into it, and what the games read
as rules (scripts, shader scripts, bot files) are kept. The roadmap is
issue #98.

## Use

Turn it on in Settings ("Generated assets"), or start with it:

```sh
QP_GENERATED=1 DYLD_LIBRARY_PATH=vendor ./qp
```

- `qp_generated` (archived, 0 or 1) takes effect at the next level load, as
  Skill does; `QP_GENERATED` overrides the saved setting for one run.
- The first level load with it on bakes what the game being played draws on
  into `~/.quakepassion-generated/<pack>/` (`QP_GENERATED_DIR` names another
  folder): Quake about 10 s, Quake II about 19 s, Quake III about 32 s. A
  stamp beside each archive (the generator's version and every source
  archive's name, size and time) keeps the bake until either changes.
- Passion draws on all three games, so a Passion run bakes all three.
- `QP_GENERATED_SKIP=character,music` leaves those families to the games'
  own data (for finding which generated asset a fault follows).

## Coverage

`scripts/generated_coverage.jac` reports what the generator makes of a game
and what it leaves:

```sh
jac build scripts/generated_coverage.jac --native -o .jac/qp-coverage
DYLD_LIBRARY_PATH=vendor .jac/qp-coverage q3     # QP_COVERAGE_NAMES=1 lists the names left
```

| Game | Made | Left | Left by design |
| --- | --- | --- | --- |
| Quake | 948 | 0 | 60 (maps, progs.dat and other data) |
| Quake II | 3325 | 0 | 82 (maps, configs, data) |
| Quake III | 2916 | 0 | 681 (maps, shader scripts, bot files, configs) |

By kind, for Quake III: 1911 images, 372 MD3 models, 598 sounds, 16 music
tracks and 11 films.

## How it works

- **The overlay** (`engine/assets/generated.jac`): the bake writes one
  archive per pack (`zzzz-generated.pak` or `.pk3`) and, with the setting
  on, that folder is laid over the top of the pack's search path
  (`content.game_directory`), and over each game's folder in Passion's
  catalog. A name the archive holds is read from it; anything else still
  comes from the game. Quake's wall textures live inside its maps, so the
  bake keeps each as `miptex/<name>.mip` and a map's, an item model's and a
  Passion material's textures are swapped for them by name as they are read.
- **The manifest** (`manifest.jac`): a graph of `Source` nodes (the pack's
  archives, each map, the CD) that `Want` `AssetSlot`s, one for each name a
  game asks for, with the facts its header gives: a texture's size, a
  sound's length, rate and loop, a model's frames, frame and skin groups,
  surfaces, shaders and tags, a Quake III image's role in its shaders. No
  recipe reads an original's pixels, samples or vertices.
- **Recipes**: textures, 2D art and sky boxes are graphs of `Op` nodes
  joined by `Feeds` edges that an `Evaluate` walker makes inputs-first
  (`graph.jac`); which recipe a name gets is chosen by a walk over `Family`
  nodes (`families.jac`); characters are skeletons of `Bone` nodes posed by
  a `PoseWalk` walker (`characters.jac`).
- **The bake** (`bake.jac`): fills every slot, writing each file to the
  archive as it is made (`writers.jac` `ArchiveWriter`) and letting go of
  every recipe's graph and every model's frames as it goes (a Quake bake
  peaks at 0.7 GB).

## What each kind is made of

| Kind | Made by | Notes |
| --- | --- | --- |
| Palettes | `palette.jac` | Rows of sixteen shades in each game's order, so the rules' palette numbers (blood, explosions, blaster, rail) still mean what they did; Quake's last 32 colours fullbright |
| Wall textures | `textures.jac` | 24 families (brick, stone, rock, ground, grass, metal, grate, tech, wood, crate, door, light, button, rune, flesh, tile, trim, glass, water, slime, lava, teleport, sky, blank), chosen from the name (and Quake II's surface flags); animation frames share a seed; sizes kept (Quake and Quake II map coordinates are in texels) |
| Quake III images | `textures.jac` `paint_role` | Drawn for their shaders' role: base, alpha (cut out), add (a glow on black), filter, blend, env |
| Skies | `skies.jac`, `textures.jac` | Quake's two-layer sky; Quake II's and Quake III's sky boxes painted along each texel's direction with 3D noise, so the sides meet |
| 2D art | `art2d.jac`, `canvas.jac`, `glyphs.jac` | A stroke font for every printable character; console fonts, Quake III's proportional font laid out by the engine's `PROP_MAP`, numbers, icons, faces, bars, screens, plaques, crosshairs, level shots |
| Models | `models.jac`, `shapes.jac` | Pickups, weapons, projectiles, gibs, flames, flashes, flags, dressing; fitted into the original's box (a weapon into its rest frame's), frames moving by their names (a weapon raised, fired, put away) |
| Characters | `characters.jac` | Bipeds, brutes, giants, quadrupeds, flyers, fish, blobs; each frame posed from its name (stand, walk, run, attack, pain, death, jump, swim, crouch, taunt); Quake III players as three models joined by tags, animated from `animation.cfg` |
| Skins | `models.jac` `material_atlas` | Every model lays its pieces on one atlas of sixteen materials, so every skin a game names is painted as that atlas |
| Sprites | `sprites.jac` | Fireballs, rings and glows, a picture for each frame |
| Sounds | `sounds.jac`, `synth.jac` | An sfxr-style synthesizer; 18 families; a creature's cry pitched by its size; loops made to loop |
| Voices | `voices.jac` | A formant synthesizer for the announcer's words, read from the sound's name |
| Music | `music.jac` | A sequencer and synthesized instruments: dark ambient for Quake, industrial metal for Quake II, electronic for Quake III; CD tracks are written as `music/trackNN.ogg` holding WAV data |
| Films | `film.jac` | Each cinematic a title card that plays as a film |

## Validation

What was run for this work:

- `jac check` on every changed file, and a native build of `qp`.
- e1m1, base1 and q3dm1 played with `QP_GENERATED=1` from an empty bake
  folder, with a capture of each (walls, HUD, view weapons, the Quake III
  scoreboard).
- The coverage script for all three games.
- Probes for each generator on its own while it was written (texture and 2D
  contact sheets, spectrograms of music and speech, model bounds against the
  originals).

## Limits

- **Looks**: the recipes are first passes. Textures read as their families
  but repeat their patterns; characters are capsule figures; voices are
  robotic, as the issue expected.
- **Monster and player models** keep the original's frames and their names,
  so the rules play as before, but a frame's pose comes from its name alone.
- **Text and rules are not generated**: maps, scripts, configs, bot files
  and Quake III shader scripts are read from the games, by design.
- **The games must be installed.** The manifest is read from them, and
  Passion opens their maps for its materials. A run with no game data
  installed (the issue's last stretch goal) was left out of scope: it would
  have meant shipping a manifest of id's names and facts in the repository,
  or guessing models' frame layouts from names alone.
