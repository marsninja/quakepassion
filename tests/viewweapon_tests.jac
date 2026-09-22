import from engine.world.weapons { ViewWeaponRule, view_frame }
import from games.viewweapons { view_weapons }

test "view animation samples firing and idle without advancing simulation" {
    rule = ViewWeaponRule(
        slot=1, model="test", fire_first=2, fire_last=4, idle_first=5, idle_last=7
    );
    assert view_frame(rule, 8, 0.0, 0.0) == 2;
    assert view_frame(rule, 8, 0.15, 0.0) == 3;
    assert view_frame(rule, 8, 0.25, 0.0) == 4;
    assert view_frame(rule, 8, 0.4, 0.1) == 6;
    assert view_frame(rule, 8, -1.0, 0.2) == 7;
    assert view_frame(rule, 8, 0.15, 0.0) == 3;
}

test "view frame range bounds and grenade hold release do not restart priming" {
    rule = view_weapons("q2")[10];
    assert view_frame(rule, 49, 10.0, 0.0, True, 1, 0.5) == 6;
    assert view_frame(rule, 49, 10.0, 0.0, True, 2, 0.0) == 11;
    assert view_frame(rule, 49, 10.0, 0.0, True, 3, 0.0) == 12;
    assert view_frame(rule, 49, 0.2, 0.0, True) == 14;
    assert view_frame(rule, 49, 0.6, 0.0, True) == 16;
    assert view_frame(rule, 1, 0.2, 0.0, True) == 0;
    assert view_frame(ViewWeaponRule(slot=1, model="test", fire_first=1), 6, 0.4, 0.0)
        == 5;
}
