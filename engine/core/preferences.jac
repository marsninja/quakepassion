"""Persistent scalar user preferences, independent of world snapshots."""
import os;
import from .savegame { read_save, write_save, values, numbers }

obj Preferences {
    has fov: float = 72.0,
        sensitivity: float = 0.0022,
        invert_y: bool = False,
        fly_speed: float = 240.0,
        frame_limit: int = 0,
        culling: bool = True,
        overlay: bool = True,
        volume: float = 0.25,
        god_mode: bool = False,
        skill: int = 1;

    def path() -> str {
        return os.getenv("HOME", ".") + "/.quakepassion-settings.txt";
    }

    def load() {
        if not os.path.exists(self.path()) {
            return;
        }
        data = read_save(self.path()).splitlines();
        versions = ["QUAKEPASSION SETTINGS 1", "QUAKEPASSION SETTINGS 2", "QUAKEPASSION SETTINGS 3"];
        if len(data) != 2 or data[0] not in versions {
            raise ValueError("Invalid settings version");
        }
        row = values(data[1], 8 + versions.index(data[0]));
        self.god_mode = len(row) >= 9 and row[8] != 0.0;
        self.skill = max(0, min(3, int(row[9]))) if len(row) >= 10 else 1;
        self.fov = max(40.0, min(110.0, row[0]));
        self.sensitivity = max(0.00022, min(0.011, row[1]));
        self.invert_y = row[2] != 0.0;
        self.fly_speed = max(60.0, min(1920.0, row[3]));
        self.frame_limit = max(0, min(1000, int(row[4])));
        self.culling = row[5] != 0.0;
        self.overlay = row[6] != 0.0;
        self.volume = max(0.0, min(1.0, row[7]));
    }

    def save() {
        write_save(
            self.path(),
            "QUAKEPASSION SETTINGS 3\n"
                + numbers(
                    [
                        self.fov,
                        self.sensitivity,
                        1.0 if self.invert_y else 0.0,
                        self.fly_speed,
                        float(self.frame_limit),
                        1.0 if self.culling else 0.0,
                        1.0 if self.overlay else 0.0,
                        self.volume,
                        1.0 if self.god_mode else 0.0,
                        float(self.skill)
                    ]
                )
                + "\n"
        );
    }
}
