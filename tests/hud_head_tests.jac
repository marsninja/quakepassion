import from engine.render.hud { HudStatus, StatusHead, HeadPose }

test "the q3 status bar head only kicks for real damage" {
    heads = StatusHead();
    # Spawn health counting down from 125 is no damage event.
    for step in range(30) {
        pose = heads.pose(HudStatus(game="q3", health=125 - step, clock=float(step) * 0.1));
        assert pose.size == 60.0;
        assert pose.shift == 0.0;
    }
}

test "a hit swells the head and kicks it toward the damage" {
    heads = StatusHead();
    heads.pose(HudStatus(game="q3", clock=1.0));
    # A hit from the left (cg.damageX -1) just now: 1.5 times the size, the
    # head turned 45 degrees toward it, the box pushed right by the stretch.
    pose = heads.pose(HudStatus(game="q3", clock=2.0, damage_age=0.0, damage_x=-1.0));
    assert abs(pose.size - 90.0) < 0.001;
    assert abs(pose.shift) < 0.001;
    assert abs(pose.yaw - 135.0) < 0.001;
    # From the right, halfway through DAMAGE_TIME: 1.25 times, shifted left
    # by the whole stretch.
    pose = heads.pose(HudStatus(game="q3", clock=2.25, damage_age=0.25, damage_x=1.0));
    assert abs(pose.size - 75.0) < 0.001;
    assert abs(pose.shift - 15.0) < 0.001;
    # After half a second the head is back to its size.
    pose = heads.pose(HudStatus(game="q3", clock=2.5, damage_age=-1.0));
    assert pose.size == 60.0;
}
