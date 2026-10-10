"""Which sounds reach the player.

Quake II sends a sound only where it could be heard. A sound started on an
entity or at a point (sv_send.c SV_StartSound) goes to clients in the
potentially hearable set of the cluster it starts in, and only across open
area portals (SV_Multicast's MULTICAST_PHS and its CM_AreasConnected test),
unless it does not attenuate (ATTN_NONE) or asks for no PHS
(CHAN_NO_PHS_ADD). Explosions are temp entities multicast to the PHS, shot
impacts to the PVS. A looping sound belongs to its entity and is heard
while that entity is in the client's frame (sv_ents.c SV_BuildClientFrame):
its area connected to the view's, its cluster in the fat PVS of the eye.

Quake III has no PHS. A sound is an event on an entity or a temp entity
(g_utils.c G_AddEvent, G_TempEntity), and loops ride on their entities; all
reach a client only with the entity, which sv_snapshot.c
SV_AddEntitiesVisibleFromPoint sends when its area is connected and its
cluster is in the eye's PVS. Global sounds are broadcast.

Quake sends every sound to every client (WinQuake sv_main.c SV_StartSound
writes sv.datagram); only distance silences it there. QuakeWorld's
SV_CalcPHS belongs to its multiplayer server alone.

`SoundReach` carries the listener to every emitter of the world once a tick
and settles which are heard; the audio layer plays what is left."""
import from .world { World }
import from .level { Level }
import from .speakers { Speaker, HasSpeaker }
import from .particles { Explosion, HasExplosion, ImpactSound, HasImpactSound }
import from .combat { Projectile, HasProjectile }
import from ..math.vec3 { Vec3 }

"""How a game's server decides who gets each kind of sound: a sound
started on an entity or at a point, an entity's loop, an explosion and a
shot's impact. "phs" and "pvs" multicast it from where it starts to the
clients in that cluster's potentially hearable or visible set; "frame"
sends it with its entity, when that is in the client's frame; "" sends it
to everyone. `fat` is SV_FatPVS's reach around the eye."""
obj HearingRule {
    has started: str = "",
        loops: str = "",
        blasts: str = "",
        impacts: str = "",
        fat: float = 0.0;
}

glob HEARING_RULES: dict[str, HearingRule] = {
    "q2": HearingRule(started="phs", loops="frame", blasts="phs", impacts="pvs", fat=8.0),
    "q3": HearingRule(started="frame", loops="frame", blasts="frame", impacts="frame")
};

"""The game's rule, or None when it sends every sound to everyone."""
def hearing_rule(game: str) -> HearingRule | None {
    return HEARING_RULES.get(game, None);
}

walker SoundReach {
    has level: Level,
        rule: HearingRule,
        # The client's origin (SV_Multicast tests the player entity's leaf)
        # and its eye (frames are built from the view point).
        origin: Vec3,
        eye: Vec3,
        # Missiles out of the frame: their flight loops are not heard.
        silenced: list[Projectile] = [],
        origin_cluster: int = -1,
        origin_area: int = 0,
        eye_area: int = 0,
        eye_clusters: list[int] = [];

    can begin with World entry {
        bsp = self.level.bsp;
        feet = bsp.leaves[self.level.locate(self.origin)];
        self.origin_cluster = feet.cluster;
        self.origin_area = feet.area;
        self.eye_area = bsp.leaves[self.level.locate(self.eye)].area;
        self.eye_clusters = self.level.view_clusters(self.eye, self.rule.fat);
        visit [here->:HasSpeaker:->];
        visit [here->:HasExplosion:->];
        visit [here->:HasImpactSound:->];
        visit [here->:HasProjectile:->];
    }

    """Whether the listener gets a sound from `leaf` under the rule `how`."""
    def hears(leaf: int, how: str) -> bool {
        if not how {
            return True;
        }
        return self.framed(leaf) if how == "frame" else self.sent(leaf, how);
    }

    """SV_Multicast: a sound started in `leaf` goes across connected areas
    to the clients in the PHS or PVS of its cluster."""
    def sent(leaf: int, how: str) -> bool {
        # A listener in solid (flying through walls) is in no cluster;
        # nothing is withheld from it.
        if self.origin_cluster < 0 {
            return True;
        }
        source = self.level.bsp.leaves[leaf];
        chart = self.level.area_map;
        if chart is not None and not chart.connected(source.area, self.origin_area) {
            return False;
        }
        return self.level.cluster_reaches(source.cluster, self.origin_cluster, how == "phs");
    }

    """SV_BuildClientFrame and SV_AddEntitiesVisibleFromPoint: an entity in
    `leaf` is in the listener's frame when its area is connected to the
    eye's and its cluster is in the eye's (fat) PVS."""
    def framed(leaf: int) -> bool {
        if not self.eye_clusters or max(self.eye_clusters) < 0 {
            return True;
        }
        source = self.level.bsp.leaves[leaf];
        chart = self.level.area_map;
        if chart is not None and not chart.connected(self.eye_area, source.area) {
            return False;
        }
        for cluster in self.eye_clusters {
            if self.level.cluster_reaches(cluster, source.cluster) {
                return True;
            }
        }
        return False;
    }

    can speaker with Speaker entry {
        # Q3's global and activator speakers are broadcast or the player's own.
        if here.global_sound or here.activator_sound {
            here.audible = True;
            return;
        }
        if not here.looping and here.requests == 0 {
            return;
        }
        if here.leaf < 0 or here.origin.sub(here.leaf_origin).length() > 0.0 {
            here.leaf = self.level.locate(here.origin);
            here.leaf_origin = here.origin.add(Vec3());
        }
        if here.looping {
            # The loop, and what a Q3 speaker plays over it by itself
            # (CG_Speaker), need the entity in the frame.
            here.audible = self.hears(here.leaf, self.rule.loops);
            if not here.audible {
                here.requests = 0;
            }
            return;
        }
        # ATTN_NONE and CHAN_NO_PHS_ADD sounds go to everyone.
        if here.attenuation > 0.0 and not here.no_phs and not self.hears(here.leaf, self.rule.started) {
            here.requests = 0;
        }
    }

    can blast with Explosion entry {
        if not here.heard and not self.hears(self.level.locate(here.pos), self.rule.blasts) {
            here.heard = True;
        }
    }

    can impact with ImpactSound entry {
        if not here.heard and not self.hears(self.level.locate(here.pos), self.rule.impacts) {
            here.heard = True;
        }
    }

    can missile with Projectile entry {
        if not self.hears(self.level.locate(here.pos), self.rule.loops) {
            self.silenced.append(here);
        }
    }
}
