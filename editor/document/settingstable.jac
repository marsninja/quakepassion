"""The studio's settings as a table: each has a name as a console variable,
a subject it is listed under, what it is called, the command that sets it
and the values it takes. The settings box and the console variables are
both read out of it, and both set a setting by the command the studio's
settings file already keeps it as."""

obj Setting {
    has name: str,
        subject: str,
        label: str,
        # The command that sets it, with % where its value goes.
        order: str,
        # The values it takes; none for a number or for words.
        choices: list[str] = [],
        numeric: bool = False,
        help: str = "";
}

"""The subjects the settings are listed under: a key and what it is called."""
glob SUBJECTS: list[tuple[str, str]] = [
    ("general", "General"),
    ("display", "Display"),
    ("view", "3D view"),
    ("map", "Map"),
    ("model", "Model"),
    ("files", "Files"),
    ("colours", "Colours")
];

"""`name|subject|label|order|choices|help`, a setting a line: choices are
words with commas between, `#` for a number and nothing for any words."""
glob SETTING_TABLE: list[str] = [
    "studio_grid|general|Grid|ed_grid %|#|How far apart the grid's lines are, and what moves snap to",
    "studio_anglesnap|general|Turns snap to|ed_anglesnap %|#|Degrees a turn by hand goes in steps of",
    "studio_texlock|general|Materials go with their faces|ed_texlock %|on,off,axis|Whether a move, turn or stretch carries the materials along; axis: a move does, a turn or stretch leaves them along the world's axes",
    "studio_autocaulk|general|Shapes come caulked|ed_autocaulk %|on,off|Whether a new shape's hidden sides are given the material no one sees",
    "studio_flyover|general|Hints beside the pointer|ed_flyover %|on,off|Whether what the pointer rests on says what it is",
    "studio_axes|general|Move arrows run along|ed_axes %|world,local,view|The world's axes, the selection's own (a brush's sides, the way an entity faces) or across, into and up the view",
    "studio_tools|display|Row of tools|ed_bar tools %|show,hide|The row of buttons under the menus",
    "studio_tools_place|display|Tools sit|ed_bar tools %|above,below|Over the views or under them",
    "studio_status|display|Status bar|ed_bar status %|show,hide|The line along the foot of the window",
    "studio_sides|display|Scene panel on the|ed_sides %|left,right|Which side the scene's panel is on (the inspector takes the other)",
    "studio_dev|display|Developer's readout|ed_dev %|on,off|Frame and build times and counts in the status bar",
    "studio_grid_shown|display|Grid in the axis views|ed_grid %|show,hide|Whether the grid's lines are drawn",
    "studio_ruler|display|Ruler|ed_ruler %|on,off|The world's numbers along the axis views' edges",
    "studio_names|display|Names on every entity|ed_names %|on,off|Off, only the selection is named",
    "studio_outside|display|Outside a view's band of depth|ed_outside %|whole,grey,hide|How a view held to a band shows what lies outside it",
    "studio_view_3d|view|The 3D view draws|ed_display % 3d|wire,textured|Outlines, or faces with their materials",
    "studio_view_axis|view|The axis views draw|ed_display % axis|wire,textured|Outlines, or faces with their materials",
    "studio_light|view|Light|ed_light %|on,off|Whether the level is drawn lit",
    "studio_models|view|Entities as their models|ed_models %|on,off|Pickups, monsters and fixtures drawn as their game's models",
    "studio_line_width|view|Lines drawn so wide|ed_overlay width %|1,2,3,4|How many pixels wide the studio's own lines are in the views",
    "studio_look|view|Mouse look rate|ed_mouse look %|#|How far the camera turns for the mouse's travel (1 is as it comes)",
    "studio_look_invert|view|Mouse look inverted|ed_mouse invert %|on,off|Pushing the mouse forward looks down",
    "studio_wheel|view|Wheel rate|ed_mouse wheel %|#|How far the wheel moves the camera (1 is as it comes)",
    "studio_wheel_reverse|view|Wheel reversed|ed_mouse reverse %|on,off|The wheel's two ways changed over",
    "studio_build|map|Light is built|ed_build %|quick,full|Coarse and fast, or fine",
    "studio_map_comments|map|Maps have numbered comments|ed_mapopts comments %|on,off|A comment before each entity and brush of a saved map",
    "studio_map_whole|map|Maps in whole numbers|ed_mapopts whole %|on,off|A saved map's numbers rounded, as the old compilers want them",
    "studio_layout|map|Views laid out as|ed_layout %|1,2,3,4,4b|One view, two, three, four, or four with the 3D view the larger",
    "studio_model_backs|model|Faces turned away|ed_model backs %|on,off|Whether the model editor draws the faces that look away",
    "studio_model_ticks|model|Ticks on points|ed_model ticks %|#|The size of the mark on every point of the model (0 for none)",
    "studio_model_marks|model|Marks drawn as|ed_model marks %|cross,box,diamond|How the marks on a model's points and tags are drawn",
    "studio_model_shade|model|The model drawn|ed_model shade %|wire,solid,textured|The model being edited as its edges, with its faces filled, or with its skin",
    "studio_model_layout|model|The model shown in|ed_model layout %|1,4|One view, or four: turning, from above, the front and the side",
    "studio_model_about|model|The view turns about|ed_model about %|model,origin,view,free|The model's middle, its origin, where the view looks, or the eye itself",
    "studio_autosave|files|Autosave every|ed_autosave every %|#|Seconds between autosaves of a changed scene (0 for never)",
    "studio_theme|colours|Theme|ed_theme %|dark,light|The studio's dark colours or its light ones",
    "studio_colour_accent|colours|Highlights|ed_colour accent %||What is picked, lit or to be pressed: red, green and blue as six digits, or default",
    "studio_colour_select|colours|Selected words|ed_colour select %||Behind words selected in a field: six digits, or default",
    "studio_colour_text|colours|Words|ed_colour text %||The studio's words: six digits, or default",
    "studio_colour_panel|colours|Panels|ed_colour panel %||Behind the panels: six digits, or default"
];

"""A setting from a line of the table, or none when the line is not one."""
def read_setting(line: str) -> Setting | None {
    parts = [part.strip() for part in line.split("|")];
    if len(parts) < 4 or not parts[0] or "%" not in parts[3] {
        return None;
    }
    kinds = parts[4] if len(parts) > 4 else "";
    return Setting(
        name=parts[0],
        subject=parts[1],
        label=parts[2],
        order=parts[3],
        choices=[word for word in kinds.split(",") if word] if kinds != "#" else [],
        numeric=kinds == "#",
        help=parts[5] if len(parts) > 5 else ""
    );
}

"""Every setting of the table, in its order."""
def settings_table -> list[Setting] {
    found: list[Setting] = [];
    for line in SETTING_TABLE {
        read = read_setting(line);
        if read is not None {
            found.append(read);
        }
    }
    return found;
}

"""Whether words are a number."""
def:priv is_number(words: str) -> bool {
    try {
        float(words);
        return True;
    } except ValueError {
        return False;
    }
}

"""Whether a setting takes a value."""
def setting_takes(setting: Setting, value: str) -> bool {
    if not value or "\n" in value or ";" in value or "\"" in value {
        return False;
    }
    if setting.numeric {
        return is_number(value);
    }
    return len(setting.choices) == 0 or value in setting.choices;
}

"""What a setting is, read out of the commands that would set the studio
as it stands (the lines of its settings file): the value of the last line
that is this setting's command with a value it takes. "" when none is."""
def setting_value(lines: list[str], setting: Setting) -> str {
    halves = setting.order.split("%");
    found = "";
    for line in lines {
        if not line.startswith(halves[0]) or not line.endswith(halves[1]) or len(line) < len(halves[0]) + len(halves[1]) {
            continue;
        }
        value = line[len(halves[0]):len(line) - len(halves[1])].strip().strip("\"");
        if setting_takes(setting, value) {
            found = value;
        }
    }
    return found;
}

"""The command that gives a setting a value, or "" when it does not take it."""
def setting_order(setting: Setting, value: str) -> str {
    shown = value.strip();
    if not setting_takes(setting, shown) {
        return "";
    }
    return setting.order.replace("%", shown);
}

"""A colour from six digits (red, green, blue, two each, as ff7a18): its
three parts, or none when the words are not that."""
def colour_parts(words: str) -> list[int] {
    digits = words.strip().lower().lstrip("#");
    if len(digits) != 6 {
        return [];
    }
    parts: list[int] = [];
    for at in [0, 2, 4] {
        try {
            parts.append(int(digits[at:at + 2], 16));
        } except ValueError {
            return [];
        }
    }
    return parts;
}

"""Three parts of a colour as six digits."""
def colour_words(red: int, green: int, blue: int) -> str {
    marks = "0123456789abcdef";
    said = "";
    for part in [red, green, blue] {
        held = max(0, min(255, part));
        said += marks[held // 16] + marks[held % 16];
    }
    return said;
}
