import math;
import from engine.world.world { World, Player }
import from engine.world.level { Level, BspArea }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.world.arena { ArenaMatch, HasMatch, Competes }
import from engine.world.models { ModelResource, Visual, UsesModel }
import from engine.world.podium {
    Podium,
    HasPodium,
    Figure,
    Poses,
    Portrays,
    Wields,
    Stands,
    PodiumTick,
    podium_figure,
    raise_podium,
    arena_intermission
}
import from engine.formats.bsp { Bsp, Model, MapEntity }
import from engine.formats.animated { AnimatedModel, AnimatedSurface, AnimationFrame }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }

def body_model(name: str) -> ModelResource {
    surface = AnimatedSurface(name="body");
    for pose in ["stand0", "run0", "run1", "attack0", "death0"] {
        surface.frames.append(AnimationFrame(name=pose));
    }
    for i in range(30) {
        surface.frames.append(AnimationFrame(name="gesture" + str(i)));
    }
    return ModelResource(name=name, model=AnimatedModel(surfaces=[surface]), skins=[]);
}

test "the top three finishers take the podium facing the intermission view" {
    world = World();
    bsp = Bsp(models=[Model(head=-1, first_face=0, face_count=0, vis_leaf_count=1)]);
    bsp.entities = [
        MapEntity(fields={"classname": "info_player_intermission", "origin": "0 0 100", "target": "look"}),
        MapEntity(fields={"classname": "target_position", "origin": "100 0 100", "targetname": "look"})
    ];
    level = Level(active=True, bsp=bsp, areas=[BspArea(name="0", bounds=AABB(mins=Vec3(), maxs=Vec3()))]);
    view = arena_intermission(world, bsp);
    assert view[0].z == 100.0 and abs(view[1].x) < 0.001 and abs(view[1].y) < 0.001;
    contest = ArenaMatch(finished=True);
    world +>:HasMatch:+> contest;
    podium = Podium();
    world +>:HasPodium:+> podium;
    rocket = ModelResource(name="rocketlauncher", model=AnimatedModel(), skins=[]);
    rail = ModelResource(name="railgun", model=AnimatedModel(), skins=[]);
    names = ["Sarge", "Grunt", "Major"];
    frags = [20, 7, 3];
    for i in range(3) {
        bot = Opponent(arena=True, game="q3", health=0);
        bot.weapon_visual = Visual();
        bot.weapon_visual +>:UsesModel:+> rocket;
        world +>:HasOpponent:+> bot;
        contest +>:Competes(name=names[i], frags=frags[i]):+> bot;
        figure = podium_figure(body_model(names[i]), None, "sound/player/" + names[i] + "/taunt.wav", 15.0);
        figure +>:Portrays:+> bot;
        podium +>:Poses(name=names[i]):+> figure;
    }
    player = Player(health=100);
    contest +>:Competes(name="You", frags=12, human=True):+> player;
    you = podium_figure(body_model("sarge"), None, "sound/player/sarge/taunt.wav", 15.0);
    you +>:Wields(key="railgun"):+> rail;
    podium +>:Poses(human=True):+> you;
    assert raise_podium(world, contest, level, view[0], view[1], "railgun") is podium;
    # SpawnPodium: 80 ahead and 70 down, turned back toward the view.
    assert abs(podium.pos.x - 80.0) < 0.001 and abs(podium.pos.z - 30.0) < 0.001;
    assert abs(abs(podium.yaw) - math.pi) < 0.001;
    places = [edge podium->:Stands:->];
    standing = [podium->:Stands:->][?:Figure];
    assert len(standing) == 3;
    winner: Figure | None = None;
    for i in range(3) {
        if places[i].place == 1 {
            winner = standing[i];
            # offsetFirst: straight up 74 on the top pad.
            assert abs(standing[i].pos.x - 80.0) < 0.001 and abs(standing[i].pos.z - 104.0) < 0.001;
        } elif places[i].place == 2 {
            # The human came second: offsetSecond, holding the railgun.
            assert standing[i] is you;
            assert abs(standing[i].pos.x - 90.0) < 0.001 and abs(abs(standing[i].pos.y) - 60.0) < 0.001;
            assert [you.weapon->:UsesModel:->][?:ModelResource] == [rail] and you.weapon.visible;
        } else {
            assert abs(standing[i].pos.z - 75.0) < 0.001;
        }
    }
    assert winner is not None and winner.body.visible;
    assert [winner.weapon->:UsesModel:->][?:ModelResource] == [rocket];
    # CelebrateStart two seconds in: gesture and taunt, then stand again.
    tick = world spawn PodiumTick(dt=1.9);
    assert not tick.cues and winner.body.first == winner.stand_frame;
    tick = world spawn PodiumTick(dt=0.2);
    assert tick.cues == ["sound/player/Sarge/taunt.wav"];
    assert winner.body.first == winner.gesture_frames[1];
    world spawn PodiumTick(dt=2.3);
    assert winner.body.first == winner.stand_frame and podium.celebrated and podium.taunts == 1;
}
