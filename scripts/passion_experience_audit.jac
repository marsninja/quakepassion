"""Survey and check the generated experience, one natural seed per theme.

    jac build scripts/passion_experience_audit.jac --native -o .jac/qp-audit
    .jac/qp-audit
    QP_SEEDS="4 25 84 100" .jac/qp-audit

Writes a JSON record per seed; exits unsuccessfully if a seed cannot be
generated or its quiet, weapon, supply or progression contracts fail.
This is structural validation; normal-mode walkthroughs test actual play.
"""
import os;
import sys;
import json;
import time;
import from games.passion.generate { survey }
import from games.passion.themes { THEMES, theme_for }
import from games.passion.experience { experience_measures, encounters }

with entry {
    seeds: list[int] = [];
    wanted = os.getenv("QP_SEEDS", "");
    if wanted {
        seeds = [int(word) for word in wanted.split()];
    } else {
        for theme in THEMES {
            seed = 1;
            while theme_for(seed).key != theme.key {
                seed += 1;
            }
            seeds.append(seed);
        }
    }
    failed = 0;
    for seed in seeds {
        began = time.time();
        try {
            record = survey(seed);
            casting = record.casting;
            assert casting is not None;
            measures = experience_measures(casting.experience);
            assert not casting.issues;
            assert measures["play_quiet_violations"] == 0.0;
            assert measures["play_weapons"] >= 3.0;
            assert measures["play_weapons"] == float(casting.placed_weapons);
            assert measures["play_ammo_types"] >= 2.0;
            assert measures["play_supplied"] == 1.0;
            assert record.measures.get("play_certified_passages", 0.0) > 0.0;
            assert casting.navigation.samples > 0;
            assert casting.navigation.dark_after <= casting.navigation.dark_before;
            print(
                json.dumps(
                    {
                        "seed": seed,
                        "theme": record.theme,
                        "status": "pass",
                        "rooms": len(encounters(casting.experience)),
                        "foes": casting.monsters,
                        "lead": casting.lead,
                        "weapons": casting.placed_weapons,
                        "ammo": casting.placed_ammo,
                        "measures": record.measures,
                        "rejections": record.rejections,
                        "notes": record.notes,
                        "seconds": time.time() - began
                    }
                )
            );
        } except Exception as error {
            failed += 1;
            print(
                json.dumps(
                    {
                        "seed": seed,
                        "theme": theme_for(seed).key,
                        "status": "fail",
                        "reason": str(error)
                    }
                )
            );
        }
    }
    sys.exit(1 if failed else 0);
}
