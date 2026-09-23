import math;
import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, Projectile, HasProjectile }
import from engine.world.turrets {
    Turret,
    HasTurret,
    Mans,
    TurretTick,
    link_turret_drivers,
    snap_eighths
}
import from engine.formats.bsp { Bsp }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "a manned Q2 turret swings toward the player and fires after its reaction time" {
    rule = enemy_rule("q2", "turret_driver");
    assert rule is not None and rule.movement == "none" and rule.passive;
    world = World();
    bsp = Bsp();
    collision = CollisionMap();
    breach = Turret(pivot=Vec3(z=100.0), muzzle=Vec3(x=120.0), driver_spawn=Vec3(x=-40.0, z=96.0));
    world +>:HasTurret:+> breach;
    driver = Opponent(
        rule=rule, kind="turret_driver", game="q2", skill=1, health=100,
        home=Vec3(x=-40.0, z=118.0), pos=Vec3(x=-40.0, z=118.0)
    );
    world +>:HasOpponent:+> driver;
    assert link_turret_drivers(world) == [driver];
    seat = [edge driver->:Mans:->][0];
    assert seat.distance == 40.0 and seat.bearing == 180.0 and seat.height == -4.0;
    # The player stands ahead and to the gun's left, level with it.
    player = Player(health=100, pos=Vec3(x=300.0, y=300.0, z=100.0));
    for i in range(5) {
        world spawn TurretTick(bsp=bsp, collision=collision, player=player, dt=0.1);
    }
    # 50 degrees a second toward a yaw of 45.
    assert abs(breach.yaw - 25.0) < 0.001;
    assert abs(breach.aim_yaw - 45.0) < 0.001;
    # The driver rides behind the gun, snapped to eighths.
    behind = math.radians(breach.yaw + 180.0);
    assert driver.pos.x == snap_eighths(40.0 * math.cos(behind));
    assert driver.pos.y == snap_eighths(40.0 * math.sin(behind));
    assert abs(driver.yaw - math.radians(25.0)) < 0.001;
    for i in range(5) {
        world spawn TurretTick(bsp=bsp, collision=collision, player=player, dt=0.1);
    }
    assert abs(breach.yaw - 45.0) < 0.001;
    assert not [world->:HasProjectile:->];
    # Medium skill waits two seconds after spotting before the first rocket.
    for i in range(11) {
        world spawn TurretTick(bsp=bsp, collision=collision, player=player, dt=0.1);
    }
    rockets = [world->:HasProjectile:->][?:Projectile];
    assert len(rockets) == 1;
    rocket = rockets[0];
    assert rocket.effect == "q2_rocket" and rocket.owner is driver and rocket.radius == 150.0;
    assert rocket.damage >= 100 and rocket.damage < 150 and rocket.splash == rocket.damage;
    assert abs(rocket.velocity.length() - 600.0) < 0.01;
}

test "a Q2 turret clamps its pitch and levels off when its driver dies" {
    rule = enemy_rule("q2", "turret_driver");
    assert rule is not None;
    world = World();
    bsp = Bsp();
    collision = CollisionMap();
    breach = Turret(pivot=Vec3(z=100.0), driver_spawn=Vec3(x=-40.0, z=96.0));
    world +>:HasTurret:+> breach;
    driver = Opponent(rule=rule, kind="turret_driver", game="q2", skill=2, health=100, home=Vec3(x=-40.0, z=118.0), pos=Vec3(x=-40.0, z=118.0));
    world +>:HasOpponent:+> driver;
    link_turret_drivers(world);
    # Far below the gun: it may only tilt 30 degrees down.
    player = Player(health=100, pos=Vec3(x=300.0, z=-400.0));
    for i in range(20) {
        world spawn TurretTick(bsp=bsp, collision=collision, player=player, dt=0.1);
    }
    assert abs(breach.pitch - 30.0) < 0.001;
    # Tilting the gun down lifts its back end and the driver with it.
    assert driver.pos.z == snap_eighths(96.0 + 40.0 * math.tan(math.radians(30.0))) + 22.0;
    driver.health = 0;
    for i in range(10) {
        world spawn TurretTick(bsp=bsp, collision=collision, player=player, dt=0.1);
    }
    assert not [edge driver->:Mans:->];
    assert abs(breach.pitch - 0.0) < 0.001 or breach.pitch > 359.999;
}
