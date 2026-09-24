import math;
import from engine.world.world { World, Player }
import from engine.world.level { Level, BspArea }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.world.arena { ArenaMatch, HasMatch, Competes }
import from engine.world.models { ModelResource, PlayerRig, WeaponKit, Holds }
import from engine.world.player_rig { dress_rig, rig_clips, hold_kit, ANIM_TORSO_GESTURE, ANIM_TORSO_STAND, ANIM_LEGS_IDLE }
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
import from engine.formats.animated { AnimatedModel }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }

def body_model(name: str) -> PlayerRig {
    rows: list[list[float]] = [];
    for i in range(25) {
        rows.append([float(i * 40), 40.0 if i == ANIM_TORSO_GESTURE else 1.0, 0.0, 18.0]);
    }
    part = ModelResource(name=name, model=AnimatedModel(), skins=[]);
    return dress_rig(rig_clips(rows), part, part, part);
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
    rocket = WeaponKit(key="rocketlauncher");
    rail = WeaponKit(key="railgun");
    names = ["Sarge", "Grunt", "Major"];
    frags = [20, 7, 3];
    for i in range(3) {
        bot = Opponent(arena=True, game="q3", health=0);
        bot.visual = body_model(names[i]);
        hold_kit(bot.visual, rocket);
        world +>:HasOpponent:+> bot;
        contest +>:Competes(name=names[i], frags=frags[i]):+> bot;
        figure = podium_figure(body_model(names[i]), "sound/player/" + names[i] + "/taunt.wav");
        figure +>:Portrays:+> bot;
        podium +>:Poses(name=names[i]):+> figure;
    }
    player = Player(health=100);
    contest +>:Competes(name="You", frags=12, human=True):+> player;
    you = podium_figure(body_model("sarge"), "sound/player/sarge/taunt.wav");
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
            assert [you.body->:Holds:->][?:WeaponKit] == [rail] and you.body.weapon == "railgun";
        } else {
            assert abs(standing[i].pos.z - 75.0) < 0.001;
        }
    }
    assert winner is not None and winner.body.visible;
    assert [winner.body->:Holds:->][?:WeaponKit] == [rocket];
    # CelebrateStart two seconds in: gesture and taunt, then stand again.
    tick = world spawn PodiumTick(dt=1.9);
    assert not tick.cues and winner.body.torso_anim == ANIM_TORSO_STAND and winner.body.legs_anim == ANIM_LEGS_IDLE;
    tick = world spawn PodiumTick(dt=0.2);
    assert tick.cues == ["sound/player/Sarge/taunt.wav"];
    assert winner.body.torso_anim == ANIM_TORSO_GESTURE;
    for step in range(24) {
        world spawn PodiumTick(dt=0.1);
    }
    assert winner.body.torso_anim == ANIM_TORSO_STAND and podium.celebrated and podium.taunts == 1;
}
