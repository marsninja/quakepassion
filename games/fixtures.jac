"""Original decorative models and ambient emitters from map entities.

Q1 torches and flames (misc.qc) carry their model, frame group and the
ambientsound call each makes; Q1 ambient_* entities and fluorescent lights are
static looping sounds at ATTN_STATIC. Q2 dead bodies, mine lights, banners and
novelty models follow g_misc.c."""
import math;
import from engine.world.fixtures { Fixture, HasFixture }
import from engine.world.speakers { Speaker, HasSpeaker }
import from engine.world.models { ModelResource, HasModelResource, attach_model }
import from engine.world.world { World, Entity, move_to_area }
import from engine.world.flyers { Flyer, HasFlyer, Bomb, HasBomb }
import from engine.world.level { Level }
import from engine.assets.catalog { AssetCatalog }
import from engine.math.vec3 { Vec3 }

obj FixtureRule {
    has model: str = "",
        group: int = -1,
        frames: list[int] = [],
        rate: float = 10.0,
        sound: str = "",
        volume: float = 1.0,
        attenuation: float = 3.0;
}

def fixture_rule(game: str, kind: str, flags: int) -> FixtureRule | None {
    if game == "q1" {
        flame = "sound/ambience/fire1.wav";
        if kind == "light_torch_small_walltorch" {
            return FixtureRule(model="progs/flame.mdl", group=0, sound=flame, volume=0.5);
        }
        if kind == "light_flame_large_yellow" {
            return FixtureRule(model="progs/flame2.mdl", group=1, sound=flame, volume=0.5);
        }
        if kind in ["light_flame_small_yellow", "light_flame_small_white"] {
            return FixtureRule(model="progs/flame2.mdl", group=0, sound=flame, volume=0.5);
        }
        if kind == "light_fluoro" or kind == "ambient_light_buzz" {
            return FixtureRule(sound="sound/ambience/fl_hum1.wav", volume=0.5);
        }
        if kind == "light_fluorospark" {
            return FixtureRule(sound="sound/ambience/buzz1.wav", volume=0.5);
        }
        if kind == "ambient_flouro_buzz" {
            return FixtureRule(sound="sound/ambience/buzz1.wav");
        }
        if kind == "ambient_comp_hum" {
            return FixtureRule(sound="sound/ambience/comp1.wav");
        }
        if kind == "ambient_drip" {
            return FixtureRule(sound="sound/ambience/drip1.wav", volume=0.5);
        }
        if kind == "ambient_drone" {
            return FixtureRule(sound="sound/ambience/drone6.wav", volume=0.5);
        }
        if kind == "ambient_suck_wind" {
            return FixtureRule(sound="sound/ambience/suck1.wav");
        }
        if kind in ["ambient_swamp1", "ambient_swamp2"] {
            return FixtureRule(sound="sound/ambience/" + kind[8:] + ".wav", volume=0.5);
        }
        return None;
    }
    if game == "q2" {
        if kind == "misc_deadsoldier" {
            pose = 0;
            for bit in range(1, 6) {
                if flags & (1 << bit) {
                    pose = bit;
                    break;
                }
            }
            return FixtureRule(model="models/deadbods/dude/tris.md2", frames=[pose]);
        }
        if kind == "light_mine1" {
            return FixtureRule(model="models/objects/minelite/light1/tris.md2");
        }
        if kind == "light_mine2" {
            return FixtureRule(model="models/objects/minelite/light2/tris.md2");
        }
        if kind == "misc_banner" {
            return FixtureRule(
                model="models/objects/banner/tris.md2", frames=list(range(16))
            );
        }
        if kind == "misc_satellite_dish" {
            return FixtureRule(model="models/objects/satellite/tris.md2");
        }
        if kind == "misc_blackhole" {
            return FixtureRule(model="models/objects/black/tris.md2", frames=list(range(19)));
        }
        if kind == "misc_easterchick" {
            return FixtureRule(model="models/monsters/bitch/tris.md2", frames=list(range(208, 248)));
        }
        if kind == "misc_easterchick2" {
            return FixtureRule(model="models/monsters/bitch/tris.md2", frames=list(range(248, 288)));
        }
        # g_misc.c SP_misc_gib_*: severed remains left lying in the level.
        if kind == "misc_gib_head" {
            return FixtureRule(model="models/objects/gibs/skull/tris.md2");
        }
        if kind == "misc_gib_arm" {
            return FixtureRule(model="models/objects/gibs/arm/tris.md2");
        }
        if kind == "misc_gib_leg" {
            return FixtureRule(model="models/objects/gibs/leg/tris.md2");
        }
        if kind == "misc_eastertank" {
            return FixtureRule(model="models/monsters/tank/tris.md2", frames=list(range(254, 293)));
        }
    }
    return None;
}

def populate_fixtures(world: World, level: Level, directory: str) -> int {
    catalog = AssetCatalog(game=level.bsp.game, directory=directory);
    resources: dict[str, ModelResource] = {};
    count = 0;
    try {
        for entity in level.bsp.entities {
            fields = entity.fields;
            source = fields.get("asset_game", level.bsp.game);
            rule = fixture_rule(
                source, fields.get("classname", ""), int(fields.get("spawnflags", "0"))
            );
            if rule is None {
                continue;
            }
            parts = fields.get("origin", "0 0 0").split();
            if len(parts) != 3 {
                raise ValueError("Invalid fixture origin");
            }
            position = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
            if rule.sound {
                world +>:HasSpeaker:+> Speaker(
                    path=rule.sound,
                    origin=position,
                    volume=rule.volume,
                    attenuation=rule.attenuation,
                    looping=True,
                    playing=True
                );
            }
            if not rule.model {
                continue;
            }
            key = source + ":" + rule.model;
            if key not in resources {
                loaded = catalog.model(key);
                resource = ModelResource(name=key, model=loaded.model, skins=loaded.skins);
                resources[key] = resource;
                world +>:HasModelResource:+> resource;
            }
            fixture = Fixture(
                pos=position,
                yaw=float(fields.get("angle", "0")) * math.pi / 180.0,
                frames=rule.frames
            );
            surface = resources[key].model.surfaces[0];
            if rule.group >= 0 and rule.group < len(surface.frame_groups) {
                group = surface.frame_groups[rule.group];
                fixture.frames = list(range(group.first, group.first + group.count));
                if group.intervals {
                    fixture.rate = 1.0 / max(0.01, group.intervals[0]);
                }
            }
            fixture.frames = [
                frame for frame in fixture.frames if frame < len(surface.frames)
            ];
            fixture.visual = attach_model(fixture, resources[key]);
            if fixture.frames {
                fixture.visual.first = fixture.frames[0];
                fixture.visual.second = fixture.frames[0];
            }
            move_to_area(fixture, level.areas[level.locate(position)]);
            world +>:HasFixture:+> fixture;
            count += 1;
        }
        # Fly-by ships and their bombs take their original models.
        flyers = [world->:HasFlyer:->][?:Flyer];
        bombs = [world->:HasBomb:->][?:Bomb];
        pieces: list[Entity] = [];
        paths: list[str] = [];
        for flyer in flyers {
            pieces.append(flyer);
            paths.append(flyer.model);
        }
        for bomb in bombs {
            pieces.append(bomb);
            paths.append("models/objects/bomb/tris.md2");
        }
        for i in range(len(pieces)) {
            key = "q2:" + paths[i];
            if key not in resources {
                loaded = catalog.model(key);
                resources[key] = ModelResource(name=key, model=loaded.model, skins=loaded.skins);
                world +>:HasModelResource:+> resources[key];
            }
            shown = attach_model(pieces[i], resources[key]);
            shown.visible = False;
            if isinstance(pieces[i], Flyer) {
                flyers[i].visual = shown;
            } else {
                bombs[i - len(flyers)].visual = shown;
            }
            move_to_area(pieces[i], level.areas[level.locate(pieces[i].pos)]);
        }
    } finally {
        catalog.close();
    }
    return count;
}
