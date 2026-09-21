"""Visited-map snapshots and a data-only campaign save envelope."""
edge Visited: Campaign --> MapState {}
node Campaign {
    has active: str = "";
}
node MapState {
    has name: str, data: str;
}
walker Remember {
    has name: str, data: str, found: bool = False;
    can update with MapState entry {
        if here.name == self.name { here.data = self.data; self.found = True; }
    }
    can start with Campaign entry { visit [here->:Visited:->]; }
    can finish with Campaign exit {
        if not self.found { here +>:Visited:+> MapState(name=self.name, data=self.data); }
    }
}
walker Recall {
    has name: str, data: str = "";
    can start with Campaign entry { visit [here->:Visited:->]; }
    can read with MapState entry { if here.name == self.name { self.data = here.data; } }
}

def pack_campaign(campaign: Campaign, active: str) -> str {
    lines = ["QUAKEPASSION CAMPAIGN 1"];
    current = active.splitlines();
    lines.append(str(len(current)));
    lines.extend(current);
    maps = [campaign->:Visited:->][?:MapState];
    lines.append(str(len(maps)));
    for map in maps {
        rows = map.data.splitlines();
        lines.append(map.name);
        lines.append(str(len(rows)));
        lines.extend(rows);
    }
    return "\n".join(lines) + "\n";
}

def unpack_campaign(data: str) -> Campaign {
    campaign = Campaign();
    rows = data.splitlines();
    if not rows or rows[0] != "QUAKEPASSION CAMPAIGN 1" {
        campaign.active = data;
        return campaign;
    }
    if len(rows) < 3 { raise ValueError("Incomplete campaign save"); }
    count = int(rows[1]);
    if count < 4 or count > len(rows) - 3 { raise ValueError("Invalid active snapshot size"); }
    campaign.active = "\n".join(rows[2:2 + count]) + "\n";
    cursor = 2 + count;
    maps = int(rows[cursor]);
    cursor += 1;
    if maps < 0 or maps > 1024 { raise ValueError("Invalid visited map count"); }
    names: list[str] = [];
    for i in range(maps) {
        if cursor + 2 > len(rows) { raise ValueError("Incomplete visited map"); }
        name = rows[cursor];
        count = int(rows[cursor + 1]);
        cursor += 2;
        if not name or name in names or count < 4 or count > len(rows) - cursor {
            raise ValueError("Invalid visited snapshot");
        }
        records = rows[cursor:cursor + count];
        if records[0] != "QUAKEPASSION 2"
            or records[1] != "q2" or records[2] != name {
            raise ValueError("Visited map mismatch");
        }
        campaign spawn Remember(name=name, data="\n".join(records) + "\n");
        names.append(name);
        cursor += count;
    }
    if cursor != len(rows) { raise ValueError("Trailing campaign save data"); }
    return campaign;
}
