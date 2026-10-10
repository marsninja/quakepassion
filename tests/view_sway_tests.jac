"""Each game's view bob, strafe roll and first-person gun placement (Q1
V_CalcBob/V_CalcRoll/V_CalcRefdef, Q2 SV_CalcViewOffset/SV_CalcGunOffset,
Q3 CG_OffsetFirstPersonView/CG_CalculateWeaponPosition)."""
import math;
import from engine.render.view_sway {
    ViewBase,
    Q1ViewSway,
    Q2ViewSway,
    Q3ViewSway,
    q1_view_bob,
    q1_view_roll,
    view_sway_for
}
import from engine.render.view_feedback { ViewFeedback, third_person_view }
import from engine.physics.collision { CollisionMap }
import from engine.world.world { Player }
import from engine.math.vec3 { Vec3, forward_from }

glob TICK: float = 1.0 / 120.0;

test "Q1 bobs with the flat speed over a 0.6 second cycle, between -7 and 4" {
    # A quarter through the cycle the swing peaks: 6.4 at 320 is held at 4.
    assert q1_view_bob(0.15, 320.0) == 4.0;
    assert abs(q1_view_bob(0.15, 100.0) - 2.0) < 0.00001;
    # Three quarters through, it is at its lowest.
    assert abs(q1_view_bob(0.45, 320.0) - (1.92 - 4.48)) < 0.00001;
    assert abs(q1_view_bob(0.6 + 0.45, 320.0) - (1.92 - 4.48)) < 0.00001;
    assert q1_view_bob(0.3, 0.0) == 0.0;
}

test "Q1 rolls up to two degrees strafing, all of it from 200 units a second" {
    assert abs(q1_view_roll(0.0, Vec3(y=-100.0)) - 1.0) < 0.00001;
    assert q1_view_roll(0.0, Vec3(y=-320.0)) == 2.0;
    assert q1_view_roll(0.0, Vec3(y=320.0)) == -2.0;
    assert q1_view_roll(0.0, Vec3(x=320.0)) == 0.0;
}

test "Q1 lifts the eye and gun by the bob and pushes the gun forward" {
    player = Player(velocity=Vec3(x=100.0, y=-100.0), grounded=True);
    base = ViewBase(eye=Vec3(z=50.0), kick_pitch=3.0, kick_roll=1.0, punch=2.0);
    placed = Q1ViewSway().place(player, base, 0.15, 1.0);
    bob = q1_view_bob(0.15, math.sqrt(20000.0));
    assert abs(placed.eye.z - (50.0 + bob)) < 0.00001;
    assert abs(placed.gun.z - (50.0 + bob + 2.0)) < 0.00001;
    assert abs(placed.gun.x - bob * 0.4) < 0.00001;
    # The view takes the kick, the strafe roll and the punch; the gun only
    # the kick's pitch.
    assert abs(placed.roll - math.radians(1.0 + 1.0)) < 0.00001;
    assert abs(placed.pitch - math.radians(-3.0 + 2.0)) < 0.00001;
    assert abs(placed.gun_pitch - math.radians(-3.0)) < 0.00001;
    assert placed.gun_roll == 0.0 and placed.gun_yaw == 0.0;
}

test "Q2 bobs per 100 ms server frame and draws between the last two" {
    player = Player(velocity=Vec3(x=300.0), grounded=True);
    sway = Q2ViewSway();
    for tick in range(24) {
        sway.tick(player, True, TICK);
    }
    # Two server frames: bobtime 0.25 then 0.5 (bobmove 1/4 above 210).
    assert abs(sway.bobtime - 0.5) < 0.00001;
    placed = sway.place(player, ViewBase(eye=Vec3(z=50.0)), 0.0, 1.0);
    first = abs(math.sin(0.25 * math.pi));
    assert abs(placed.eye.z - (50.0 + first * 300.0 * 0.005)) < 0.0001;
    # run_pitch and bob_pitch look down while running forward.
    assert abs(placed.pitch + math.radians(300.0 * 0.002 + first * 0.002 * 300.0)) < 0.0001;
    # Halfway to the next frame, halfway between.
    for tick in range(6) {
        sway.tick(player, True, TICK);
    }
    halfway = sway.place(player, ViewBase(eye=Vec3(z=50.0)), 0.0, 1.0);
    lift = (first * 1.5 + 1.0 * 1.5) * 0.5;
    assert abs(halfway.eye.z - (50.0 + lift)) < 0.0001;
    # Standing still starts the cycle over.
    still = Player(grounded=True);
    for tick in range(24) {
        sway.tick(still, False, TICK);
    }
    assert sway.bobtime == 0.0;
}

test "the Q2 gun lags a turn by a fifth of the last frame's change" {
    player = Player(grounded=True);
    sway = Q2ViewSway();
    for tick in range(12) {
        sway.tick(player, False, TICK);
    }
    player.yaw = math.radians(10.0);
    for tick in range(24) {
        sway.tick(player, False, TICK);
    }
    # The frame after the turn: yaw -2 and roll -1 degrees against it.
    placed = sway.place(player, ViewBase(eye=Vec3(), yaw=player.yaw), 0.0, 1.0);
    assert abs(math.degrees(placed.gun_yaw - placed.yaw) + 2.0) < 0.0001;
    assert abs(math.degrees(placed.gun_roll - placed.roll) + 1.0) < 0.0001;
    # A frame later the gun has caught up.
    for tick in range(12) {
        sway.tick(player, False, TICK);
    }
    settled = sway.place(player, ViewBase(eye=Vec3(), yaw=player.yaw), 0.0, 1.0);
    assert abs(settled.gun_yaw - settled.yaw) < 0.00001;
}

test "Q3 bobs on the stride cycle, only on the ground and while moving" {
    player = Player(velocity=Vec3(x=320.0), grounded=True);
    sway = Q3ViewSway();
    for tick in range(24) {
        sway.tick(player, True, TICK);
    }
    assert abs(sway.cycle - 80.0) < 0.001;
    fracsin = abs(math.sin(80.0 / 127.0 * math.pi));
    placed = sway.place(player, ViewBase(eye=Vec3(z=50.0)), 0.0, 1.0);
    assert abs(placed.eye.z - (50.0 + fracsin * 320.0 * 0.005)) < 0.0001;
    assert abs(placed.roll - math.radians(fracsin * 0.002 * 320.0)) < 0.0001;
    # Between ticks the cycle is drawn between its tick values.
    sway.tick(player, True, TICK);
    halfway = sway.place(player, ViewBase(eye=Vec3(z=50.0)), 0.0, 0.5);
    mid = abs(math.sin((80.0 + 0.4 * 1000.0 * TICK * 0.5) / 127.0 * math.pi));
    assert abs(halfway.eye.z - (50.0 + mid * 1.6)) < 0.0001;
    # Airborne, or not trying to move, the cycle holds; stopped, it restarts.
    held = sway.cycle;
    player.grounded = False;
    sway.tick(player, True, TICK);
    player.grounded = True;
    sway.tick(player, False, TICK);
    assert sway.cycle == held;
    player.velocity = Vec3();
    sway.tick(player, False, TICK);
    assert sway.cycle == 0.0;
    sway.cycle = 50.0;
    sway.landed();
    assert sway.cycle == 0.0;
}

test "the Q3 gun drifts idly, drops a quarter more on landing, and bobs" {
    player = Player(grounded=True);
    sway = Q3ViewSway();
    placed = sway.place(player, ViewBase(eye=Vec3(z=40.0), dip=8.0), math.pi / 2.0, 1.0);
    assert abs(placed.gun.z - 38.0) < 0.00001 and placed.eye.z == 40.0;
    # CG_CalculateWeaponPosition idle drift: (xyspeed + 40) * sin(time) / 100.
    assert abs(math.degrees(placed.gun_yaw) - 0.4) < 0.0001;
    assert abs(math.degrees(placed.gun_roll) - 0.4) < 0.0001;
    assert abs(math.degrees(placed.gun_pitch) + 0.4) < 0.0001;
}

test "the view places the eye from the body, or shows the dead view" {
    view = ViewFeedback();
    view.reset("q3");
    player = Player(pos=Vec3(z=100.0), grounded=True);
    placed = view.place(player, Vec3(z=100.0), True, 0.0, 0.0, 1.0, 0.0);
    assert placed.eye.z == 100.0 and placed.gun.z == 100.0;
    view.landing(0.0, 16.0);
    view.advance(0.15);
    dipped = view.place(player, Vec3(z=100.0), True, 0.0, 0.0, 1.0, 0.0);
    assert abs(dipped.eye.z - 84.0) < 0.0001 and abs(dipped.gun.z - 80.0) < 0.0001;
    player.health = 0;
    # Q3 shows its dead from outside (CG_OffsetThirdPersonView): 40 behind
    # the body's eye and 8 above it, looking over it toward the killer.
    killer = Player(pos=Vec3(y=200.0, z=100.0));
    player.killer = killer;
    player.pitch = math.radians(-20.0);
    dead = view.place(player, Vec3(z=100.0), True, 0.0, 0.0, 1.0, 0.0, dead=True);
    assert abs(dead.eye.x) < 0.0001 and abs(dead.eye.y + 40.0) < 0.0001;
    assert abs(dead.eye.z - 108.0) < 0.0001 and dead.roll == 0.0;
    assert abs(math.degrees(dead.yaw) - 90.0) < 0.0001;
    assert abs(math.degrees(dead.pitch) + 0.8303) < 0.001;
    # Q2's dead view is from the eye of the body where it lies, with no dip,
    # rolled over and looking up at the killer.
    lying = ViewFeedback();
    lying.reset("q2");
    down = lying.place(player, Vec3(z=100.0), True, 0.0, 0.0, 1.0, 0.0, dead=True);
    assert down.eye.z == 100.0 and abs(math.degrees(down.roll) - 40.0) < 0.0001;
    assert abs(math.degrees(down.pitch) - 15.0) < 0.0001 and abs(math.degrees(down.yaw) - 90.0) < 0.0001;
    # Q1 rolls the player's own view over.
    q1 = ViewFeedback();
    q1.reset("q1");
    fallen = q1.place(player, Vec3(z=100.0), True, 0.0, 0.0, 1.0, 0.0, dead=True);
    assert abs(math.degrees(fallen.roll) - 80.0) < 0.0001 and fallen.yaw == player.yaw;
    assert abs(math.degrees(fallen.pitch) + 20.0) < 0.0001 and fallen.eye.z == 100.0;
    # Q2's fall kick also lowers the eye by 0.4 of it as it fades.
    q2 = ViewFeedback();
    q2.reset("q2");
    q2.landing(20.0, 0.0);
    assert abs(q2.eye_drop() - 8.0) < 0.00001;
    assert view_sway_for("passion").place(player, ViewBase(eye=Vec3(z=5.0)), 0.0, 1.0).gun.z == 5.0;
}

test "Q3's death camera is CG_OffsetThirdPersonView, worked by hand" {
    # cg_thirdPersonRange 40, cg_thirdPersonAngle 0, FOCUS_DISTANCE 512. A
    # level view: 40 back and 8 up, pitched down by atan(8 / 552).
    level = third_person_view(Vec3(x=10.0, y=20.0, z=100.0), 0.0, 0.0);
    assert level.eye.sub(Vec3(x=-30.0, y=20.0, z=108.0)).length() < 0.0001;
    assert abs(math.degrees(level.pitch) + 0.8303) < 0.001 and level.yaw == 0.0 and level.roll == 0.0;
    side = third_person_view(Vec3(z=100.0), math.pi / 2.0, 0.0);
    assert side.eye.sub(Vec3(y=-40.0, z=108.0)).length() < 0.0001;
    assert abs(math.degrees(side.pitch) + 0.8303) < 0.001;
    # Looking 80 degrees down: the focus pitch stops at 45 ("don't go too
    # far overhead") while the camera swings by half the view's pitch, 40.
    steep = third_person_view(Vec3(z=100.0), 0.0, 80.0);
    assert steep.eye.sub(Vec3(x=-30.6418, z=133.7115)).length() < 0.001;
    assert abs(math.degrees(steep.pitch) + 45.2231) < 0.001;
    # Looking 30 degrees up: the camera drops behind by 15.
    up = third_person_view(Vec3(z=100.0), 0.0, -30.0);
    assert up.eye.sub(Vec3(x=-38.637, z=97.6472)).length() < 0.001;
    assert abs(math.degrees(up.pitch) - 28.1893) < 0.001;
    # A wall 20 behind the eye stops the 8 unit box 16 back, 0.4 of the way;
    # the camera rises 0.6 * 32 from there and is traced again.
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=-100.0, y=-500.0, z=-500.0),
        Vec3(x=-20.0, y=500.0, z=500.0),
        Vec3(),
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0)
    );
    collision.reindex();
    walled = third_person_view(Vec3(z=100.0), 0.0, 0.0, collision);
    assert abs(walled.eye.x + 16.0) < 0.2 and walled.eye.y == 0.0;
    assert abs(walled.eye.z - 122.4) < 0.3 and abs(math.degrees(walled.pitch) + 2.4293) < 0.05;
    # In a tunnel the second trace stops under the ceiling (here 110 up: the
    # box's centre gets to 106, 6 / 22.4 of the way).
    collision.add_box(
        Vec3(x=-500.0, y=-500.0, z=110.0),
        Vec3(x=500.0, y=500.0, z=200.0),
        Vec3(),
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0)
    );
    collision.reindex();
    tunnel = third_person_view(Vec3(z=100.0), 0.0, 0.0, collision);
    assert abs(tunnel.eye.x + 4.2857) < 0.2 and abs(tunnel.eye.z - 106.0) < 0.2;
    # The view carries its collision to the camera.
    q3 = ViewFeedback();
    q3.reset("q3");
    body = Player(pos=Vec3(z=100.0), health=0);
    seen = q3.place(body, Vec3(z=100.0), True, 0.0, 0.0, 1.0, 0.0, dead=True, collision=collision);
    assert seen.eye.sub(tunnel.eye).length() < 0.0001 and seen.pitch == tunnel.pitch;
}

test "an intermission camera has no bob or kick; Q1's sways idly" {
    player = Player(pos=Vec3(z=10.0), velocity=Vec3(x=300.0), grounded=True, yaw=0.5, pitch=0.1);
    q1 = ViewFeedback();
    q1.reset("q1");
    placed = q1.place(player, Vec3(z=10.0), True, 0.0, math.pi / 2.0, 1.0, 2.0, intermission=True);
    assert placed.eye.z == 10.0;
    # V_AddIdle at v_idlescale 1: pitch sin(t) * 0.3, yaw sin(2t) * 0.3, roll sin(t / 2) * 0.1.
    assert abs(placed.pitch - (0.1 - math.radians(0.3))) < 0.00001;
    assert abs(placed.yaw - 0.5) < 0.00001;
    assert abs(placed.roll - math.radians(math.sin(math.pi / 4.0) * 0.1)) < 0.00001;
    q2 = ViewFeedback();
    q2.reset("q2");
    still = q2.place(player, Vec3(z=10.0), True, 0.0, 1.0, 1.0, 2.0, intermission=True);
    assert still.pitch == 0.1 and still.roll == 0.0 and still.eye.z == 10.0;
}

test "a Q2 shot kicks the view back for the server frame it is fired in" {
    player = Player(grounded=True);
    sway = Q2ViewSway();
    for tick in range(12) {
        sway.tick(player, False, TICK);
    }
    sway.recoil(2.0, 0.0, []);
    for tick in range(24) {
        sway.tick(player, False, TICK);
    }
    # The frame fired in is pushed 2 units back along the aim; the next one
    # is not.
    kicked = sway.place(player, ViewBase(eye=Vec3(z=50.0)), 0.0, 1.0);
    assert abs(kicked.eye.x + 2.0) < 0.00001 and abs(kicked.gun.x + 2.0) < 0.00001;
    for tick in range(12) {
        sway.tick(player, False, TICK);
    }
    assert sway.place(player, ViewBase(eye=Vec3(z=50.0)), 0.0, 1.0).eye.x == 0.0;
    # The machinegun shakes and turns it at random instead.
    sway.recoil(0.0, 0.35, [0.0, 0.7, 0.7]);
    for tick in range(24) {
        sway.tick(player, False, TICK);
    }
    shaken = sway.place(player, ViewBase(eye=Vec3(z=50.0)), 0.0, 1.0);
    assert shaken.eye.sub(Vec3(z=50.0)).length() > 0.0;
    assert abs(shaken.eye.x) <= 0.35 and abs(math.degrees(shaken.yaw)) <= 0.7;
    assert abs(math.degrees(shaken.pitch)) < 0.00001;
}
