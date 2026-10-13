import from editor.ui.controls { dock_place }

test "a panel let go near an edge docks there, and floats in between" {
    assert dock_place(10, 1280) == "left" and dock_place(256, 1280) == "left";
    assert dock_place(1270, 1280) == "right" and dock_place(1024, 1280) == "right";
    assert dock_place(640, 1280) == "float" and dock_place(300, 1280) == "float";
    # A narrow window keeps an edge forty wide.
    assert dock_place(39, 100) == "left" and dock_place(61, 100) == "right";
}
