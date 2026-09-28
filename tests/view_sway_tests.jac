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
import from engine.render.view_feedback { ViewFeedback }
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
    placed = view.place(player, Vec3(z=100.0), True, 0.0, 0.0, 1.0, 0.0, 26.0);
    assert placed.eye.z == 100.0 and placed.gun.z == 100.0;
    view.landing(0.0, 16.0);
    view.advance(0.15);
    dipped = view.place(player, Vec3(z=100.0), True, 0.0, 0.0, 1.0, 0.0, 26.0);
    assert abs(dipped.eye.z - 84.0) < 0.0001 and abs(dipped.gun.z - 80.0) < 0.0001;
    player.health = 0;
    dead = view.place(player, Vec3(z=100.0), True, 0.0, 0.0, 1.0, 0.0, 26.0, dead=True);
    assert abs(dead.eye.z - (100.0 - 42.0)) < 0.0001 and abs(math.degrees(dead.roll) - 40.0) < 0.0001;
    # Q2's fall kick also lowers the eye by 0.4 of it as it fades.
    q2 = ViewFeedback();
    q2.reset("q2");
    q2.landing(20.0, 0.0);
    assert abs(q2.eye_drop() - 8.0) < 0.00001;
    assert view_sway_for("passion").place(player, ViewBase(eye=Vec3(z=5.0)), 0.0, 1.0).gun.z == 5.0;
}

test "an intermission camera has no bob or kick; Q1's sways idly" {
    player = Player(pos=Vec3(z=10.0), velocity=Vec3(x=300.0), grounded=True, yaw=0.5, pitch=0.1);
    q1 = ViewFeedback();
    q1.reset("q1");
    placed = q1.place(player, Vec3(z=10.0), True, 0.0, math.pi / 2.0, 1.0, 2.0, 22.0, intermission=True);
    assert placed.eye.z == 10.0;
    # V_AddIdle at v_idlescale 1: pitch sin(t) * 0.3, yaw sin(2t) * 0.3, roll sin(t / 2) * 0.1.
    assert abs(placed.pitch - (0.1 - math.radians(0.3))) < 0.00001;
    assert abs(placed.yaw - 0.5) < 0.00001;
    assert abs(placed.roll - math.radians(math.sin(math.pi / 4.0) * 0.1)) < 0.00001;
    q2 = ViewFeedback();
    q2.reset("q2");
    still = q2.place(player, Vec3(z=10.0), True, 0.0, 1.0, 1.0, 2.0, 22.0, intermission=True);
    assert still.pitch == 0.1 and still.roll == 0.0 and still.eye.z == 10.0;
}
