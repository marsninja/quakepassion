"""Which sounds reach the player: Q2's PHS and area test for started sounds
(SV_StartSound, SV_Multicast), the frame test for looping ones
(SV_BuildClientFrame's fat PVS), Q3's PVS for everything, and Quake's
sending every sound to everyone."""
import struct;
import from engine.world.hearing { SoundReach, HearingRule, hearing_rule }
import from engine.world.level { Level, Split, BspArea, Front, Back }
import from engine.world.area_portals { AreaPortalTick, chart_areas, load_area_portals, HasAreaPortal }
import from engine.world.map_areas { AreaPortal }
import from engine.world.speakers { Speaker, HasSpeaker }
import from engine.world.particles { Explosion, HasExplosion, ImpactSound, HasImpactSound }
import from engine.world.combat { Projectile, HasProjectile }
import from engine.world.signals { Fire }
import from engine.world.world { World }
import from engine.formats.bsp { Bsp, MapEntity, AreaLink, Leaf, Model }
import from engine.math.aabb { AABB }
import from engine.math.vec3 { Vec3 }

"""Three leaves in a row along x, one cluster each: leaf 0 is x > 0, leaf 1
between -64 and 0, leaf 2 beyond -64. `areas` gives each leaf's area."""
def row_level(world: World, game: str, visibility: bytes, areas: list[int]) -> Level {
    nodes: list[BspArea] = [];
    leaves: list[Leaf] = [];
    for index in range(3) {
        leaf_node = BspArea(name=str(index), index=index, faces=[10 + index], bounds=AABB(mins=Vec3(), maxs=Vec3()));
        world ++> leaf_node;
        nodes.append(leaf_node);
        leaves.append(
            Leaf(contents=0, vis_offset=-1, cluster=index, area=areas[index], mins=Vec3(), maxs=Vec3())
        );
    }
    near = Split(normal=Vec3(x=1.0), distance=0.0);
    far = Split(normal=Vec3(x=1.0), distance=-64.0);
    near +>:Front:+> nodes[0];
    near +>:Back:+> far;
    far +>:Front:+> nodes[1];
    far +>:Back:+> nodes[2];
    bsp = Bsp(
        game=game,
        clusters=3,
        cluster_bytes=1,
        visibility=visibility,
        leaves=leaves,
        models=[Model(head=0, first_face=0, face_count=3)]
    );
    return Level(active=True, bsp=bsp, areas=nodes, splits=[near, far]);
}

"""A Q2 visibility lump of three clusters: each cluster's PVS and PHS row
as one byte of bits."""
def q2_vis(pvs: list[int], phs: list[int]) -> bytes {
    data = struct.pack("<i", 3);
    for cluster in range(3) {
        data += struct.pack("<ii", 28 + cluster, 31 + cluster);
    }
    return data + bytes(pvs) + bytes(phs);
}

"""The listener at `eye`, 22 units above its origin."""
def reach(world: World, level: Level, eye: Vec3) -> SoundReach {
    rule = hearing_rule(level.bsp.game);
    assert rule is not None;
    return world spawn SoundReach(level=level, rule=rule, origin=eye.sub(Vec3(z=22.0)), eye=eye);
}

def speaker_at(world: World, x: float, looping: bool = False) -> Speaker {
    speaker = Speaker(path="sound/test.wav", origin=Vec3(x=x), looping=looping, playing=looping);
    world +>:HasSpeaker:+> speaker;
    return speaker;
}

test "CM_ClusterPVS and CM_ClusterPHS rows answer one cluster at a time" {
    world = World();
    level = row_level(world, "q2", q2_vis([3, 7, 6], [3, 7, 6]), [1, 1, 1]);
    assert level.cluster_reaches(0, 1) and not level.cluster_reaches(0, 2);
    assert level.cluster_reaches(2, 1) and not level.cluster_reaches(2, 0);
    assert level.cluster_reaches(1, 2, True);
    assert not level.cluster_reaches(-1, 0) and not level.cluster_reaches(0, -1);
    # CM_DecompressVis: a zero byte and its count stand for that many empty bytes.
    level.bsp.clusters = 20;
    level.bsp.visibility = struct.pack("<i", 20) + struct.pack("<ii", 12, 12) + bytes([0, 2, 0x08]);
    assert level.cluster_reaches(0, 19) and not level.cluster_reaches(0, 18) and not level.cluster_reaches(0, 3);
    # Q3: rows of cluster_bytes bytes after the two counts.
    arena = row_level(World(), "q3", struct.pack("<ii", 3, 1) + bytes([3, 7, 6]), [0, 0, 0]);
    assert arena.cluster_reaches(0, 1) and not arena.cluster_reaches(0, 2) and arena.cluster_reaches(2, 2);
    # An unvised map hears and sees everything.
    arena.bsp.clusters = 0;
    assert arena.cluster_reaches(0, 2);
    # SV_FatPVS: the leaves within eight units of the eye.
    assert level.view_clusters(Vec3(x=32.0), 8.0) == [0];
    assert sorted(level.view_clusters(Vec3(x=4.0), 8.0)) == [0, 1];
    assert level.view_clusters(Vec3(x=4.0)) == [0];
}

test "Q2 sends a started sound to its PHS and a loop with its entity's frame" {
    world = World();
    # From cluster 0: 1 is seen, 2 is not. Cluster 2's sounds carry to 1 only.
    level = row_level(world, "q2", q2_vis([3, 7, 6], [7, 7, 6]), [1, 1, 1]);
    eye = Vec3(x=32.0, z=22.0);
    near = speaker_at(world, -32.0);
    far = speaker_at(world, -96.0);
    near.requests = 1;
    far.requests = 2;
    reach(world, level, eye);
    assert near.requests == 1 and far.requests == 0;
    # ATTN_NONE and CHAN_NO_PHS_ADD sounds go to everyone.
    far.requests = 1;
    far.attenuation = 0.0;
    reach(world, level, eye);
    assert far.requests == 1;
    far.attenuation = 3.0;
    far.no_phs = True;
    reach(world, level, eye);
    assert far.requests == 1;
    # A loop is heard while its entity is in the frame: the eye's fat PVS.
    hum = speaker_at(world, -32.0, True);
    drone = speaker_at(world, -96.0, True);
    reach(world, level, eye);
    assert hum.audible and not drone.audible;
    # Within eight units of the next leaf, its PVS counts too (SV_FatPVS).
    reach(world, level, Vec3(x=4.0, z=22.0));
    assert drone.audible;
    # Explosions are multicast to the PHS, impacts to the PVS; a missile's
    # flight loop rides on the missile.
    blast = Explosion(pos=Vec3(x=-96.0), kind="rocket", sound="sound/boom.wav");
    heard_blast = Explosion(pos=Vec3(x=-32.0), kind="rocket", sound="sound/boom.wav");
    struck = ImpactSound(pos=Vec3(x=-96.0), sound="sound/ric.wav");
    world +>:HasExplosion:+> blast;
    world +>:HasExplosion:+> heard_blast;
    world +>:HasImpactSound:+> struck;
    rocket = Projectile(pos=Vec3(x=-96.0), velocity=Vec3(), damage=1);
    close = Projectile(pos=Vec3(x=-32.0), velocity=Vec3(), damage=1);
    world +>:HasProjectile:+> rocket;
    world +>:HasProjectile:+> close;
    judged = reach(world, level, eye);
    assert blast.heard and struck.heard and not heard_blast.heard;
    assert len(judged.silenced) == 1 and judged.silenced[0] is rocket;
}

test "SV_Multicast sends a sound only across connected areas" {
    world = World();
    level = row_level(world, "q2", q2_vis([7, 7, 7], [7, 7, 7]), [1, 1, 2]);
    level.bsp.areas = [[], [AreaLink(portal=1, area=2)], [AreaLink(portal=1, area=1)]];
    level.bsp.entities = [MapEntity(fields={"classname": "func_areaportal", "targetname": "gate", "style": "1"})];
    chart = chart_areas(world, level.bsp, level.areas);
    load_area_portals(world, level.bsp, chart);
    level.area_map = chart;
    eye = Vec3(x=32.0, z=22.0);
    far = speaker_at(world, -96.0);
    drone = speaker_at(world, -96.0, True);
    far.requests = 1;
    reach(world, level, eye);
    assert far.requests == 0 and not drone.audible;
    # Use_Areaportal opens it: the same sound now carries.
    gate = [world->:HasAreaPortal:->][?:AreaPortal][0];
    gate.activation spawn Fire(emit=False);
    world spawn AreaPortalTick();
    far.requests = 1;
    reach(world, level, eye);
    assert far.requests == 1 and drone.audible;
}

test "Q3 sends sounds with their entities: the eye's PVS, no PHS" {
    world = World();
    level = row_level(world, "q3", struct.pack("<ii", 3, 1) + bytes([3, 7, 6]), [0, 0, 0]);
    eye = Vec3(x=32.0, z=26.0);
    near = speaker_at(world, -32.0);
    far = speaker_at(world, -96.0);
    announcer = speaker_at(world, -96.0);
    announcer.global_sound = True;
    near.requests = 1;
    far.requests = 1;
    announcer.requests = 1;
    blast = Explosion(pos=Vec3(x=-96.0), kind="rocket", sound="sound/boom.wav");
    world +>:HasExplosion:+> blast;
    reach(world, level, eye);
    # EV_GENERAL_SOUND rides on an entity outside the PVS; EV_GLOBAL_SOUND
    # is broadcast.
    assert near.requests == 1 and far.requests == 0 and announcer.requests == 1;
    assert blast.heard;
    # No fat PVS: the eye's own cluster decides.
    drone = speaker_at(world, -96.0, True);
    reach(world, level, Vec3(x=4.0, z=26.0));
    assert not drone.audible;
    reach(world, level, Vec3(x=-4.0, z=26.0));
    assert drone.audible;
}

test "Quake sends every sound to everyone" {
    assert hearing_rule("q1") is None and hearing_rule("passion") is None;
    q2 = hearing_rule("q2");
    q3 = hearing_rule("q3");
    assert q2 is not None and q2.started == "phs" and q2.loops == "frame" and q2.fat == 8.0;
    assert q2.blasts == "phs" and q2.impacts == "pvs";
    assert q3 is not None and q3.started == "frame" and q3.blasts == "frame" and q3.fat == 0.0;
}
