import from engine.world.world { World, Player }
import from engine.world.combat { CombatState, Opponent, HasOpponent }
import from engine.world.targets { TargetEvent, HasTarget, TargetTick }
import from engine.world.signals { Signal }
import from engine.world.triggers { TouchTrigger, HasTrigger, TriggerTick }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }
import from engine.world.level { Level }
import from engine.formats.bsp { Texture, Face }
import from engine.render.quake { QuakeRenderer }

test "a used killbox telefrags everything inside it and nothing outside" {
    world = World();
    collision = CollisionMap();
    box = TargetEvent(kind="killbox", mins=Vec3(x=-64.0, y=-64.0, z=-64.0), maxs=Vec3(x=64.0, y=64.0, z=64.0), activation=Signal(entities=[1]));
    world +>:HasTarget:+> box;
    player = Player(health=100, pos=Vec3(z=collision.eye_height));
    inside = Opponent(health=300, pos=Vec3(x=40.0, z=22.0));
    outside = Opponent(health=300, pos=Vec3(x=400.0, z=22.0));
    world +>:HasOpponent:+> inside;
    world +>:HasOpponent:+> outside;
    world spawn TargetTick(player=player, collision=collision, state=CombatState(), dt=0.01);
    assert player.health == 100 and inside.health == 300;
    box.activation.pending = 1;
    world spawn TargetTick(player=player, collision=collision, state=CombatState(), dt=0.01);
    assert player.health == 0 and inside.health == 0 and outside.health == 300;
}

test "Q1 and Q2 textures animate by the original clocks and entity frames" {
    level = Level();
    level.bsp.game = "q1";
    level.bsp.textures = [Texture(name="+0button"), Texture(name="+1button"), Texture(name="+abutton"), Texture(name="wall")];
    level.bsp.faces = [Face(texture=0), Face(texture=0, frame=1), Face(texture=3)];
    drawing = QuakeRenderer();
    drawing.build_animations(level);
    assert drawing.anim_frames[0] == [0, 1] and drawing.anim_alternates[0] == [2];
    drawing.time = 0.0;
    assert drawing.shown_texture(level, 0, 0) == 0 and drawing.shown_texture(level, 0, 1) == 2;
    drawing.time = 0.25;
    assert drawing.shown_texture(level, 0, 0) == 1 and drawing.shown_texture(level, 3, 2) == 3;
    q2 = Level();
    q2.bsp.game = "q2";
    q2.bsp.textures = [Texture(name="a"), Texture(name="b"), Texture(name="c")];
    q2.bsp.texture_next = {0: 1, 1: 2, 2: 0};
    q2.bsp.faces = [Face(texture=0)];
    drawing.build_animations(q2);
    assert drawing.anim_frames[0] == [0, 1, 2];
    drawing.time = 1.1;
    assert drawing.shown_texture(q2, 0, 0) == 2;
}

test "Q2 monster-only triggers fire for monsters and ignore the player" {
    world = World();
    volume = CollisionMap();
    volume.add_box(
        Vec3(x=-64.0, y=-64.0, z=0.0),
        Vec3(x=64.0, y=64.0, z=64.0),
        Vec3(),
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0)
    );
    trigger = TouchTrigger(model=1, volume=volume, interval=0.1, monsters=True, players=False);
    world +>:HasTrigger:+> trigger;
    player = Player(health=100, pos=Vec3(z=46.0));
    world spawn TriggerTick(player=player, start=Vec3(z=24.0), finish=Vec3(z=24.0), dt=0.01);
    assert trigger.activations == 0;
    grunt = Opponent(health=30, pos=Vec3(x=600.0, z=46.0));
    world +>:HasOpponent:+> grunt;
    world spawn TriggerTick(player=player, start=Vec3(z=24.0), finish=Vec3(z=24.0), dt=0.01);
    assert trigger.activations == 0;
    grunt.pos = Vec3(x=20.0, z=46.0);
    world spawn TriggerTick(player=player, start=Vec3(z=24.0), finish=Vec3(z=24.0), dt=0.01, touching=False);
    assert trigger.activations == 1;
    # A player-and-monster trigger still fires for the player.
    trigger.players = True;
    trigger.cooldown = 0.0;
    grunt.health = 0;
    world spawn TriggerTick(player=player, start=Vec3(z=24.0), finish=Vec3(z=24.0), dt=0.01);
    assert trigger.activations == 2;
}
