"""Write editor/document/scriptlib.jac from editor/userland/qp.jac.

The studio is one native program: the library a project's scripts import
is kept inside it as text and written beside the scripts when they are run.
This turns the library's source into that text. Run it from the repo root
after changing editor/userland/qp.jac:

    jac run scripts/embed_script_library.jac
"""

with entry {
    source = "";
    with open("editor/userland/qp.jac", "r") as file {
        source = file.read();
    }
    lines = [
        '"""The library a project\'s scripts import (editor/userland/qp.jac), kept as',
        "text: the studio writes it beside the scripts it runs. Written by",
        'scripts/embed_script_library.jac; change the library there, not here."""',
        "",
        "glob SCRIPT_LIBRARY_LINES: list[str] = ["
    ];
    for line in source.rstrip("\n").split("\n") {
        lines.append("    '" + line.replace("\\", "\\\\").replace("'", "\\'") + "',");
    }
    lines[-1] = lines[-1][:-1];
    lines.append("];");
    lines.append("");
    lines.append('"""The library as the file it is written to."""');
    lines.append("def script_library -> str {");
    lines.append('    return "\\n".join(SCRIPT_LIBRARY_LINES) + "\\n";');
    lines.append("}");
    with open("editor/document/scriptlib.jac", "w") as file {
        file.write("\n".join(lines) + "\n");
    }
    print("editor/document/scriptlib.jac: " + str(len(lines)) + " lines");
}
