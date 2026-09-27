"""The player's body noises and landings: falling damage and the sounds of
jumping, landing, pain, death, water and burning, each game by its own rules."""
import from .world { Player }
import from .damage { Damage }
import from .powerups { empowered }

"""A landing at `speed` units a second (downward). Q1 PlayerPostThink: over
300 plays land.wav (h2ojump.wav into water), over 650 also hurts 5 with
land2.wav. Q2 P_FallingDamage: delta = speed^2 / 10000, cut by water depth;
from 15 the view dips by delta/2 (at most 40), past 30 it hurts (delta-30)/2
with fall2/fall1 (fall1 from 55); 15-30 plays land1.wav. Q3 PM_CrashLand:
past 7 land1.wav, past 40 a 5 point fall (EV_FALL_MEDIUM), past 60 10
(EV_FALL_FAR), doubled when ducked; the view dips 8 or 16 units."""
walker CrashLand {
    has game: str,
        speed: float,
        water_depth: int = 0,
        cue: str = "",
        dealt: int = 0,
        kick: float = 0.0,
        drop: float = 0.0;

    can land with Player entry {
        if here.health <= 0 or self.speed <= 0.0 {
            return;
        }
        amount = 0;
        if self.game == "q1" {
            if self.speed <= 300.0 {
                return;
            }
            if self.water_depth > 0 and here.liquid_kind == 1 {
                self.cue = "sound/player/h2ojump.wav";
                return;
            }
            if self.speed > 650.0 {
                amount = 5;
                self.cue = "sound/player/land2.wav";
            } else {
                self.cue = "sound/player/land.wav";
            }
        } elif self.game == "q2" {
            delta = self.speed * self.speed * 0.0001;
            if self.water_depth >= 3 {
                return;
            }
            if self.water_depth == 2 {
                delta *= 0.25;
            } elif self.water_depth == 1 {
                delta *= 0.5;
            }
            if delta < 15.0 {
                return;
            }
            self.kick = min(40.0, delta * 0.5);
            if delta > 30.0 {
                amount = max(1, int((delta - 30.0) * 0.5));
                self.cue = "sound/player/male/fall1.wav"
                    if delta >= 55.0
                    else "sound/player/male/fall2.wav";
            } else {
                self.cue = "sound/player/land1.wav";
            }
        } elif self.game == "q3" {
            delta = self.speed * self.speed * 0.0001;
            if here.crouched {
                delta *= 2.0;
            }
            if self.water_depth >= 3 {
                return;
            }
            if self.water_depth == 2 {
                delta *= 0.25;
            } elif self.water_depth == 1 {
                delta *= 0.5;
            }
            if delta > 60.0 {
                amount = 10;
                self.drop = 16.0;
                self.cue = "sound/player/sarge/fall1.wav";
            } elif delta > 40.0 {
                amount = 5;
                self.drop = 16.0;
                self.cue = "sound/player/sarge/fall1.wav";
            } elif delta > 7.0 {
                self.drop = 8.0;
                self.cue = "sound/player/land1.wav";
            }
        }
        if amount > 0 {
            result = here spawn Damage(amount=amount, means="fall");
            self.dealt = result.dealt;
        }
    }
}

"""What the body last sounded like; lets the voice notice changes between
ticks (entering water, surfacing, taking damage) whatever caused them."""
edge HasVoice: Player --> Voice {}
node Voice {
    has water_depth: int = 0,
        health: int = 100,
        air_used: float = 0.0,
        pain_wait: float = 0.0,
        burn_wait: float = 0.0,
        dead: bool = False,
        roll: int = 1;

    def pick(count: int) -> int {
        self.roll = (self.roll * 48271) % 2147483647;
        return self.roll % count;
    }
}

def voice_of(player: Player) -> Voice {
    found = [player->:HasVoice:->][?:Voice];
    if found {
        return found[0];
    }
    voice = Voice(water_depth=player.water_depth, health=player.health);
    player +>:HasVoice:+> voice;
    return voice;
}

"""Q3 GIB_HEALTH: a player killed 40 or more past zero bursts."""
def q3_gibbed(body: Player) -> bool {
    return body.health <= 0 and body.death_overkill >= 40;
}

"""Once per tick: Q1 client.qc WaterMove (inh2o/inlava/slimbrn2 on entry,
outwater.wav on leaving, gasp1/gasp2 surfacing), player.qc PainSound (drown
and lava/slime burn sounds, pain1-6 at most twice a second) and DeathSound
(death1-5, h2odeath under water); Q2 p_view.c
P_WorldEffects (watr_in/lava_in, watr_out, watr_un, gasp1/gasp2, burn1/burn2
in lava once a second, gurp while drowning) and P_DamageFeedback's pain
sounds by health (0.7 s apart), with p_client.c death1-4; Q3 only
the water events (EV_WATER_TOUCH/LEAVE/UNDER/CLEAR) and the gib sound. A
body killed past the gib health gibs with its game's sound instead of the
death cry (Q1 GibPlayer, Q2 player_die, Q3 EV_GIB_PLAYER). `jumped` is the pmove
jump this tick (Q1 plyrjmp8.wav, Q2 *jump1.wav)."""
walker VoiceTick {
    has game: str,
        dt: float,
        jumped: bool = False,
        cues: list[str] = [];

    can listen with Player entry {
        voice = voice_of(here);
        voice.pain_wait = max(0.0, voice.pain_wait - self.dt);
        voice.burn_wait = max(0.0, voice.burn_wait - self.dt);
        before = voice.water_depth;
        now = here.water_depth;
        hurt = here.health < voice.health;
        # Seconds the head was under before this tick (air_finished).
        held = voice.air_used;
        voice.air_used = voice.air_used + self.dt if now >= 3 else 0.0;
        if self.game == "q1" {
            self.q1(here, voice, before, now, hurt, held);
        } elif self.game == "q2" {
            self.q2(here, voice, before, now, hurt, held);
        } elif self.game == "q3" {
            if before == 0 and now > 0 {
                self.cues.append("sound/player/watr_in.wav");
            } elif before > 0 and now == 0 {
                self.cues.append("sound/player/watr_out.wav");
            }
            if before < 3 and now >= 3 {
                self.cues.append("sound/player/watr_un.wav");
            }
            # g_combat.c player_die: at GIB_HEALTH the body gibs
            # (EV_GIB_PLAYER's gibSound) instead of its death cry.
            if here.health <= 0 and not voice.dead and q3_gibbed(here) {
                self.cues.append("sound/player/gibsplt1.wav");
            }
        }
        voice.water_depth = now;
        voice.health = here.health;
        voice.dead = here.health <= 0;
    }

    def q1(body: Player, voice: Voice, before: int, now: int, hurt: bool, held: float) {
        if body.health > 0 {
            if self.jumped {
                self.cues.append("sound/player/plyrjmp8.wav");
            }
            if before > 0 and now == 0 {
                self.cues.append("sound/misc/outwater.wav");
            } elif before == 0 and now > 0 {
                splash = {
                    1: "sound/player/inh2o.wav",
                    2: "sound/player/slimbrn2.wav",
                    3: "sound/player/inlava.wav"
                };
                self.cues.append(splash.get(body.liquid_kind, "sound/player/inh2o.wav"));
            }
            # Surfacing: gasp2 after running out of air, gasp1 after holding
            # the breath more than three seconds.
            if before >= 3 and now < 3 {
                if held > 12.0 {
                    self.cues.append("sound/player/gasp2.wav");
                } elif held > 3.0 {
                    self.cues.append("sound/player/gasp1.wav");
                }
            }
        }
        if body.health <= 0 {
            if not voice.dead {
                # player.qc PlayerDie: below -40 health GibPlayer's
                # teledth1 for a telefrag, else gib or udeath at even odds.
                if body.death_overkill > 40 {
                    if body.death_means == "telefrag" {
                        self.cues.append("sound/player/teledth1.wav");
                    } else {
                        self.cues.append(
                            "sound/player/gib.wav" if voice.pick(2) == 0 else "sound/player/udeath.wav"
                        );
                    }
                } elif now >= 3 {
                    self.cues.append("sound/player/h2odeath.wav");
                } else {
                    self.cues.append("sound/player/death" + str(1 + voice.pick(5)) + ".wav");
                }
            }
            return;
        }
        if not hurt {
            return;
        }
        if now >= 3 and body.liquid_kind == 1 {
            self.cues.append("sound/player/drown" + str(1 + voice.pick(2)) + ".wav");
            return;
        }
        if now > 0 and body.liquid_kind in [2, 3] {
            self.cues.append("sound/player/lburn" + str(1 + voice.pick(2)) + ".wav");
            return;
        }
        if voice.pain_wait > 0.0 {
            return;
        }
        voice.pain_wait = 0.5;
        self.cues.append("sound/player/pain" + str(1 + voice.pick(6)) + ".wav");
    }

    def q2(body: Player, voice: Voice, before: int, now: int, hurt: bool, held: float) {
        if body.health > 0 {
            if self.jumped and now == 0 {
                self.cues.append("sound/player/male/jump1.wav");
            }
            if before == 0 and now > 0 {
                self.cues.append(
                    "sound/player/lava_in.wav" if body.liquid_kind == 3 else "sound/player/watr_in.wav"
                );
            } elif before > 0 and now == 0 {
                self.cues.append("sound/player/watr_out.wav");
            }
            if before < 3 and now >= 3 {
                self.cues.append("sound/player/watr_un.wav");
            }
            if before >= 3 and now < 3 {
                if held > 12.0 {
                    self.cues.append("sound/player/gasp1.wav");
                } elif held > 1.0 {
                    self.cues.append("sound/player/gasp2.wav");
                }
            }
            # P_WorldEffects: lava burns sound once a second.
            if now > 0 and body.liquid_kind == 3 and voice.burn_wait <= 0.0 and hurt {
                voice.burn_wait = 1.0;
                voice.pain_wait = 1.0;
                self.cues.append("sound/player/burn" + str(1 + voice.pick(2)) + ".wav");
                return;
            }
        }
        if body.health <= 0 {
            if not voice.dead {
                # p_client.c player_die: below -40 health the body gibs.
                if body.death_overkill > 40 {
                    self.cues.append("sound/misc/udeath.wav");
                } else {
                    self.cues.append("sound/player/male/death" + str(1 + voice.pick(4)) + ".wav");
                }
            }
            return;
        }
        if not hurt {
            return;
        }
        if now >= 3 and held > 12.0 {
            self.cues.append(
                "sound/player/drown1.wav"
                    if body.health <= 10
                    else "sound/player/male/gurp" + str(1 + voice.pick(2)) + ".wav"
            );
            voice.pain_wait = 1.0;
            return;
        }
        if voice.pain_wait > 0.0 or empowered(body, "invulnerability") {
            return;
        }
        voice.pain_wait = 0.7;
        level = 100;
        if body.health < 25 {
            level = 25;
        } elif body.health < 50 {
            level = 50;
        } elif body.health < 75 {
            level = 75;
        }
        self.cues.append(
            "sound/player/male/pain" + str(level) + "_" + str(1 + voice.pick(2)) + ".wav"
        );
    }
}
