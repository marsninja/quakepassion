"""Q3 bots in liquid. Every tick each arena bot's immersion is sampled the
way the player's is (Level.immersion: bg_pmove.c PM_SetWaterLevel over the
bot's own box), giving its movement the water level and current it swims by
and its AI the liquid it is in (BotInLavaOrSlime, BotCheckAir). The liquid
then acts on it as on any client (g_active.c P_WorldEffects): it drowns once
its air runs out, and lava and slime burn it."""
import from .world { World }
import from .level { Level }
import from .combat { Opponent, HasOpponent }
import from .environment { EnvironmentTick }

walker ImmerseBots {
    has level: Level,
        dt: float;

    can begin with World entry {
        visit [here->:HasOpponent:->];
    }

    can immerse with Opponent entry {
        if not here.arena or here.dormant {
            return;
        }
        here.immerse(self.level.immersion(here.pos, here.eye_height));
        here spawn EnvironmentTick(game=self.level.bsp.game, dt=self.dt);
    }
}
