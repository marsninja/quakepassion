"""The dynamic lights of one frame, as each game's client makes them.

Q1 (cl_main.c CL_RelinkEntities, cl_tent.c CL_ParseTEnt) lights are white:
EF_MUZZLEFLASH (200 + rand&31, minlight 32, a tenth of a second), EF_ROCKET
models in flight (200), EF_DIMLIGHT on the enforcer's laser and on a player
holding the quad or pentagram (200 + rand&31), and TE_EXPLOSION (350,
shrinking 300 a second, half a second). Q2 (cl_fx.c CL_ParseMuzzleFlash and
CL_ParseMuzzleFlash2, cl_ents.c CL_AddPacketEntities, cl_tent.c
CL_AddExplosions) lights are coloured: muzzle flashes by weapon, EF_ROCKET,
EF_BLASTER and EF_HYPERBLASTER yellow, EF_BFG green (with bfg_lightramp as it
bursts), explosions 350 times their fading alpha. Q3 (cg_weapons.c) has the
weapon's flash colour at 300 + rand&31, the rocket's 200 in flight, 300 for
rocket and grenade explosions held for half their life then fading, and the
quad's blue 200 + rand&31 (cg_players.c CG_PlayerPowerups).

The world and model shaders hold eight lights, so the eight nearest the
viewer are kept. Radii that the originals jitter with rand()&31 take a
cosmetic roll from the light's position, never gameplay random numbers."""
import math;
import from .lighting { Lighting, FlashLight }
import from .world { World, Player }
import from .combat {
    Opponent,
    HasOpponent,
    CombatState,
    Projectile,
    HasProjectile,
    muzzle_flash_age,
    selected_weapon
}
import from .particles { Explosion, HasExplosion, impact_roll }
import from .models { PlayerRig, WeaponKit, Holds, RIG_FLASH_TIME }
import from .powerups { Empowered, Powerup }
import from ..math.vec3 { Vec3, forward_from, right_from }
import from ..math.interpolation { TickBlend }

# The lights the world and model shaders hold at once.
glob DYNAMIC_LIGHT_LIMIT: int = 8;

glob LIGHT_WHITE: Vec3 = Vec3(x=1.0, y=1.0, z=1.0);

"""rand()&31, as a cosmetic roll from where the light is."""
def light_jitter(origin: Vec3, salt: float = 0.0) -> float {
    return float(int(impact_roll(origin, 11.0 + salt) * 32.0));
}

"""The light a missile carries in flight, or None: Q1 EF_ROCKET models
(missile.mdl, lavaball.mdl) and the enforcer laser's EF_DIMLIGHT; Q2
EF_ROCKET, EF_BLASTER and EF_HYPERBLASTER, and EF_BFG (bfg_lightramp over
its burst, a frame a tenth of a second); Q3 missileDlight (the rocket).
`origin` is where the frame draws the missile."""
def missile_light(projectile: Projectile, origin: Vec3) -> FlashLight | None {
    effect = projectile.effect;
    if effect in ["q1_rocket", "q1_lavaball"] and projectile.phase == 0 {
        return FlashLight(origin=origin, color=LIGHT_WHITE, radius=200.0);
    }
    if effect == "q1_laser" and projectile.phase == 0 {
        return FlashLight(origin=origin, color=LIGHT_WHITE, radius=200.0 + light_jitter(origin));
    }
    if effect in ["q2_rocket", "q2_bolt", "q2_hyperbolt"] and projectile.phase == 0 {
        return FlashLight(origin=origin, color=Vec3(x=1.0, y=1.0), radius=200.0);
    }
    if effect == "q2_bfg" {
        if projectile.phase == 0 {
            return FlashLight(origin=origin, color=Vec3(y=1.0), radius=200.0);
        }
        ramp = [300.0, 400.0, 600.0, 300.0, 150.0, 75.0];
        frame = int(max(0.0, 0.5 - projectile.remaining) * 10.0);
        return FlashLight(origin=origin, color=Vec3(y=1.0), radius=ramp[min(frame, len(ramp) - 1)]);
    }
    if effect == "q3_rocket" and projectile.phase == 0 {
        return FlashLight(origin=origin, color=Vec3(x=1.0, y=0.75), radius=200.0);
    }
    return None;
}

"""An explosion's light at its age, or None: Q1 TE_EXPLOSION's dlight (350,
decaying 300 a second, gone at half a second); Q2 CL_AddExplosions (its
light times the explosion's alpha, (16 - frame) / 16 a tenth of a second at
a time); Q3 CG_AddExplosion (full for the first half of its life, then
fading)."""
def explosion_light(blast: Explosion, game: str) -> FlashLight | None {
    if blast.light_radius <= 0.0 {
        return None;
    }
    age = max(0.0, blast.age);
    radius = blast.light_radius;
    if game == "q1" {
        radius = blast.light_radius - 300.0 * age;
        if age > 0.5 {
            return None;
        }
        return FlashLight(origin=blast.pos, color=LIGHT_WHITE, radius=radius) if radius > 0.0 else None;
    }
    if game == "q2" {
        frame = float(int(age * 10.0));
        radius = blast.light_radius * (16.0 - frame) / 16.0;
    } elif game == "q3" {
        share = age / max(0.001, blast.lifetime);
        radius = blast.light_radius * (1.0 if share < 0.5 else max(0.0, 1.0 - (share - 0.5) * 2.0));
    } else {
        fade = max(0.0, 1.0 - age / max(0.001, blast.lifetime));
        return FlashLight(origin=blast.pos, color=blast.light.scale(fade), radius=blast.light_radius * (0.5 + 0.5 * fade));
    }
    return FlashLight(origin=blast.pos, color=blast.light, radius=radius) if radius > 0.0 else None;
}

"""The player's muzzle flash while it shows: Q1 EF_MUZZLEFLASH from 16 up and
18 ahead of the origin; Q2 CL_ParseMuzzleFlash 18 ahead and 16 right, in its
weapon's colour (the chaingun's by how many rounds this frame fired); Q3 the
weapon's flashDlightColor at the flash."""
def player_flash(player: Player, state: CombatState, at: Vec3) -> FlashLight | None {
    if state.flash <= 0.0 {
        return None;
    }
    game = state.game;
    forward = forward_from(player.yaw, 0.0);
    weapon = selected_weapon(state).key;
    if game == "q1" {
        # The view is 22 above the origin (view_ofs); the flash 16 above it.
        origin = at.sub(Vec3(z=6.0)).add(forward.scale(18.0));
        return FlashLight(origin=origin, color=LIGHT_WHITE, radius=200.0 + light_jitter(origin), minlight=32.0);
    }
    if game == "q2" {
        origin = at.sub(Vec3(z=22.0)).add(forward.scale(18.0)).add(right_from(player.yaw).scale(16.0));
        color = Vec3(x=1.0, y=1.0);
        radius = 200.0;
        if weapon == "chaingun" {
            rounds = 1 if state.spin <= 5 else (2 if state.spin <= 10 else 3);
            color = [Vec3(x=1.0, y=0.25), Vec3(x=1.0, y=0.5), Vec3(x=1.0, y=1.0)][rounds - 1];
            radius = [200.0, 225.0, 250.0][rounds - 1];
        } elif weapon == "railgun" {
            color = Vec3(x=0.5, y=0.5, z=1.0);
        } elif weapon == "rocketlauncher" {
            color = Vec3(x=1.0, y=0.5, z=0.2);
        } elif weapon in ["grenadelauncher", "handgrenade"] {
            color = Vec3(x=1.0, y=0.5);
        } elif weapon == "bfg" {
            color = Vec3(y=1.0);
        }
        return FlashLight(origin=origin, color=color, radius=radius + light_jitter(origin), minlight=32.0);
    }
    if game == "q3" {
        colors = {
            "gauntlet": Vec3(x=0.6, y=0.6, z=1.0),
            "lightning": Vec3(x=0.6, y=0.6, z=1.0),
            "machinegun": Vec3(x=1.0, y=1.0),
            "shotgun": Vec3(x=1.0, y=1.0),
            "grenadelauncher": Vec3(x=1.0, y=0.7),
            "rocketlauncher": Vec3(x=1.0, y=0.75),
            "plasmagun": Vec3(x=0.6, y=0.6, z=1.0),
            "railgun": Vec3(x=1.0, y=0.5),
            "bfg": Vec3(x=1.0, y=0.7, z=1.0)
        };
        origin = at.add(forward_from(player.yaw, player.pitch).scale(18.0));
        return FlashLight(origin=origin, color=colors.get(weapon, LIGHT_WHITE), radius=300.0 + light_jitter(origin));
    }
    # Passion: a warm flash ahead of the eye.
    return FlashLight(
        origin=at.add(forward_from(player.yaw, player.pitch).scale(18.0)),
        color=Vec3(x=1.0, y=0.65, z=0.25).scale(min(1.0, state.flash / 0.04))
    );
}

"""A monster's or bot's muzzle flash while it shows: Q1 EF_MUZZLEFLASH
(white), Q2 CL_ParseMuzzleFlash2 (the flash's colour), both 200 + rand&31
with minlight 32; a Q3 bot's weapon flash as the player's."""
def opponent_flash(enemy: Opponent, game: str, blend: TickBlend) -> FlashLight | None {
    rig = enemy.visual;
    if isinstance(rig, PlayerRig) {
        if rig.clock - rig.flash_time >= RIG_FLASH_TIME * 2.0 {
            return None;
        }
        kits = [rig->:Holds:->][?:WeaponKit];
        at = blend.place(enemy.tick_pose, enemy.pos);
        origin = at.add(forward_from(enemy.yaw, enemy.pitch).scale(20.0));
        return FlashLight(
            origin=origin,
            color=kits[0].light if kits else Vec3(x=1.0, y=1.0),
            radius=300.0 + light_jitter(origin)
        );
    }
    if muzzle_flash_age(enemy) < 0.0 {
        return None;
    }
    origin = enemy.flash_origin;
    if game == "q1" {
        return FlashLight(origin=origin, color=LIGHT_WHITE, radius=200.0 + light_jitter(origin), minlight=32.0);
    }
    return FlashLight(origin=origin, color=enemy.flash_color, radius=200.0 + light_jitter(origin), minlight=32.0);
}

"""A powered-up actor's own light: Q1 CheckPowerups gives the quad and the
pentagram EF_DIMLIGHT (at the origin, 200 + rand&31); Q3 the quad a blue
200 + rand&31."""
def powerup_light(actor: Player, game: str, eye: float, at: Vec3) -> FlashLight | None {
    powers = [power.kind for power in [actor->:Empowered:->][?:Powerup] if power.remaining > 0.0];
    origin = at.sub(Vec3(z=eye));
    if game == "q1" and ("quad" in powers or "invulnerability" in powers) {
        return FlashLight(origin=origin, color=LIGHT_WHITE, radius=200.0 + light_jitter(origin, 5.0));
    }
    if game == "q3" and "quad" in powers {
        return FlashLight(origin=origin, color=Vec3(x=0.2, y=0.2, z=1.0), radius=200.0 + light_jitter(origin, 5.0));
    }
    return None;
}

"""This frame's dynamic lights, on lit bodies where the frame draws them
(`blend` of the way through the last physics tick)."""
def combat_lights(
    lighting: Lighting, world: World, player: Player, state: CombatState, blend: TickBlend = TickBlend()
) {
    game = state.game;
    lights: list[FlashLight] = [];
    viewer = blend.place(player.tick_pose, player.pos);
    flash = player_flash(player, state, viewer);
    if flash is not None {
        lights.append(flash);
    }
    glow = powerup_light(player, game, 26.0 if game == "q3" else 22.0, viewer);
    if glow is not None and player.health > 0 {
        lights.append(glow);
    }
    for blast in [world->:HasExplosion:->][?:Explosion] {
        light = explosion_light(blast, game);
        if light is not None {
            lights.append(light);
        }
    }
    for projectile in [world->:HasProjectile:->][?:Projectile] {
        light = missile_light(projectile, blend.place(projectile.tick_pose, projectile.pos));
        if light is not None {
            lights.append(light);
        }
    }
    for enemy in [world->:HasOpponent:->][?:Opponent] {
        if enemy.health <= 0 {
            continue;
        }
        light = opponent_flash(enemy, game, blend);
        if light is not None {
            lights.append(light);
        }
        if isinstance(enemy.visual, PlayerRig) {
            glow = powerup_light(enemy, game, enemy.eye_height, blend.place(enemy.tick_pose, enemy.pos));
            if glow is not None {
                lights.append(glow);
            }
        }
    }
    # The shaders hold eight: keep the nearest the viewer.
    if len(lights) > DYNAMIC_LIGHT_LIMIT {
        order = sorted([(lights[i].origin.sub(viewer).length() - lights[i].radius, i) for i in range(len(lights))]);
        lights = [lights[ranked[1]] for ranked in order[:DYNAMIC_LIGHT_LIMIT]];
    }
    # With no lights, keep the same empty list: models keep the light they
    # were given (Lighting.light_model holds it while the lights stand).
    if lights or lighting.dynamic {
        lighting.set_dynamic(lights);
    }
}
